
require 'securerandom'
require 'time'

class UPnPDevice
	
	def initialize(name,type,version)
		@services=Array.new
		@uuid=SecureRandom.uuid
		@name=name
		@type=type
		@version=version
	end
	
	def addService(service)
		@services << service
	end
	
	attr_reader :services, :name, :uuid, :type, :version
	
	def deviceMessages
		a = Array.new
		a. << ["uuid:#{@uuid}","uuid:#{@uuid}"]
		a << ["urn:schemas-upnp-org:device:#{@type}:#{@version}","uuid:#{@uuid}:urn:schemas-upnp-org:device:#{@type}:#{@version}"]
		return a
	end
		
	def serviceMessages
		a = Array.new
		@services.each do |s|
			a << ["urn:schemas-upnp-org:service:#{s.type}:#{s.version}","uuid:#{@uuid}:urn:schemas-upnp-org:service:#{s.type}:#{s.version}"]
		end
		return a
	end
	
end


class UPnPRootDevice < UPnPDevice

	NOTIFY  = "NOTIFY * HTTP/1.1"
	HOST = "HOST: 239.255.255.250:1900"

	def initialize(type,version,ip,port,product)
		super("root",type,version)
		@devices=Hash.new
		addDevice(self)
		@location= "http://#{ip}:#{port}/rupture/description"
		@product = product
		@os = "Linux/3" #this should be dynamic but who uses it?
		@cacheControl = 1800
	end

	def addDevice(device)
		@devices.store(device.name,device)
	end
	
	def createAliveMessage(nt,usn) #creates a single message to multicast
		s = String.new
		s << NOTIFY << "\n" << HOST << "\n"
		s << "CACHE-CONTROL: " << @cachecontrol.to_s << "\n"
		s << "LOCATION: #{@location}\n"
		s << "NT: #{nt}\n"
		s << "NTS: ssdp:alive\n"
		s << "SERVER: #{@os} UPnP/1.0 #{@product}\n"
		s << "USN: #{usn}\n\n"
		return s
	end
	
	def keepAlive #creates all messages for root & embedded devices and services
		a = Array.new
		a << createAliveMessage("upnp:rootdevice","uuid:#{@uuid}::upnp:rootdevice")
		@devices.each_value do |d|
			d.deviceMessages do |n|
				a << createAliveMessage(n[0],n[1])
			end
			d.serviceMessages do |n|
				a << createAliveMessage(n[0],n[1])
			end
		end
		return a
	end
	
	def createByeByeMessage(nt,usn)
		s = String.new
		s << NOTIFY << "\n" << HOST << "\n"
		s << "NT: #{nt}\n"
		s << "NTS: ssdp:byebye\n"
		s << "USN: uuid:#{usn}\n\n"
		return s
	end
	
	def byeBye
		a = Array.new
		a << createByeByeMessage("upnp:rootdevice","uuid:#{@uuid}::upnp:rootdevice")
		@devices.each_value do |d|
			d.deviceMessages do |n|
				a << createByeByeMessage(n[0],n[1])
			end
			d.serviceMessages do |n|
				a << createByeByeMessage(n[0],n[1])
			end
		end
		return a
	end

	def createSearchResponse(st,usn)
		s = String.new
		s << NOTIFY << "200 OK \n" 
		s << "CACHE-CONTROL: " << @cachecontrol.to_s << "\n"
		s << "DATE: " << Time.now.rfc822 << "\n" 
		s << "LOCATION: #{@location}\n"
		s << "SERVER: #{@os} UPnP/1.0 #{@product}\n"
		s << "ST: #{st}\n"
		s << "USN: #{usn}\n\n"
		return s
	end


	def handleSearch(message)
		a = Array.new
		line = message.split("\n")
		/MX: (?<delay>\w+)/ =~ line[3]
		/ST: (?<target>\w+)/ =~ line[4]
		target.chomp!
		if target == "ssdp:all"
			# return everything
		elsif target == "upnp:rootdevice"
			a << createSearchResponse("upnp:rootdevice","uuid:#{@uuid}::upnp:rootdevice")
		else
			/^urn:schemas-upnp-org:device:(?<deviceType>\w+):(?<deviceVersion>\w+)$/ =~ target
			/^urn:schemas-upnp-org:service:(?<serviceType>\w+):(?<serviceVersion>\w+)$/ =~ target
			/^uuid:(?<uniqueDevice>\w+)$/ =~ target
			if uniqueDevice != nil
				devices.each_value do |d|
					if uniqueDevice == d.uuid
						a << createSearchResponse("uuid:#{@uuid}","uuid:#{@uuid}")
					end
				end
			elsif (serviceVersion != nil) && (serviceType != nil)
				# return matching services
			elsif (deviceVersion != nil) && (deviceType != nil)
				# return matching devices
			end
		end
			
			
		return delay, a
	end
		
	
end

class UPnPService
	attr_reader :type, :version
	
	def initialize(t, v)
		type = t
		version = v
	end
	
end
