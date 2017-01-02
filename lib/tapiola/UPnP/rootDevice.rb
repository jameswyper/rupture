
require_relative 'device'

require 'socket'
require 'ipaddr'
require 'webrick'

module UPnP

class RootDevice < Device

# standard text for the NOTIFY HTTP header used in Discovery
	NOTIFY  = "NOTIFY * HTTP/1.1"
# standard text for the HOST HTTP header used in Discovery	
	HOST = "HOST: 239.255.255.250:1900"

	
# standard multicast IP address	
	MULTICAST_ADDR = "239.255.255.250" 
# standard multicast port
	PORT = 1900

	# any devices contained within the root device.  Not sure if we need to refer to this outside the class so may remove this later
	attr_reader :devices
	
	# Cache-Control value, default to 1800 seconds.  Again may not be needed outside the class
	attr_reader :cacheControl
	
	# IP and Port part of URL
	attr_reader :ipPort

	def initialize(type,version,ip,port,product)
		super("root",type,version)
		@devices=Hash.new
		addDevice(self)
		
		@product = product
		@os = "Linux/3" #this should be dynamic but who uses it?
		@cacheControl = 1800
		
		# if an ip wasn't specified, find one that isn't the loopback one
		
		if ip == nil
			Socket::ip_address_list.each do |a|
				if a.ipv4?
					if !a.ipv4_loopback?
						@ip = a.ip_address
					end
				end
			end
		else
			@ip = ip
		end
		
		# if a port wasn't specified, ask Webrick to find a free one by specifying port 0 and then check what it found
		
		if port == nil
			@webserver = WEBrick::HTTPServer.new :Port=> 0
			@port = @webserver.config[:Port]
		else
			@webserver = WEBrick::HTTPServer.new :Port=> port
			@port = port
		end
		
		@ipPort = "#{@ip}:#{@port}"
		
		@descriptionAddr = "/#{URLBase}/description"
		
		@location= "http://#{@ip}:#{@port}#{@descriptionAddr}/description.xml"
		
		@log = Logger.new(STDOUT)
		@log.level  = Logger::DEBUG
		@log.datetime_format  = "%H:%M:%S"
		
		@log.info "Listening on #{@ipPort}"
	end

# trivial method to add devices to a root device, it's just a list.  No support for removing them.  Should only be called at runtime.
	def addDevice(device)
		@devices.store(device.name,device)
		device.linkToRoot(self)
	end
	
	
=begin rdoc

Assembles the XML for the root device description.  
Calls getXMLDeviceData to get individual XML elements for each device (root and any embedded)

=end
	
	def createDescriptionXML
		
		rootE =  REXML::Element.new("root")
		rootE.add_namespace("urn:schemas.upnp.org:device-1-0")
		
		sv = REXML::Element.new("specVersion")
		sv.add_element("major").add_text("1")
		sv.add_element("minor").add_text("0")

		rootE.add_element(sv)

		dv = REXML::Element.new("device")
		
		rxml = self.getXMLDeviceData
		
		rxml.each { |rx| dv.add_element(rx) }
		
		
		if @devices.size > 1
		
			dvl = REXML::Element.new("devicelist")
				
			@devices.each_value do |d|
				if (d.name != "root")
					dxml = d.getXMLDeviceData
					dxml.each { |dx| 	dvl.add_element(dx) }
				end
			end
		
			dv.add_element(dvl)
		
		end
		
		rootE.add_element(dv)
		
		doc = REXML::Document.new
		doc << REXML::XMLDecl.new(1.0)
		doc.add_element(rootE)
		
		return doc

	end
	
# For Step 1 - discovery.  Helper method to create a single message that will be multicast. Called by #keepAlive, not intended to be called elsewhere	
	def createAliveMessage(nt,usn) 
		s = String.new
		s << NOTIFY << "\r\n" << HOST << "\r\n"
		s << "CACHE-CONTROL: max-age = " << @cacheControl.to_s << "\r\n"
		s << "LOCATION: #{@location}\r\n"
		s << "NT: #{nt}\r\n"
		s << "NTS: ssdp:alive\r\n"
		s << "SERVER: #{@os} UPnP/1.0 #{@product}\r\n"
		s << "USN: #{usn}\r\n\r\n"
		return s
	end
	
