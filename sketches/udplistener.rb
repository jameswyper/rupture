
require 'thread'
require 'socket'
require 'ipaddr'
require 'pry'

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
			puts "#{self.object_id} multicast listening"
			@sock.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, rip)
		end
		@sock.bind("0.0.0.0",port)
		@messages = Queue.new
		@paused  = true
		puts "#{self.object_id} Listener initialised on #{ip}:#{port} socket #{@sock.to_s}"
		@ip = ip
	end

	def start
		@paused = false
		Thread.new do
			while (!@paused)  do
				puts "#{self.object_id} in select loop #{@sock.to_s}"
				s = IO.select([@sock],nil,nil,1)
				puts "#{self.object_id} after select"
				if s
					puts "#{self.object_id} before read, #{s.size}"
					if (@ip == 1900)
						binding.pry
					end
					s.each  do |t| 
						puts "socket #{t.to_s}" 
					end
					
					msg, info = @sock.recvfrom(1024)
					
					lm = ListenerMessage.new(info[3], info[1], msg)
					puts "#{self.object_id} UDP message from #{@lm.ip}:#{@lm.port}"
					@messages << lm
				end
			end
		end
	end
	
	def pause
		@paused = true
		puts "#{self.object_id} Paused"
	end

end