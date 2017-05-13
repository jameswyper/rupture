
require 'thread'
require 'socket'
require 'ipaddr'

class ListenerMessage
	attr_accessor :ip, :port, :data
	def initialize (i,p,d)
		@ip = i
		@port = p
		@data = d
	end
end	

class UDPListener
	
	
	attr_accessor :messages
	
	def initialize(ip, port, multicast = false)
		rip =  IPAddr.new(ip).hton + IPAddr.new("0.0.0.0").hton
		@sock = UDPSocket.new
		@sock.setsockopt(:SOCKET,:REUSEADDR,1)
		if multicast
			@sock.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, rip)
		end
		@sock.bind(ip,port)
		@messages = Queue.new
		@paused  = true
		#puts "listener initialised #{ip} #{port} #{rip}"
	end

	def start
		@paused = false
		Thread.new do
			while (!@paused)  do
				#puts "in select loop"
				s = IO.select([@sock],nil,nil,1)
				if s
					#puts "message!"
					msg, info = @sock.recvfrom(1024)
					lm = ListenerMessage.new(info[3], info[1], msg)
					@messages << lm
				end
			end
		end
	end
	
	def pause
		@paused = true
	end

end