# For Step 1 - discovery.  The keepAlive process creates a series of messages for each device and service	
	def keepAlive 
		a = Array.new
		a << createAliveMessage("upnp:rootdevice","uuid:#{@uuid}::upnp:rootdevice")
		@devices.each_value do |d|
			d.deviceMessages.each do |n|
				a << createAliveMessage(n[0],n[1])
			end
			d.serviceMessages.each do |n|
				a << createAliveMessage(n[0],n[1])
			end
		end
		return a
	end

# For Step 1 - discovery.  Helper method to create a single message that will be multicast. Called by #byeBye, not intended to be called elsewhere	
	def createByeByeMessage(nt,usn)
		s = String.new
		s << NOTIFY << "\r\n" << HOST << "\r\n"
		s << "NT: #{nt}\r\n"
		s << "NTS: ssdp:byebye\r\n"
		s << "USN: #{usn}\r\n\r\n"
		return s
	end

# For Step 1 - discovery.  The byeBye process creates a series of messages for each device and service.  To be called upon shutdown of the root device
	def byeBye
		a = Array.new
		a << createByeByeMessage("upnp:rootdevice","uuid:#{@uuid}::upnp:rootdevice")
		@devices.each_value do |d|
			d.deviceMessages.each do |n|
				a << createByeByeMessage(n[0],n[1])
			end
			d.serviceMessages.each do |n|
				a << createByeByeMessage(n[0],n[1])
			end
		end
		return a
	end


# For Step 1 - discovery.  Helper method to create a single message that will be multicast. Called by #handleSearch, not intended to be called elsewhere	
	def createSearchResponse(st,usn)
		s = String.new
		s <<  "HTTP/1.1 200 OK \r\n" 
		s << "CACHE-CONTROL: max-age = " << @cacheControl.to_s << "\r\n"
		s << "DATE: " << Time.now.rfc822 << "\r\n" 
		s << "LOCATION: #{@location}\r\n"
		s << "SERVER: #{@os} UPnP/1.0  product}\r\n"
		s << "ST: #{st}\r\n"
		s << "USN: #{usn}\r\n\r\n"
		return s
	end

=begin
     Client devices searching for devices on the network will send a brief search message via UDP multicast.  This message contains some standard text and two
     parameters - a search target describing what the client is looking for (everything, root device, a specific device or service) and how long to wait in seconds
     before sending the response.
     This method constructs the response based on what the client asked for and also extracts the delay parameter to pass back
     FIXME doesn't handle the case where there's no match between what the client wants and we have
