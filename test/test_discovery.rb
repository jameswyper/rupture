

=begin

	This script tests the SSDP (Discovery) protocol for the tapiola UPnP library
	Rather than test the behaviour of individual classes, it performs a full-system test by creating a UPnP server
	and checking that it implements the SSDP protocol correctly (with a few tweaks around repeating messages more
	frequently to ensure the tests run in a resonable space of time - a completely realistic test would take about 
	an hour to run and spend much of that time doing nothing)
	
	I use a small helper class UDPCollector, this merely creates a UDP socket, binds it, and allows any messages
	received on the socket to be collected for examination
	
	The SSDP protocol requires that M-SEARCH messages are sent from and received at the same port, this means the sending
	socket and receiving socket must both be bound to the same port.  In practice I've found (rightly or wrongly) that
	this means the receiving socket doesn't actually get the messages, so I re-use the receiving socket for sending.
	It's absolutely OK to do this with UDP.
	
	In outline the script
	- sets up a couple of UDP sockets, one to receive multicast SSDP:alive and SSDP:byebye messages and one to send/receive
	  M-SEARCH protocol messages
	- creates a simple UDP server (one device, no services)
	- collects initial SSDP:alive messages from the server
	- sends a series of different M-SEARCH messages to the server and collects the responses
	- collects a second set of SSDP:alive messages that the server should send after a few seconds (due to the random
	  nature of the timing of these we can't be sure exactly how many we'll collect)
	- shuts the server down
	- collects the SSDP:byebye messages
	
	It will then take the collected messages and split them into two-dimensional arrays (messages and lines within each message)
	
	SSDP has a lot of "boilerplate" in the protocol, this is checked first
	Any part of the message that's specific to the server / M-SEARCH request sent is then checked
	
	limitations:  I check that the UUID is in the correct format, not that it's the correct UUID.  The same for the server URL (LOCATION field)
	
	A similar set of tests is then repeated on a more complex server with one root device, one embedded device and some services in each
	
=end

require 'minitest/autorun'
require_relative 'udpcollector.rb'
require_relative '../lib/tapiola/UPnP.rb'


UUIDREGEXP = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"

=begin
	Discovery messages are sent over UDP so their sequencing can't be guaranteed
	The UPnP protocol recommends that some messages are sent more than once, at random intervals
	We therefore need a way of taking elements of the message that we wish to examine further and
	sorting / removing duplicates so we can compare against expected results more easily
=end
	

def sortDedup (x)
	y = Array.new
	z = ""
	x.sort.each do |e| 
		if (z != e)
			y << e
		end
		z = e
	end
	return y	
end

=begin
	The following helper methods are used to process the incoming messages and check the boilerplate elements
	of the relevant protocols
