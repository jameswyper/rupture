require 'UPnPBase.rb'
require 'socket'
require 'ipaddr'

=begin rdoc
    
    initialisation: 
    create a response queue object to hold responses
    create a multicast queue object to hold advertisments 
    
    normal running:
    set up three threads
    
    1st will sit for a while and occasionally push advertisment messages to the queue
    2nd will block waiting for multicast messages from other clients, when one arrives it will generate responses and add them to the queue
    3rd will process both queues sending unicast or multicast messages as required
    
    each thread loops while a "terminated" condition is true, after which the 3rd thread will send bye-bye messages
    
    termination:
    
    set "terminated" condition to true
  
    
    
=end

class UPnPDiscoveryServer
	
	MULTICAST_ADDR = "239.255.255.250" 
	PORT = 1900
	
	def initialize(rootDevice)
		@terminated = false
		@responseQueue = Array.new
		@rootd = rootDevice
		@responseLock = Mutex.new
		@multicastLock = Mutex.new
		@multicastQueue = @rootd.keepAlive
	end
	
	def run
		
		t1 = Thread.start do
			while (!@terminated) do
				interval = (@rootd.cacheControl * 0.1) + rand(@rootd.cacheControl * 0.4)
				sleep (interval)
				@multicastLock.synchronize { @multicastQueue.concat(@rootd.keepAlive) }
			end
		end
		
		t2 = Thread.start do
			
			ip =  IPAddr.new(MULTICAST_ADDR).hton + IPAddr.new("0.0.0.0").hton
			sock = UDPSocket.new
			sock.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, ip)
			sock.bind(Socket::INADDR_ANY, PORT)

			
			while (!@terminated) do
				msg, info = sock.recvfrom(1024)
				d, r = @rootd.handleSearch(msg)
				if (r != nil)
					# pass an array of four values onto the queue, the IP address and port of the requestor
					# the time in seconds the requestor said it would wait for a response
					# finally the response messages (itself an array)
					@responseLock.synchronize { @responseQueue << [ info [3], info[1], d, r ] }
				end
			end
		end
		
		t3 = Thread.start do
			begin
				msock = UDPSocket.open
				msock.setsockopt(Socket::IPPROTO_IP, Socket::IP_TTL, [1].pack('i'))
				rsock = UDPSocket.open
				rsock.setsockopt(Socket::IPPROTO_IP, Socket::IP_TTL, [1].pack('i'))
				while ((!@terminated)
					
					@responseLock.synchronize do
						rq = @responseQueue.dup
						@responseQueue.clear
					end
					
					@multicastLock.synchronize do
						mq = @multicastQueue.dup
						@multicastQueue.clear
					end
					
					
					# send each multicast message a few times at random intervals
					# send each response message a few times at intervals up to d
					
					
					
					# msock.send(ARGV.join(' '), 0, MULTICAST_ADDR, PORT)
				end
				
				send byebye message
				
			ensure
				socket.close 	
			end
		end
		
	end
	
	def terminate
		@terminated = true
	end

end