=end
	def handleSearch(message)
		a = Array.new
		line = message.split("\n")
		
		if /^M-SEARCH.*/ =~ line[0] 
			line.each_index {|n| @log.debug n.to_s + ":#{line[n]}" }
		else
			@log.debug "Not a search:#{line[0]}"
			return 0,a
		end
		
		# run through the message looking for the MX and ST records - note these should be in lines 3 and 4 but not all clients respect that so we go through each line
		delay = nil
		target = nil
		line.each do |l|
			if (delay == nil)
				/^MX: (?<delay>\w+)/ =~ l
			end
			if (target == nil)
				/^ST: (?<target>.*)/ =~ l
			end
		end
		
		if target == nil  # didn't find an ST record so this wasn't an SSDP search request
			return 0, a
		else
			target.chomp!
			@log.debug "Search target:#{target}:"
			if target == "ssdp:all"
				a << createSearchResponse("upnp:rootdevice","uuid:#{@uuid}::upnp:rootdevice")
				@devices.each_value do |d|
					d.deviceMessages.each do |n|
						a << createSearchResponse(n[0],n[1])
					end
					d.serviceMessages.each do |n|
						a << createSearchResponse(n[0],n[1])
					end
				end
			elsif target == "upnp:rootdevice"
				a << createSearchResponse("upnp:rootdevice","uuid:#{@uuid}::upnp:rootdevice")
			else
				/^urn:schemas-upnp-org:device:(?<deviceType>\w+):(?<deviceVersion>\d+)$/ =~ target
				/^urn:schemas-upnp-org:service:(?<serviceType>\w+):(?<serviceVersion>\d+)$/ =~ target
				/^uuid:(?<uniqueDevice>.*)$/ =~ target
				if uniqueDevice != nil
					devices.each_value do |d|
						if uniqueDevice == d.uuid
							a << createSearchResponse("uuid:#{@uuid}","uuid:#{@uuid}")
						end
					end
				elsif (serviceVersion != nil) && (serviceType != nil)
					devices.each_value do |d|
						d.services.each do |s|
							if (s.type == serviceType) && (s.version >= serviceVersion.to_i)
								a << createSearchResponse("urn:schemas-upnp-org:service:#{serviceType}:#{serviceVersion}","uuid:#{d.uuid}:urn:schemas-upnp-org:service:#{serviceType}:#{serviceVersion}")
							end
						end
					end
				elsif (deviceVersion != nil) && (deviceType != nil)
					devices.each_value do |d|
						if (d.type == deviceType) && (d.version >= deviceVersion.to_i)
							a << createSearchResponse("urn:schemas-upnp-org:device:#{deviceType}:#{deviceVersion}","uuid:#{d.uuid}:urn:schemas-upnp-org:device:#{deviceType}:#{deviceVersion}")
						end
					end
				end
			end
		end
			
			
		return delay, a
	end
		
=begin rdoc

Sets up a series of threads to
	- listen to SSDP requests and create responses, adding them to a queue to be sent out
	- create advertisements to be added to the same queue
	- send out the messages on the queue

Returns the last of these threads (the sender one) so that the main program can terminate it gracefully

=end

	def discoveryStart
		@discoveryRunning = TRUE
		@ssdpMessages = Queue.new
		
		#set up socket for receiving multicasts
	
		rip =  IPAddr.new(MULTICAST_ADDR).hton + IPAddr.new("0.0.0.0").hton
		rsock = UDPSocket.new
		rsock.setsockopt(:SOCKET,:REUSEADDR,1)
		#rsock.bind(Socket::INADDR_ANY, PORT)
		rsock.bind(MULTICAST_ADDR,PORT)
		rsock.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, rip)
	

		# set up two sockets for sending (normal responses and multicast adverts)

		ssock = UDPSocket.open
		ssock.setsockopt(:SOCKET,:REUSEADDR,1)
		ssock.bind(@ip,PORT)
		msock = UDPSocket.open
		msock.setsockopt(:IP, :TTL, 4)
		
		# Thread to listen for SSDP search requests and send response

		ssdpResponder = Thread.new do
			
			
			while @discoveryRunning do
				
				@log.debug "Responder: Waiting for multicast message"
				rmsg,rinfo = rsock.recvfrom(1024)
				@log.debug "Responder: Received multicast message from #{rinfo[3]}:#{rinfo[1]}"
				
				begin
				
				d, r = handleSearch(rmsg)
				
				@log.debug "Responder: handleSearch returned"
				
				if (!r.empty?)
					#@log.debug "Responder: " + r.join("\n")
					@log.debug "Valid search request, creating response"
					# pass an array of four values onto the queue, the IP address and port of the requestor
					# the time in seconds the requestor said it would wait for a response
					# finally the response messages (itself an array)
					@ssdpMessages.push([rinfo[3], rinfo[1], d, r ])
				else
					@log.debug "Invalid search request"
				end
				
				rescue StandardError => detail
					
					@log.debug detail.to_s
					@log.debug detail.backtrace.join("\n")
				
				end
				@log.debug "Responder: ready to go round again"
			end
			
		end
		
		# Thread to put out advertisements at the beginning and odd intervals thereafter
		
		ssdpAdvertiser = Thread.new do
			
			while @discoveryRunning do
				@log.debug "Ad " 
				@ssdpMessages.push([MULTICAST_ADDR, PORT, 0, keepAlive])
				@log.debug "Ad (pushed) #{@ssdpMessages.size} " 
				sleep (cacheControl * (0.1 + (rand * 0.4)))
			end
		end
		
		# Thread to send the messages
		
		ssdpSender = Thread.new do
			
			while (@discoveryRunning || !@ssdpMessages.empty?) do
				@log.debug"Sender: Queue size is #{@ssdpMessages.size} " 
				if (!@discoveryRunning)
					@log.debug "Sender: (in cleanup)" 
				end
				@log.debug "Sender: (about to pop)"
				
				m = @ssdpMessages.pop #should block here if nothing in queue, which is fine
				
				@log.debug "Sender: (popped) " 
				dip = m[0]
				dp = m[1]
				d = m[2]
				r = m[3]
				if dip == MULTICAST_ADDR
					3.times do
						r.each do |msg|
							begin
								@log.debug "Sender: multicasting "
								msock.send msg, 0, MULTICAST_ADDR, PORT
							end
							sleep (0.05 + (rand * 0.1))
						end
					end
				else
					r.each do |msg|
						begin
							@log.debug "Sender: responding to #{dip}:#{dp}"
							ssock.send msg, 0, dip, dp
							@log.debug "Sender: response apparently sent"
						end
						sleep( 0.05 + (rand * 0.1))
					end
				end
				@log.debug "Sender: (looping round again)"
			end
			
			# if we've reached this point then we need to stop the other threads and clean up the sockets
			@log.debug "Send (final) " + Time.now.to_s
			ssdpAdvertiser.kill
			ssdpResponder.kill
			ssock.close
			msock.close
			rsock.close
				
		end
			
		return ssdpSender	
		
	end
	