=end

	def split_SSDPalive_into_lines(response)
		
		msg = Array.new

		response.each do |m|
			n = Array.new
			dropit = false
			m.data.each_line  do |el| 
				assert_equal "\r\n", el[-2..-1]
				if (el.strip == "M-SEARCH * HTTP/1.1")
					dropit=true
				end
				n << el.strip
			end
			msg << n unless dropit
		end
		return msg
	end
	
	def split_SSDPbyebye_into_lines(response)
		msg = Array.new
		response.each do |m|
			n = Array.new
			dropit = false
			m.data.each_line  do |el| 
				assert_equal "\r\n", el[-2..-1]
				if ((el.strip == "NTS: ssdp-alive") || (el.strip == "M-SEARCH * HTTP/1.1"))
					dropit = true
				end
				n << el.strip
			end
			msg << n unless dropit
		end
		return msg
	end
	
	
	def split_ST_into_lines(response)
		
		msg = Array.new
		response.each do |m|
			n = Array.new
			m.data.each_line  do |el| 
				assert_equal "\r\n", el[-2..-1]
				n << el.strip
			end
			msg << n
		end
		return msg
	end
	

	
	def check_boilerplate_SSDPalive(msg)
		nt = Array.new
		usn = Array.new
		msg.each do |m|
			assert_equal "NOTIFY * HTTP/1.1",m[0]
			assert_equal "HOST: 239.255.255.250:1900", m[1] 
			assert_equal "CACHE-CONTROL: max-age = 15", m[2] 
			assert_match Regexp.new("LOCATION: http://[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[0-9]{1,5}/test/description/description\.xml"), m[3] 
			nt << m[4]
			assert_equal "NTS: ssdp:alive", m[5]
			assert_match Regexp.new("SERVER: .* UPnP\/1\.0 .*") , m[6]
			usn << m[7]
			assert_equal "", m[8]
		end
		return sortDedup(nt), sortDedup(usn)
	end
	
	def check_boilerplate_SSDPbyebye(msg)
		nt = Array.new
		usn = Array.new
		msg.each do |m|
			assert_equal "NOTIFY * HTTP/1.1",m[0]
			assert_equal "HOST: 239.255.255.250:1900", m[1] 
			nt << m[2]
			assert_equal "NTS: ssdp:byebye", m[3]
			usn << m[4]
			assert_equal "", m[5]
		end
		return sortDedup(nt), sortDedup(usn)
	end
	
	def check_boilerplate_ST(msg)
		st = Array.new
		usn = Array.new
		msg.each do |m|
			assert_equal "HTTP/1.1 200 OK",m[0]
			assert_equal "CACHE-CONTROL: max-age = 15", m[1] 
			assert_match Regexp.new("DATE: .*"),m[2]
			assert_equal "EXT:",m[3]
			assert_match Regexp.new("LOCATION: http://[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[0-9]{1,5}/test/description/description\.xml"), m[4] 

			assert_match Regexp.new("SERVER: .* UPnP\/1\.0 .*") , m[5]
			st << m[6]
			usn << m[7]
			assert_equal "", m[8]
		end
		return sortDedup(st), sortDedup(usn)
	end
	
	


class TestSimpleSSDPDiscovery < Minitest::Test
	
		
	def setup

		puts "Setting up simple UDP server"
		
		# set up listeners for regular broadcasts and SSDP responses
		
		@bcastq = UDPCollector.new('239.255.255.250',1900,true)

		
		port = 63868 # feel free to change the port number in the unlikely event another service is using it
		
		@respq = UDPCollector.new("0.0.0.0",port,false)   
		


		@srch = @respq.sock
		
		@root = UPnP::RootDevice.new(:Type => "SampleOne", :Version => 1, :Name => "sample1", :FriendlyName => "SampleApp Root Device",
			:Product => "Sample/1.0", :Manufacturer => "James", :ModelName => "JamesSample",	:ModelNumber => "43",
			:ModelURL => "github.com/jameswyper/tapiola", :CacheControl => 15,
			:SerialNumber => "12345678", :ModelDescription => "Sample App Root Device, to illustrate use of tapiola UPnP framework", 
			:URLBase => "test", :IP => "127.0.0.1", :port => 54321, :LogLevel => Logger::INFO)
		
		
		
		Thread.new {@root.start}
		@initbcast = Array.new
		@rebcast = Array.new
		@endbcast = Array.new

		puts "Waiting for initial broadcast advertisment messages"
		sleep(1)
		@initbcast = @bcastq.collect

		
		srq = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: "
		srq << '"ssdp:discover"'
		srq << "\r\nMX: 2\r\nST: "
		
		puts "sending search all message"
		srqm = srq  +  "ssdp:all" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (2)
		@srchall = @respq.collect
	
		
		puts "sending search for root message"
		srqm = srq + "upnp:rootdevice" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (2)
		@srchroot = @respq.collect
	
		
		puts "sending search for uuid message"
		srqm = srq + "uuid:#{@root.uuid}" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (2)
		@srchuuid = @respq.collect

		puts "sending search for device/version message"
		srqm = srq + "urn:schemas-upnp-org:device:SampleOne:1" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (2)
		@srchtype = @respq.collect

		puts "waiting a little longer to collect any repeat SSDP advertisments"
		sleep(2)

		@rebcast = @bcastq.collect

		puts "stopping the server"
		@root.stop
	
		
		puts "waiting for byebye messages"
		sleep(2)
		@endbcast = @bcastq.collect
		
		puts "done with collecting for the simple server"
		
	
	end
	

	
	
	def test_SSDP

