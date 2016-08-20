
require 'securerandom'
require 'time'
require 'pry'
require 'rexml/document'

# Constant - used to namespace the URLs that will be handled e.g. 1.2.3.4/rupture/whatever
URLBase = "rupture"

# Simple structure to hold information about an Icon
class UPnPIcon
	
	# class variable to hold reference (by URL) to each icon
	@@icons = Hash.new
	
	# MIME type e.g "image/png"
	attr_reader :type   
	# width in pixels
	attr_reader :width
	# height in pixels
	attr_reader :height
	# colour depth - bits per pixel
	attr_reader :depth
	# path to where the icon is stored on the filesystem.  Might need to turn this into a method.
	attr_reader :path
	# url where clients will be able to access the icon from
	attr_reader :url
	
	# create an icon object and add it to the collection
	def initialize(t,w,h,d,p)
		@type = t
		@width = w
		@height = h
		@depth = d
		@path = p
		@url = "icons/" + SecureRandom.uuid
		@@icons[@url.dup] = self
	end
	
end

=begin rdoc
  The base class describing a UPnP device.  Implementations should derive a class from this or #UPnPRootDevice depending on how the devices are modelled.
  The UPnP specification allows for devices to be contained within a root device, or for there to be just a single root device.
  I can't see why anyone would want to bother set up contained devices but the code will attempt to handle it.
=end
class UPnPDevice
	
	# Hash containing all valid device properties from the UPnP spec and whether they are mandatory or optional
	# The properties variable will hold the actual properties used in this device
	@@allProperties = {
	"friendlyName" => "M" ,
	"manufacturer" => "M" ,
	"manufacturerURL" => "O",
	"modelDescription" => "O",
	"modelname" => "M",
	"modelNumber" => "M",
	"modelURL" => "O",
	"serialNumber" => "O",
	"UPC" => "O"
	} 
	
=begin rdoc
  [name] the name of the UPnP device
  [type] the type (should be a UPnP standard e.g. MediaServer)
  [version] UPnP device types can have multiple versions, this specifies which one we are supporting
=end 
	def initialize(name,type,version)
		@services=Array.new
		@uuid=SecureRandom.uuid
		@name=name
		@type=type
		@version=version
		@properties = Hash.new
		@icons = Array.new
	end
	
	# trivial method to add a new service to the list of supported ones.  Expected to be called during setup only.  No support for removing services.
	def addService(service)
		@services << service
	end
	
	# set of services supported by the device
	attr_reader :services
	# device name
	attr_accessor :name 
	# Unique ID in uuid format for the device, generated when it is first created
	attr_accessor :uuid 
	# UPnP device type e.g. "MediaServer"
	attr_accessor :type 
	# UPnP device version (an integer)
	attr_accessor :version
	# Hash containing the name and value of all the properties for the device e.g. Manufacturer, Serial Number etc.  All valid properties are held in #allProperties
	attr_accessor :properties
	# Array of icons representing the device
	attr_accessor :icons
	
=begin rdoc
    The UPnP spec specifies (Step 1 - discovery) that a message is sent on startup, periodically, and in response to a search request with the essential elements of the UPnP root device,
    any embedded devices and services.  This method helps to construct that message for devices.  #serviceMessages does the same for services.  
    They should only be needed by the methods in the #UPnPRootDevice class
=end
	def deviceMessages
		a = Array.new
		a << ["uuid:#{@uuid}","uuid:#{@uuid}"]
		a << ["urn:schemas-upnp-org:device:#{@type}:#{@version}","uuid:#{@uuid}:urn:schemas-upnp-org:device:#{@type}:#{@version}"]
		return a
	end
	
=begin rdoc
    Similar helper method to that for #deviceMessages
=end
	def serviceMessages
		a = Array.new
		@services.each do |s|
			a << ["urn:schemas-upnp-org:service:#{s.type}:#{s.version}","uuid:#{@uuid}:urn:schemas-upnp-org:service:#{s.type}:#{s.version}"]
		end
		return a
	end
	
=begin rdoc
     For Step 2 - description.  Once a client has discovered a device it will then request more detailed information about the device and the services offered.
     This information is constructed as an XML message.
=end
	
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
		a << il
		end
		
		
		sl = REXML::Element.new("serviceList")
		@services.each do |s|
			sx = REXML::Element.new "service"
			sx.add_element("serviceType").add_text("urn:schemas-upnp-org:service:#{s.type}:#{s.version}")
			sx.add_element("serviceID").add_text("urn:upnp-org:serviceID:#{s.type}")
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

# standard text for the NOTIFY HTTP header used in Discovery
	NOTIFY  = "NOTIFY * HTTP/1.1"
# standard text for the HOST HTTP header used in Discovery	
	HOST = "HOST: 239.255.255.250:1900"
	
	# any devices contained within the root device.  Not sure if we need to refer to this outside the class so may remove this
	attr_reader :devices
	# Cache-Control value, default to 1800 seconds.  Again may not be needed outside the class
	attr_reader :cacheControl

	def initialize(type,version,ip,port,product)
		super("root",type,version)
		@devices=Hash.new
		addDevice(self)
		@location= "http://#{ip}:#{port}/#{URLBase}/description"
		@product = product
		@os = "Linux/3" #this should be dynamic but who uses it?
		@cacheControl = 1800
	end

