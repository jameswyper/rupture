
require 'test/unit'
require_relative 'udplistener.rb'
require_relative '../lib/tapiola/UPnP.rb'

=begin
class Test_Other_Server < Test::Unit::TestCase
	
	def setup
		@q = UDPListener.new('239.255.255.250',1900,true)
		@q.start

		puts "Before spawn"
		@serv = Process.spawn('gmediaserver','-v4','/home/james/Music/','--expire-time=10')
		puts "After spawn pid=#{@serv}"
	end
	
	def test_broadcast
		puts "Starting test_broadcast, waiting 1 second"
		
		sleep(1)
		
		initbcast = Array.new
		rebcast = Array.new
		endbcast = Array.new
		
		while (!@q.messages.empty?)
			initbcast << @q.messages.pop
		end
		
		puts "waiting 12 seconds"
		sleep(12)
		
		while (!@q.messages.empty?)
			rebcast << @q.messages.pop
		end
		
		Process.kill("INT", @serv)
		
		puts "SIGINT sent to server, waiting 2 seconds"
		
		sleep(2)
		
		while (!@q.messages.empty?)
			endbcast << @q.messages.pop
		end		
		
		assert (initbcast.size > 0)
		assert (rebcast.size > 0)
		assert (endbcast.size > 0)
		

		2.times  {puts "*" * 120}
		puts "* Initialisation Messages *"
		puts "*" * 25
		initbcast.each {|m| puts m.data, "*" * 120}
		2.times  {puts "*" * 120}
		puts "* Next batch of Messages *"
		puts "*" * 25
		rebcast.each {|m| puts m.data, "*" * 120}
		2.times  {puts "*" * 120}
		puts "* Byebye Messages *"
		puts "*" * 25
		endbcast.each {|m| puts m.data, "*" * 120}

	end
	
	
	def teardown
		

		puts "Tests finished server pid was #{@serv}"
		
		Process.wait @serv
	end
	
end
=end

class TestOurSimpleServer < Test::Unit::TestCase
	
	def setup
		
		# set up listeners for regular broadcasts and SSDP responses
		
		@bcastq = UDPListener.new('239.255.255.250',1900,true)
		@bcastq.start
		ip = nil

		Socket::getifaddrs.each do |i|
			a = i.addr
			n = i.name
			puts "Looking for interfaces, found #{n}"
			if a.ipv4?
				if !a.ipv4_loopback?
					ip = a.ip_address
					puts "Found IP address #{ip} to use"
				end
			end
		end
		
		port = 63868 #change the port number in the unlikely event another service is using it
		
		@respq = UDPListener.new(ip,port,false)   
		@respq.start
		
		@srch = UDPSocket.open
		@srch.setsockopt(:SOCKET,:REUSEADDR,1)
		@srch.bind(ip,port)
		
		@root = UPnP::RootDevice.new(:Type => "SampleOne", :Version => 1, :Name => "sample1", :FriendlyName => "SampleApp Root Device",
			:Product => "Sample/1.0", :Manufacturer => "James", :ModelName => "JamesSample",	:ModelNumber => "43",
			:ModelURL => "github.com/jameswyper/tapiola", :CacheControl => 10,
			:SerialNumber => "12345678", :ModelDescription => "Sample App Root Device, to illustrate use of tapiola UPnP framework")
		
		Thread.new {@root.start}

	end
	
	def test_SSDP
		
		initbcast = Array.new
		rebcast = Array.new
		endbcast = Array.new

		puts "Sleeping 1 second"
		sleep(1)
		while (!@bcastq.messages.empty?)
			initbcast << @bcastq.messages.pop
		end

		puts "Sleeping 8 seconds"
		sleep(8)
		while (!@bcastq.messages.empty?)
			rebcast << @bcastq.messages.pop
		end

		@root.stop
		
		puts "Sleeping 2 seconds"
		sleep(2)
		while (!@bcastq.messages.empty?)
			endbcast << @bcastq.messages.pop
		end
		
		assert (initbcast.size > 0)
		assert (rebcast.size > 0)
		assert (endbcast.size > 0)
		
=begin
		2.times  {puts "*" * 120}
		puts "* Initialisation Messages *"
		puts "*" * 25
		initbcast.each {|m| puts m.data, "*" * 120}
		2.times  {puts "*" * 120}
		puts "* Next batch of Messages *"
		puts "*" * 25
		rebcast.each {|m| puts m.data, "*" * 120}
		2.times  {puts "*" * 120}
		puts "* Byebye Messages *"
		puts "*" * 25
		endbcast.each {|m| puts m.data, "*" * 120}
=end
		
	end
	
	def teardown
		
		
	end
	
end