# check that the number of messages created is appropriate

		assert (@initbcast.size >= 9)


# process the initial broadcast messages - check they have proper newlines then

# check the content that's core to each messages and store the content that's unique

		ntc, usnc = check_boilerplate_SSDPalive(split_SSDPalive_into_lines(@initbcast))
		
		# check the unique content 


		assert_equal "NT: upnp:rootdevice", ntc[0]
		assert_equal "NT: urn:schemas-upnp-org:device:SampleOne:1", ntc[1]
		assert_match Regexp.new("NT: uuid:#{UUIDREGEXP}","i"), ntc[2]
		
		
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}","i"), usnc[0]
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::upnp:rootdevice","i"), usnc[1]		
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::urn:schemas-upnp-org:device:SampleOne:1","i"), usnc[2]		
	


# same checks for messages that have been rebroadcast 

		assert  ( @rebcast.size >= 9)

		ntc, usnc = check_boilerplate_SSDPalive(split_SSDPalive_into_lines(@rebcast))
		

		
		assert_equal "NT: upnp:rootdevice", ntc[0]
		assert_equal "NT: urn:schemas-upnp-org:device:SampleOne:1", ntc[1]
		assert_match Regexp.new("NT: uuid:#{UUIDREGEXP}","i"), ntc[2]

		
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}","i"), usnc[0]
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::upnp:rootdevice","i"), usnc[1]		
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::urn:schemas-upnp-org:device:SampleOne:1","i"), usnc[2]		
	

		

# similar checks for SSDP:byebye

		assert  ( @endbcast.size >= 9)
		

# process the initial broadcast messages - check they have proper newlines, filter out any announcement messages we've collected

		msg = split_SSDPbyebye_into_lines(@endbcast)
		
		
# now we really should have 9 messages

		assert_equal 9, msg.size
		
# check the content that's core to each messages and store the content that's unique

		ntc,usn = check_boilerplate_SSDPbyebye(msg)

# check the unique content 

		
		assert_equal "NT: upnp:rootdevice", ntc[0]
		assert_equal "NT: urn:schemas-upnp-org:device:SampleOne:1", ntc[1]
		assert_match Regexp.new("NT: uuid:#{UUIDREGEXP}","i"), ntc[2]
		
		
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}","i"), usnc[0]
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::upnp:rootdevice","i"), usnc[1]		
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::urn:schemas-upnp-org:device:SampleOne:1","i"), usnc[2]		
	
	
# check search results




		stc,usnc = check_boilerplate_ST(split_ST_into_lines(@srchall))
		assert_equal 3,stc.size
		assert_equal "ST: upnp:rootdevice", stc[0]
 		assert_equal "ST: urn:schemas-upnp-org:device:SampleOne:1", stc[1]
 		assert_match Regexp.new("ST: uuid:#{UUIDREGEXP}","i"), stc[2]
		assert_equal 3, usnc.size
 		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}","i"), usnc[0]
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::upnp:rootdevice","i"), usnc[1]		
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::urn:schemas-upnp-org:device:SampleOne:1","i"), usnc[2]		
	

		stc,usnc = check_boilerplate_ST(split_ST_into_lines(@srchroot))
		assert_equal 1,stc.size
		assert_equal "ST: upnp:rootdevice", stc[0]
		assert_equal 1, usnc.size
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::upnp:rootdevice","i"), usnc[0]		


		stc,usnc = check_boilerplate_ST(split_ST_into_lines(@srchuuid))
		assert_equal 1,stc.size
 		assert_match Regexp.new("ST: uuid:#{UUIDREGEXP}","i"), stc[0]
		assert_equal 1, usnc.size
 		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}","i"), usnc[0]
		
	
		stc,usnc = check_boilerplate_ST(split_ST_into_lines(@srchtype))
		assert_equal 1,stc.size
		assert_equal "ST: urn:schemas-upnp-org:device:SampleOne:1", stc[0]
 		assert_equal 1, usnc.size
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::urn:schemas-upnp-org:device:SampleOne:1","i"), usnc[0]		
	
	end	
	
	
	def teardown
	
		
	end
	
end