# trivial method to add devices to a root device, it's just a list.  No support for removing them.  Should only be called at runtime.
	def addDevice(device)
		@devices.store(device.name,device)
	end
	
# For Step 1 - discovery.  Helper method to create a single message that will be multicast. Called by #keepAlive, not intended to be called elsewhere	
	def createAliveMessage(nt,usn) 
		s = String.new
		s << NOTIFY << "\n" << HOST << "\n"
		s << "CACHE-CONTROL: max-age = " << @cacheControl.to_s << "\n"
		s << "LOCATION: #{@location}\n"
		s << "NT: #{nt}\n"
		s << "NTS: ssdp:alive\n"
		s << "SERVER: #{@os} UPnP/1.0 #{@product}\n"
		s << "USN: #{usn}\n\n"
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
		s << NOTIFY << "\n" << HOST << "\n"
		s << "NT: #{nt}\n"
		s << "NTS: ssdp:byebye\n"
		s << "USN: #{usn}\n\n"
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
		s << NOTIFY << " 200 OK \n" 
		s << "CACHE-CONTROL: " << @cacheControl.to_s << "\n"
		s << "DATE: " << Time.now.rfc822 << "\n" 
		s << "LOCATION: #{@location}\n"
		s << "SERVER: #{@os} UPnP/1.0 #{@product}\n"
		s << "ST: #{st}\n"
		s << "USN: #{usn}\n\n"
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

=begin
   A UPnP Service consists of state variables and actions, this is a simple base class to hold essential information about the service
   A real service should implement a class derived from this one, set up the state variables and actions (which are also derived from simple base classes #UPnPAction
   and #UPnPStateVariable) and use #addStateVariable and #addAction to associate them with the service
   
   
	TODO
	
	each service needs to attach itself to WeBrick as a servlet method (do we need to define the control URL as part of the service?)
	this method will 
	- decode the XML / SOAP request
	- validate the action requested and the parameters passed
	- invoke the action to do the work
	- pick up the error code (if any) from the action and the output parameters
	
	when an Action is invoked it will
	- use the arguments passed to it (in a hash)
	- do whatever it needs to do
	- if any state variables should change it will find them by name (self.service.stateVariables["name"]) and change the value
	- add any out arguments to the hash
	
	each service will need to attach itself to Webrick with an additional servlet method for eventing which will
	- 
   
=end

class UPnPService
	
	# standard UPnP name for the service e.g. ConnectionManager
	attr_reader :type 
	# standard UPnP version, an integer
	attr_reader :version 
	# list of all actions associated with the service
	attr_reader :actions 
	# list of all state variables associated with the service
	attr_reader :stateVariables
	
	# the device this service is attached to
	attr_writer :device
	
	def initialize(t, v)
		@type = t
		@version = v
		@actions = Hash.new
		@stateVariables =  Hash.new
	end
	
	def addStateVariable(s)
		@stateVariables[s.name]  = s
		s.service = self
	end
	
	def addAction(a)
		@actions[a.name] = a
		a.service = self
	end
	
end

class UPnPArgument
	
	# argument name
	attr_reader :name 
	# each argument must be linked to a state variable.  No idea why
	attr_reader :relatedStateVariable
	# whether this is an input or output argument
	attr_reader :direction
	# the action this argument is associated with
	attr_writer :action
	
	def initialize(n,d,s)
		@name = n
		@relatedStateVariable = s
		@direction = d
	end
end

class UPnPAction
	
	# the name of the action
	attr_reader :name
	# Hash containing all the arguments (in and out) associated with this service
	attr_reader :args
	# the service this action is associated with
	attr_writer :service
	
	def initialize(n)
		@name = n
		@args = Hash.new
	end
	
	def addArgument(arg)
		@args[arg.name] = arg
	end
		
end

class UPnPStateVariable
	
	# variable name - should be as per the Service specification
	attr_reader :name 
	# current value - might replace this with proper getter / setter methods
	attr_reader :value 
	# default value for the variable
	attr_reader :defaultValue
	# variable type e.g. int, char, string
	attr_reader :type 
	# pemitted values for strings
	attr_reader :allowedValues
	# maximum value for numbers
	attr_reader :allowedMax
	# minimum value for numbers
	attr_reader :allowedMin
	# the smallest amount the value of this variable (if numeric) can change by
	attr_reader :allowedIncrement
	
		
	def initialize(n, t, dv, av, amx, amn, ai, ev)
		@name = n
		@defaultValue = dv
		@type = t
		@allowedValues = av
		@allowedMax = amx
		@allowedMin = amn
		@allowedIncrement = ai
		@evented = ev
	end
	
	# check if the state variable is evented or not
	def evented? 
		@evented
	end
	
	# assign a new value and trigger eventing if necessary
	def value=(v)
		value =  v
		if (self.evented?)
			
		end
	end
	
	
end
