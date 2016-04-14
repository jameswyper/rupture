
require 'securerandom'
require 'time'
require 'pry'
require 'rexml/document'

URLBase = "rupture"

class UPnPIcon
	attr_reader :type, :width, :height, :depth, :path, :url
	def initialize(t,w,h,d,p)
		@type = t
		@width = w
		@height = h
		@depth = d
		@path = p
		@url = "icons/" + SecureRandom.uuid
	end
end

class UPnPDevice
	
	#list all device properties and whether they are mandatory or optional
	
	@@allProperties = {
	"friendlyName" => "M" ,
	"manufacturer" => "M" ,
	"manufacturerURL" => "O",
	"modelDescription" => "O",
	"modelname" => "M"
	"modelNumber" => "M"
	"modelURL" => "O"
	"serialNumber" => "O"
	"UPC" => "O"
	} 
	
	def initialize(name,type,version)
		@services=Array.new
		@uuid=SecureRandom.uuid
		@name=name
		@type=type
		@version=version
		@properties = Hash.new
		@icons = Array.new
	end
	
	def addService(service)
		@services << service
	end
	
	attr_reader :services, :name, :uuid, :type, :version
	attr_accessor :properties, :icons
	
	def deviceMessages
		a = Array.new
		a << ["uuid:#{@uuid}","uuid:#{@uuid}"]
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
	
	def deviceXMLDescription
		a  = Array.new
		
		a << REXML::Element.new("deviceType").add_text("urn:schemas-upnp-org:device:#{@type}:#{@version}").dup
		a << REXML::Element.new("UDN").add_text("uuid:#{@uuid}").dup
		
		@@allProperties.each_key do |k|
			v = @properties[k] 
			if v != nil
				a << REXML::Element.new(k).add_text(v).dup
			end
		end
		
		if @icons.size > 0
			il = REXML::Element.new("iconList")
			@icons.each do |i|
				ix = REXML::Element.new "icon"
				ix.add_element("mimetype").add_text("image/#{i.type}")
				ix.add_element("width").add_text(i.width)
				ix.add_element("height").add_text(i.height)
				ix.add_element("depth").add_text(i.depth)
				ix.add_element("URL").add_text(i.URL)
				il.add_element(ix.dup)
			end
		end
		a << il
		
		sl = REXML::Element.new("serviceList")
		@services.each do |s|
			sx = REXML::Element.new "service"
			sx.add_element("serviceType").add_text("urn:schemas-upnp-org:service:#{s.type}:#{s.version}")
			sx.add_element("serviceID").add_text("urn:upnp-org:serviceID:"+s.id)
			sx.add_element("SCPDURL").add_text("#{URLBase}/#{@name}/SCPD/#{s.type}/#{s.version}")
			sx.add_element("controlURL").add_text("#{URLBase}/#{@name}/control/#{s.type}/#{s.version}")
			sx.add_element("eventSubURL").add_text("#{URLBase}/#{@name}/events/#{s.type}/#{s.version}")
			sl.add_element(sx.dup)
		end
		a << sl
		
		#consider linking a device to a service, so instance of a service is one associated to a device
		#means we can store URLS inside the service instance
		#I think we have to do this really as devices cannot share service instances
		#also means we can set up service ID properly
		
		# next steps - maybe move service XML into service class
		# check usage of URLbase is legit
		# method to assemble root device description and return it
		
		return a
	end
end


class UPnPRootDevice < UPnPDevice

	NOTIFY  = "NOTIFY * HTTP/1.1"
	HOST = "HOST: 239.255.255.250:1900"
	
	attr_reader :devices

	def initialize(type,version,ip,port,product)
		super("root",type,version)
		@devices=Hash.new
		addDevice(self)
		@location= "http://#{ip}:#{port}/#{URLBase}/description"
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
			d.deviceMessages.each do |n|
				a << createAliveMessage(n[0],n[1])
			end
			d.serviceMessages.each do |n|
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
		a << createByeByeMessage("upnp:rootdevice","#{@uuid}::upnp:rootdevice")
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

	def createSearchResponse(st,usn)
		s = String.new
		s << NOTIFY << " 200 OK \n" 
		s << "CACHE-CONTROL: " << @cacheControl.to_s << "\n"
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
		/ST: (?<target>.*)/ =~ line[4]
		target.chomp!
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
						#binding.pry
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
			
			
		return delay, a
	end
		
	
end

class UPnPService
	attr_reader :type, :version, :actions, :stateVariables
	
	def initialize(t, v)
		@type = t
		@version = v
		@actions = Hash.new
		@stateVariables =  Hash.new
	end
	
	def addStateVariable(s)
		@stateVariables[s.name]  = s
	end
	
	def addAction(a)
		@actions[a.name] = a
	end
	
end

class UPnPArgument
	
	attr_reader :name, :relatedStateVariable, :direction
	
	def initialize(n,d,s)
		@name = n
		@relatedStateVariable = s
		@direction = d
	end
end

class UPnPAction
	
	attr_reader :name, :args
	
	def initialize(n)
		@name = n
		@args = Hash.new
	end
	
	def addArgument(arg)
		@args[arg.name] = arg
	end
		
end

class UPnPStateVariable
	
	attr_reader:name, :value, :defaultValue, :type, :allowedValues, :allowedMax, :allowedMin, :allowedIncrement
		
	def initialize(n, t, dv, av, amx, amn, ai)
		@name = n
		@defaultValue = dv
		@type = t
		@allowedValues = av
		@allowedMax = amx
		@allowedMin = amn
		@allowedIncrement = ai
	end
	
	
end