class TestComplexSSDPDiscovery < Minitest::Test
	
		
	def setup


		puts "Setting up more complex UDP server"
		# set up listeners for regular broadcasts and SSDP responses
		
		@bcastq = UDPCollector.new('239.255.255.250',1900,true)


		
		port = 63868 # feel free to change the port number in the unlikely event another service is using it
		
		@respq = UDPCollector.new("0.0.0.0",port,false)   
		


		@srch = @respq.sock
		
		@root = UPnP::RootDevice.new(:Type => "SampleTwo", :Version => 2, :Name => "sample2", :FriendlyName => "SampleApp Root Device v2",
			:Product => "Sample/1.0", :Manufacturer => "James", :ModelName => "JamesSample",	:ModelNumber => "43",
			:ModelURL => "github.com/jameswyper/tapiola", :CacheControl => 15,
			:SerialNumber => "12345678", :ModelDescription => "Sample App Root Device, to illustrate use of tapiola UPnP framework", 
			:URLBase => "test", :IP => "127.0.0.1", :port => 54322, :LogLevel => Logger::INFO)
		
		
		@emb = UPnP::Device.new(:Type => "SampleThree", :Version => 3, :Name => "sample3", :FriendlyName => "SampleApp Embedded Device",
			 :Manufacturer => "James inc", :ModelName => "JamesSample III",	:ModelNumber => "42",	:ModelURL => "github.com/jameswyper/tapiola",
			:UPC => "987654321", :ModelDescription => "Sample App Embedded Device, to illustrate use of tapiola UPnP framework")
	
		@serv1 = UPnP::Service.new("Add",1)
		@serv2 = UPnP::Service.new("Find",3)
		@serv3 = UPnP::Service.new("Change",2)
		
		@root.addDevice(@emb)
		@root.addService(@serv1)
		@root.addService(@serv2)
		@emb.addService(@serv3)
		
		Thread.new {@root.start}
		@initbcast = Array.new
		@rebcast = Array.new
		@endbcast = Array.new

		puts "Waiting for initial broadcast advertisment messages"
		sleep(1)
		@initbcast = @bcastq.collect

		
		srq = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: "
		srq << '"ssdp:discover"'
		srq << "\r\nMX: 2\r\nST: "
		
		puts "sending search all message"
		srqm = srq  +  "ssdp:all" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (2)
		@srchall = @respq.collect
	
		
		puts "sending search for root message"
		srqm = srq + "upnp:rootdevice" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (2)
		@srchroot = @respq.collect
	
		
		puts "sending search for uuid message (root device)"
		srqm = srq + "uuid:#{@root.uuid}" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (2)
		@srchuuidroot = @respq.collect
		
		puts "sending search for uuid message (embedded device)"
		srqm = srq + "uuid:#{@emb.uuid}" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (2)
		@srchuuidemb = @respq.collect
		
		puts "sending search for device/version message (root)"
		srqm = srq + "urn:schemas-upnp-org:device:SampleTwo:2" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (2)
		@srchdevtype1 = @respq.collect
		
		puts "sending search for device/version message (embedded)"
		srqm = srq + "urn:schemas-upnp-org:device:SampleThree:3" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (2)
		@srchdevtype2 = @respq.collect


