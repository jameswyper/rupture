
require 'thread'
require 'socket'
require 'ipaddr'

class CollectorMessage
	attr_accessor :ip, :port, :data
	def initialize (i,p,d)
		@ip = i
		@port = p
		@data = d
	end
end	

class UDPCollector
	
	
	attr_accessor :sock
	
	def initialize(ip, port, multicast = false)
		rip =  IPAddr.new(ip).hton + IPAddr.new("0.0.0.0").hton
		@sock = UDPSocket.new
		@sock.setsockopt(:SOCKET,:REUSEADDR,1)
		if multicast
			#puts "#{self.object_id} multicast listening"
			@sock.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, rip)
		end
		@sock.bind(Socket::INADDR_ANY,port)
		#puts "#{self.object_id} Listener initialised on #{ip}:#{port} socket #{@sock.to_s}"
		@ip = ip
	end

	def collect
		
		messages = Array.new
		
		#puts "#{self.object_id} entering select routine #{@sock.to_s}"

		s = IO.select([@sock],nil,nil,0.5) 
		
		
		while s do
			#puts "#{self.object_id} in select loop #{@sock.to_s}"
			msg, info = @sock.recvfrom(1024)
			lm = CollectorMessage.new(info[3], info[1], msg)
			#puts "#{self.object_id} UDP message from #{lm.ip}:#{lm.port}"
			messages << lm
			s = IO.select([@sock],nil,nil,0.5) 
		end


		return messages
	end
	

end