
require 'minitest/autorun'
require_relative 'udplistener.rb'
require_relative '../lib/tapiola/UPnP.rb'


UUIDREGEXP = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"


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

class TestSimpleSSDPDiscovery < Minitest::Test
	

	
	def setup

		# set up listeners for regular broadcasts and SSDP responses
		
		@bcastq = UDPListener.new('239.255.255.250',1900,true)
		@bcastq.start
		ip = nil

		Socket::getifaddrs.each do |i|
			a = i.addr
			n = i.name
			#puts "Looking for interfaces, found #{n}"
			if a.ipv4?
				if !a.ipv4_loopback?
					ip = a.ip_address
					puts "Found IP address #{ip} to use"
				end
			end
		end
		
		port = 63868 #change the port number in the unlikely event another service is using it
		
		@respq = UDPListener.new("0.0.0.0",port,false)   
		@respq.start
		
		# set up socket to send search requests
		
		@srch = UDPSocket.open
		@srch.setsockopt(:SOCKET,:REUSEADDR,1)
		@srch.bind(ip,port)
		
		@root = UPnP::RootDevice.new(:Type => "SampleOne", :Version => 1, :Name => "sample1", :FriendlyName => "SampleApp Root Device",
			:Product => "Sample/1.0", :Manufacturer => "James", :ModelName => "JamesSample",	:ModelNumber => "43",
			:ModelURL => "github.com/jameswyper/tapiola", :CacheControl => 15,
			:SerialNumber => "12345678", :ModelDescription => "Sample App Root Device, to illustrate use of tapiola UPnP framework", 
			:URLBase => "test", :IP => "127.0.0.1", :port => 54321, :LogLevel => Logger::INFO)
		
		
		
		Thread.new {@root.start}
		@initbcast = Array.new
		@rebcast = Array.new
		@endbcast = Array.new

		puts "Waiting for initial broadcast messages"
		sleep(1)
		while (!@bcastq.messages.empty?)
			@initbcast << @bcastq.messages.pop
		end

#=begin		
		srq = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: "
		srq << '"ssdp:discover"'
		srq << "\r\nMX: 2\r\nST: "
		
		puts "sending search all message"
		srqm = srq  +  "ssdp:all" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (3)
		while (!@respq.messages.empty?)
			@srchall << @respq.messages.pop
		end
		
		puts "sending search for root message"
		srqm = srq + "upnp:rootdevice" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (3)
		while (!@respq.messages.empty?)
			@srchroot << @respq.messages.pop
		end
		
		puts "sending search for uuid message"
		srqm = srq + "uuid:#{@root.uuid}" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (3)
		while (!@respq.messages.empty?)
			@srchuuid << @respq.messages.pop
		end

		puts "sending search for device/version message"
		srqm = srq + "urn:schemas-upnp-org:device:SampleOne:1" + "\r\n\r\n"
		@srch.send  srqm ,0, "239.255.255.250", 1900
		sleep (3)
		while (!@respq.messages.empty?)
			@srchtype << @respq.messages.pop
		end
#=end

		while (!@bcastq.messages.empty?)
			@rebcast << @bcastq.messages.pop
		end

		
		@root.stop
	
		
		puts "Waiting for byebye messages"
		sleep(2)
		while (!@bcastq.messages.empty?)
			@endbcast << @bcastq.messages.pop
		end	
		
	
	end
	
	def test_SSDP

# check that the number of messages created is appropriate

		assert (@initbcast.size >= 9)


# process the initial broadcast messages - check they have proper newlines

		msg = Array.new

		@initbcast.each do |m|
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
		
# check the content that's core to each messages and store the content that's unique

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

# check the unique content 

		ntc = sortDedup(nt)
		
		assert_equal "NT: upnp:rootdevice", ntc[0]
		assert_equal "NT: urn:schemas-upnp-org:device:SampleOne:1", ntc[1]
		assert_match Regexp.new("NT: uuid:#{UUIDREGEXP}","i"), ntc[2]
		
		usnc = sortDedup(usn)
		
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}","i"), usnc[0]
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::upnp:rootdevice","i"), usnc[1]		
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::urn:schemas-upnp-org:device:SampleOne:1","i"), usnc[2]		
	


# check that the number of messages created is appropriate

		assert  ( @rebcast.size >= 9)
		#assert_equal  9, @endbcast.size

# process the re-broadcast messages - check they have proper newlines

		msg = Array.new
		
		@rebcast.each do |m|
			n = Array.new
			dropit = false
			m.data.each_line  do |el| 
				assert_equal "\r\n", el[-2..-1]
				n << el.strip
				if (el.strip == "M-SEARCH * HTTP/1.1")
					dropit=true
				end
			end
			msg << n unless dropit
		end
		
# check the content that's core to each messages and store the content that's unique

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

# check the unique content 

		ntc = sortDedup(nt)
		
		assert_equal "NT: upnp:rootdevice", ntc[0]
		assert_equal "NT: urn:schemas-upnp-org:device:SampleOne:1", ntc[1]
		assert_match Regexp.new("NT: uuid:#{UUIDREGEXP}","i"), ntc[2]
		
		usnc = sortDedup(usn)
		
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}","i"), usnc[0]
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::upnp:rootdevice","i"), usnc[1]		
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::urn:schemas-upnp-org:device:SampleOne:1","i"), usnc[2]		
	

		

# check that the number of messages created is appropriate
# because of the way the server works, some broadcast messages might get collected alongside the ones we want to look at
# this is OK

		assert  ( @endbcast.size >= 9)
		

# process the initial broadcast messages - check they have proper newlines, filter out any announcement messages we've collected

		msg = Array.new
		@endbcast.each do |m|
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
		
# now we really should have 9 messages

		assert_equal 9, msg.size
		
# check the content that's core to each messages and store the content that's unique

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

# check the unique content 

		ntc = sortDedup(nt)
		
		assert_equal "NT: upnp:rootdevice", ntc[0]
		assert_equal "NT: urn:schemas-upnp-org:device:SampleOne:1", ntc[1]
		assert_match Regexp.new("NT: uuid:#{UUIDREGEXP}","i"), ntc[2]
		
		usnc = sortDedup(usn)
		
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}","i"), usnc[0]
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::upnp:rootdevice","i"), usnc[1]		
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::urn:schemas-upnp-org:device:SampleOne:1","i"), usnc[2]		
	
	
# check search results

# process the search messages - check they have proper newlines

		msg = Array.new
		@srchall.each do |m|
			n = Array.new
			m.data.each_line  do |el| 
				assert_equal "\r\n", el[-2..-1]
				n << el.strip
			end
			msg << n
		end
		
# check the content that's core to each messages and store the content that's unique

		nt = Array.new
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

# check the unique content 

		stc = sortDedup(st)
		asset_equal 1, stc.size
		
		assert_equal "NT: upnp:rootdevice", stc[0]
#		assert_equal "NT: urn:schemas-upnp-org:device:SampleOne:1", ntc[1]
#		assert_match Regexp.new("NT: uuid:#{UUIDREGEXP}","i"), ntc[2]
		
		usnc = sortDedup(usn)
		assert_equal 1, usnc.size
		
#		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}","i"), usnc[0]
		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::upnp:rootdevice","i"), usnc[0]		
#		assert_match Regexp.new("USN: uuid:#{UUIDREGEXP}::urn:schemas-upnp-org:device:SampleOne:1","i"), usnc[2]		
	

	
	
	
	
	end	
	
	
	def teardown
		@bcastq.pause
		@respq.pause
		
	end
	
end