#todo - add messages which are going to fail

		puts "sending search for service/version message (embedded 1)"
		srqm = srq + "urn:schemas-upnp-org:service:Add:1" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (2)
		@srchservtype1 = @respq.collect
		
		puts "sending search for service/version message (embedded 2)"
		srqm = srq + "urn:schemas-upnp-org:service:Change:2" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (2)
		@srchservtype2 = @respq.collect
		
		puts "sending search for service/version message (embedded 3)"
		srqm = srq + "urn:schemas-upnp-org:service:Find:3" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (2)
		@srchservtype3 = @respq.collect
		
		puts "sending bogus search messages 1"
		srqm = srq + "urn:schemas-upnp-org:service:Search:3" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (2)
		@srchbogus1 = @respq.collect	
		
		puts "sending bogus search messages 2"
		srqm = srq + "urn:schemas-upnp-org:service:Add:5" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (2)
		@srchbogus2 = @respq.collect	
		
		puts "sending bogus search messages 3"
		srqm = srq + "urn:schemas-upnp-org:device:Add:5" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (2)
		@srchbogus3 = @respq.collect	
				
		puts "sending bogus search messages 4"
		srqm = srq + "uuid:00000000-1111-2222-1111-2222-121212121212" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (2)
		@srchbogus4 = @respq.collect	
		
		puts "sending bogus search messages 5"
		srqm = srq + "upnp:blootdevie" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (2)
		@srchbogus5 = @respq.collect	

		puts "sending bogus search messages 6"
		srqm = srq + "ssdp:owl" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (2)
		@srchbogus6 = @respq.collect	

		puts "waiting a little longer to collect any repeat SSDP advertisments"
		sleep(2)

		@rebcast = @bcastq.collect

		puts "stopping the server"
		@root.stop
	
		
		puts "waiting for byebye messages"
		sleep(2)
		@endbcast = @bcastq.collect
		
		puts "done with collecting, now running tests on the collected data"
		
	
	end
	

	
	
	def test_SSDP

# check that the number of messages created is appropriate

		assert (@initbcast.size >= 24)


# process the initial broadcast messages - check they have proper newlines then

# check the content that's core to each messages and store the content that's unique

		ntc, usnc = check_boilerplate_SSDPalive(split_SSDPalive_into_lines(@initbcast))
		
		# check the unique content 

		assert_equal 8, ntc.size
		assert_equal 8, usnc.size

		assert_equal "NT: upnp:rootdevice", ntc[0]
		assert_equal "NT: urn:schemas-upnp-org:device:SampleThree:3", ntc[1]
		assert_equal "NT: urn:schemas-upnp-org:device:SampleTwo:2", ntc[2]
		assert_equal "NT: urn:schemas-upnp-org:service:Add:1", ntc[3]
		assert_equal "NT: urn:schemas-upnp-org:service:Change:2", ntc[4]
		assert_equal "NT: urn:schemas-upnp-org:service:Find:3", ntc[5]
		assert_match Regexp.new("NT: uuid:#{UUIDREGEXP}","i"), ntc[6]
		assert_match Regexp.new("NT: uuid:#{UUIDREGEXP}","i"), ntc[7]
		
# with multiple UUIDs we can no longer rely on the order of USN messages
		
		assert_includes usnc,"USN: uuid:#{@root.uuid}"
		assert_includes usnc,"USN: uuid:#{@emb.uuid}"
		assert_includes usnc,"USN: uuid:#{@root.uuid}::upnp:rootdevice"
		assert_includes usnc,"USN: uuid:#{@emb.uuid}::urn:schemas-upnp-org:device:SampleThree:3"
		assert_includes usnc,"USN: uuid:#{@root.uuid}::urn:schemas-upnp-org:device:SampleTwo:2"
		assert_includes usnc,"USN: uuid:#{@root.uuid}::urn:schemas-upnp-org:service:Add:1"
		assert_includes usnc,"USN: uuid:#{@emb.uuid}::urn:schemas-upnp-org:service:Change:2"
		assert_includes usnc,"USN: uuid:#{@root.uuid}::urn:schemas-upnp-org:service:Find:3"


# same checks for messages that have been rebroadcast 

		assert  ( @rebcast.size >= 24)

		ntc, usnc = check_boilerplate_SSDPalive(split_SSDPalive_into_lines(@rebcast))


		assert_equal 8, ntc.size
		assert_equal 8, usnc.size

		assert_equal "NT: upnp:rootdevice", ntc[0]
		assert_equal "NT: urn:schemas-upnp-org:device:SampleThree:3", ntc[1]
		assert_equal "NT: urn:schemas-upnp-org:device:SampleTwo:2", ntc[2]
		assert_equal "NT: urn:schemas-upnp-org:service:Add:1", ntc[3]
		assert_equal "NT: urn:schemas-upnp-org:service:Change:2", ntc[4]
		assert_equal "NT: urn:schemas-upnp-org:service:Find:3", ntc[5]
		assert_match Regexp.new("NT: uuid:#{UUIDREGEXP}","i"), ntc[6]
		assert_match Regexp.new("NT: uuid:#{UUIDREGEXP}","i"), ntc[7]
		
		
		assert_includes usnc,"USN: uuid:#{@root.uuid}"
		assert_includes usnc,"USN: uuid:#{@emb.uuid}"
		assert_includes usnc,"USN: uuid:#{@root.uuid}::upnp:rootdevice"
		assert_includes usnc,"USN: uuid:#{@emb.uuid}::urn:schemas-upnp-org:device:SampleThree:3"
		assert_includes usnc,"USN: uuid:#{@root.uuid}::urn:schemas-upnp-org:device:SampleTwo:2"
		assert_includes usnc,"USN: uuid:#{@root.uuid}::urn:schemas-upnp-org:service:Add:1"
		assert_includes usnc,"USN: uuid:#{@emb.uuid}::urn:schemas-upnp-org:service:Change:2"
		assert_includes usnc,"USN: uuid:#{@root.uuid}::urn:schemas-upnp-org:service:Find:3"
		

