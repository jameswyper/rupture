
require 'time'
require 'pry'
require 'rexml/document'
require 'rexml/xmldecl'
require 'logger'
require_relative 'common'
require_relative 'icon'

module UPnP


=begin rdoc
  The base class describing a UPnP device.  Implementations should derive a class from this or #UPnPRootDevice depending on how the devices are modelled.
  The UPnP specification allows for devices to be contained within a root device, or for there to be just a single root device.
  I can't see why anyone would want to bother set up contained devices but the code will attempt to handle it.
=end

class Device
	
	# Hash containing all valid device properties from the UPnP spec that are used in Description, and whether they are mandatory or optional
	# The properties variable will hold the actual properties used in this device
	@@allProperties = {
	:friendlyName => :M ,
	:manufacturer => :M ,
	:manufacturerURL => :O,
	:modelDescription => :O,
	:modelName => :M,
	:modelNumber => :M,
	:modelURL => :M,
	:serialNumber => :O,
	:UPC => :O
	} 
	
=begin rdoc
     initialiser MUST be called with the following parameters in the hash; in descending order of importance:
     
       
	:Type (e.g MediaServer)
	:Version (e.g. 1)
	:Name (e.g. "device1"), will be used to form URLs - really only needed when embedding devices
	:FriendlyName (typically this is what clients display)


	(the next four only appear to be used in device description)
	
	:Manufacturer
	:ModelName
	:ModelNumber
	:ModelURL 
	
	The following parameters are optional:
	
	:URLBase - start of URL for all web services e.g. if set to pyjamas then the addresses all start 127.0.0.1:60000/pyjamas/..
	
	(the next four only appear to be used in device description, if they aren't set XML tags won't be created for them)

	:ManufacturerURL 
	:ModelDescription
	:SerialNumber
	:UPC 
	
=end	


	attr_accessor :services

	def initialize(params)
		
		[:type, :version, :name, :friendlyName, 
		:manufacturer,	:modelName, :modelNumber, :modelURL ].each do |p|
			if (params[p] == nil)
				raise "Device initialize method: required parameter :#{p} missing"
			end
		end
		
		@urlBase = (params[:URLBase])
		if (!@urlBase)
			@urlBase = 'tapiola'
		end
		
		@services=Hash.new
		@uuid=SecureRandom.uuid
		@name=params[:name]
		@type=params[:type]
		@version=params[:version]
		@properties = Hash.new
		@@allProperties.each_key { |k| if (params[k]) then @properties[k] = params[k] end }
		@icons = Array.new
		@presentationAddr = "#{urlBase}/presentation/#{@name}/presentation.html"
	end
	
	# trivial method to add a new service to the list of supported ones.  Expected to be called during setup only.  No support for removing services.
	def addService(service)
		if (@services[service.type] != nil)
			raise "device addService method: service of type #{service.type} already exists"
		end
		@services[service.type] = service
		service.linkToDevice(self)
	end
	
	# helper method for when root adds an embedded device, this ties the link up in the other direction
	def linkToRoot(root)
		@rootDevice = root
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
	# Base URL for all service, event, presentation and discovery calls
	attr_reader :urlBase
	
=begin rdoc
    The UPnP spec specifies (Step 1 - discovery) that a message is sent on startup, periodically, and in response to a search request with the essential elements of the UPnP root device,
    any embedded devices and services.  This method helps to construct that message for devices.  #serviceMessages does the same for services.  
    They should only be called by the methods in the #UPnPRootDevice class
=end
	def deviceMessages
		a = Array.new
		a << ["uuid:#{@uuid}","uuid:#{@uuid}"]
		a << ["urn:schemas-upnp-org:device:#{@type}:#{@version}","uuid:#{@uuid}::urn:schemas-upnp-org:device:#{@type}:#{@version}"]
		return a
	end
	
=begin rdoc
    Similar helper method to that for #deviceMessages
=end
	def serviceMessages
		a = Array.new
		@services.each_value do |s|
			a << ["urn:schemas-upnp-org:service:#{s.type}:#{s.version}","uuid:#{@uuid}::urn:schemas-upnp-org:service:#{s.type}:#{s.version}"]
		end
		return a
	end
	
=begin rdoc
     For Step 2 - description.  Once a client has discovered a device it will then request more detailed information about the device and the services offered.
     This information is constructed as an XML message. This function creates the XML elements for a device
=end
	
	def getXMLDeviceData
		a  = Array.new
		
		a << REXML::Element.new("deviceType").add_text("urn:schemas-upnp-org:device:#{@type}:#{@version}").dup
		a << REXML::Element.new("UDN").add_text("uuid:#{@uuid}").dup
		
		@@allProperties.each_key do |k|
			v = @properties[k] 
			if v != nil
				a << REXML::Element.new(k.to_s).add_text(v).dup
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
		@services.each_value do |s|
			sx = REXML::Element.new "service"
			sx.add_element("serviceType").add_text("urn:schemas-upnp-org:service:#{s.type}:#{s.version}")
			sx.add_element("serviceId").add_text("urn:upnp-org:serviceId:#{s.type}")
			sx.add_element("SCPDURL").add_text("http://#{@rootDevice.ipPort}/#{s.descAddr}")
			sx.add_element("controlURL").add_text("http://#{@rootDevice.ipPort}/#{s.controlAddr}")
			sx.add_element("eventSubURL").add_text("http://#{@rootDevice.ipPort}/#{s.eventAddr}")
			sl.add_element(sx.dup)
		end
		a << sl
	
		a << REXML::Element.new("presentationURL").add_text("http://#{@rootDevice.ipPort}/#{@presentationAddr}")
				
		return a
	end



	def handlePresentation(req,res,action,url)
		if (url == 'presentation.html')
			res.body = "This is #{@name}"
			return WEBrick::HTTPStatus::OK
		else
			return WEBrick::HTTPStatus::NotFound
		end
	end
	
=begin rdoc
Check that the device data is, so far as we can tell, correct
For now this will just mean checking that the properties are correctly set
=end
	
	def validate
		@@allProperties.each do |k,v|
			if (!@properties[k] && (v == :M))
				raise SetupError, "Mandatory property #{k} missing"
			end
		end
	end
	
end



end