=begin rdoc
Signals that the Discovery threads should be shut down.  Requires the value of the "sender" thread returned from
discoveryStart as an argument

=end
	def discoveryStop(senderthread)
		
		#load queue with SSDP:ByeBye messages 
		
		@log.debug "Stop " 
		@ssdpMessages.push([MULTICAST_ADDR, PORT, 0, byeBye])
		@log.debug "Stop (pushed) #{@ssdpMessages.size}" 
		@discoveryRunning = FALSE
		@log.debug "Stop (@dR false) " 
		
		senderthread.join
	end
	
	def handleDescription(req)
		@log.debug("Description request: #{req}")
		b = String.new
		b = createDescriptionXML.to_s
		return b
	end
	
	def webServerStart

		@log.debug "Description address is #{@descriptionAddr}"

		@webserver.mount_proc @descriptionAddr do |req,res|
			b = handleDescription(req)
			res.body = b
			res.content_type = "text/xml"
		end
	

		#@webserver.mount_proc d.presentationAddr do |req,res|
		#	r, b = d.handlePresentation(req)
		#	res.body = b
		#end
		
		@log.debug "Services mounted at: /#{URLBase}/services"
		
		@webserver.mount "/#{URLBase}/services", HandleServices, self
		

		@webserver.start
		
	end
	
	def webServerStop
		@webserver.shutdown
	end
	
end 
end

=begin rdoc
This class has to live outside the main UPnP class hierarchy because it is derived from Webrick
However the root UPnP object is passed to it from Webrick as options[0]
From that we can process the request
=end

class HandleServices < WEBrick::HTTPServlet::AbstractServlet
	
	def do_GET (req, res)
		root = @options[0]
		device = nil
		service = nil
		what = nil
		
		/.*#{Regexp.quote(UPnP::URLBase)}\/services\/(?<device>.*)\/(?<service>.*)\/(?<what>.*)\.xml/ =~ req.path
		
		r =  "Path is #{req.path}, and from that we have derived\r\n"
		r << "Device: #{device}  " if device
		r << "Service: #{service}  " if service
		r << "What: #{what}  " if what
		
		res.body = r
	end
end