# similar checks for SSDP:byebye

		assert  ( @endbcast.size >= 24)
		

# process the initial broadcast messages - check they have proper newlines, filter out any announcement messages we've collected

		msg = split_SSDPbyebye_into_lines(@endbcast)
		
		
# now we really should have 24  messages

		assert_equal 24, msg.size
		
# check the content that's core to each messages and store the content that's unique

		ntc,usn = check_boilerplate_SSDPbyebye(msg)

		
		assert_equal 8, ntc.size
		assert_equal 8, usnc.size

# check the unique content 

		assert_equal "NT: upnp:rootdevice", ntc[0]
		assert_equal "NT: urn:schemas-upnp-org:device:SampleThree:3", ntc[1]
		assert_equal "NT: urn:schemas-upnp-org:device:SampleTwo:2", ntc[2]
		assert_equal "NT: urn:schemas-upnp-org:service:Add:1", ntc[3]
		assert_equal "NT: urn:schemas-upnp-org:service:Change:2", ntc[4]
		assert_equal "NT: urn:schemas-upnp-org:service:Find:3", ntc[5]
		assert_match Regexp.new("NT: uuid:#{UUIDREGEXP}","i"), ntc[6]
		assert_match Regexp.new("NT: uuid:#{UUIDREGEXP}","i"), ntc[7]
		
		
		assert_includes usnc,"USN: uuid:#{@root.uuid}"
		assert_includes usnc,"USN: uuid:#{@emb.uuid}"
		assert_includes usnc,"USN: uuid:#{@root.uuid}::upnp:rootdevice"
		assert_includes usnc,"USN: uuid:#{@emb.uuid}::urn:schemas-upnp-org:device:SampleThree:3"
		assert_includes usnc,"USN: uuid:#{@root.uuid}::urn:schemas-upnp-org:device:SampleTwo:2"
		assert_includes usnc,"USN: uuid:#{@root.uuid}::urn:schemas-upnp-org:service:Add:1"
		assert_includes usnc,"USN: uuid:#{@emb.uuid}::urn:schemas-upnp-org:service:Change:2"
		assert_includes usnc,"USN: uuid:#{@root.uuid}::urn:schemas-upnp-org:service:Find:3"	
	
# check search results

# tests need to be fixed from here


		stc,usnc = check_boilerplate_ST(split_ST_into_lines(@srchall))
		assert_equal 8,stc.size
		assert_equal "ST: upnp:rootdevice", stc[0]
 		assert_equal "ST: urn:schemas-upnp-org:device:SampleThree:3", stc[1]
		assert_equal "ST: urn:schemas-upnp-org:device:SampleTwo:2", stc[2]
		assert_equal "ST: urn:schemas-upnp-org:service:Add:1", stc[3]
		assert_equal "ST: urn:schemas-upnp-org:service:Change:2", stc[4]
		assert_equal "ST: urn:schemas-upnp-org:service:Find:3", stc[5] 
		assert_includes stc[6..7],"ST: uuid:#{@root.uuid}"
		assert_includes stc[6..7],"ST: uuid:#{@emb.uuid}"
		
		assert_equal 8, usnc.size
 		assert_includes usnc,"USN: uuid:#{@root.uuid}"
		assert_includes usnc,"USN: uuid:#{@emb.uuid}"
		assert_includes usnc,"USN: uuid:#{@root.uuid}::upnp:rootdevice"
		assert_includes usnc,"USN: uuid:#{@emb.uuid}::urn:schemas-upnp-org:device:SampleThree:3"
		assert_includes usnc,"USN: uuid:#{@root.uuid}::urn:schemas-upnp-org:device:SampleTwo:2"
		assert_includes usnc,"USN: uuid:#{@root.uuid}::urn:schemas-upnp-org:service:Add:1"
		assert_includes usnc,"USN: uuid:#{@emb.uuid}::urn:schemas-upnp-org:service:Change:2"
		assert_includes usnc,"USN: uuid:#{@root.uuid}::urn:schemas-upnp-org:service:Find:3"	
	

		stc,usnc = check_boilerplate_ST(split_ST_into_lines(@srchroot))
		assert_equal 1,stc.size
		assert_equal "ST: upnp:rootdevice", stc[0]
		assert_equal 1, usnc.size
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::upnp:rootdevice","i"), usnc[0]		


		stc,usnc = check_boilerplate_ST(split_ST_into_lines(@srchuuidroot))
		assert_equal 1,stc.size
 		assert_match Regexp.new("ST: uuid:#{@root.uuid}","i"), stc[0]
		assert_equal 1, usnc.size
 		assert_match Regexp.new("USN: uuid:#{@root.uuid}","i"), usnc[0]
		
		stc,usnc = check_boilerplate_ST(split_ST_into_lines(@srchuuidemb))
		assert_equal 1,stc.size
 		assert_match Regexp.new("ST: uuid:#{@emb.uuid}","i"), stc[0]
		assert_equal 1, usnc.size
 		assert_match Regexp.new("USN: uuid:#{@emb.uuid}","i"), usnc[0]	
	
		stc,usnc = check_boilerplate_ST(split_ST_into_lines(@srchdevtype1))
		assert_equal 1,stc.size
		assert_equal "ST: urn:schemas-upnp-org:device:SampleTwo:2", stc[0]
 		assert_equal 1, usnc.size
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::urn:schemas-upnp-org:device:SampleTwo:2","i"), usnc[0]		
		
		stc,usnc = check_boilerplate_ST(split_ST_into_lines(@srchdevtype2))
		assert_equal 1,stc.size
		assert_equal "ST: urn:schemas-upnp-org:device:SampleThree:3", stc[0]
 		assert_equal 1, usnc.size
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::urn:schemas-upnp-org:device:SampleThree:3","i"), usnc[0]		
	
		
		
		stc,usnc = check_boilerplate_ST(split_ST_into_lines(@srchservtype1))
		assert_equal 1,stc.size
		assert_equal "ST: urn:schemas-upnp-org:service:Add:1", stc[0]
		assert_equal 1, usnc.size
		assert_equal "USN: uuid:#{@root.uuid}::urn:schemas-upnp-org:service:Add:1",usnc[0]

		stc,usnc = check_boilerplate_ST(split_ST_into_lines(@srchservtype2))
		assert_equal 1,stc.size
		assert_equal "ST: urn:schemas-upnp-org:service:Change:2", stc[0]
		assert_equal 1, usnc.size
		assert_equal "USN: uuid:#{@emb.uuid}::urn:schemas-upnp-org:service:Change:2",usnc[0]

		stc,usnc = check_boilerplate_ST(split_ST_into_lines(@srchservtype3))
		assert_equal 1,stc.size
		assert_equal "ST: urn:schemas-upnp-org:service:Find:3", stc[0]
		assert_equal 1, usnc.size
		assert_equal "USN: uuid:#{@root.uuid}::urn:schemas-upnp-org:service:Find:3",usnc[0]

		assert_equal 0,@srchbogus1.size
		assert_equal 0,@srchbogus2.size		
		assert_equal 0,@srchbogus3.size	
		assert_equal 0,@srchbogus4.size
		assert_equal 0,@srchbogus5.size		
		assert_equal 0,@srchbogus6.size	
		
	end	
	
	
	def teardown
	
		
	end
	
end