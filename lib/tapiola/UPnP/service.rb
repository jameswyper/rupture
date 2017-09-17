
require_relative 'common'
require_relative 'stateVariable'
require 'rexml/document'
require 'rexml/xmldecl'

module UPnP

=begin

A UPnP Service consists of state variables and actions, this is a class to hold essential information about the service.

A real service should instantiate this class, set up the state variables and actions (which are also derived from simple base classes #UPnPAction and #UPnPStateVariable) and use #addStateVariable and #addAction to associate them with the service.
   
   
=end

class Service
	
	# standard UPnP name for the service e.g. ConnectionManager
	attr_reader :type 
	# standard UPnP version, an integer
	attr_reader :version 
	# list of all actions associated with the service
	attr_reader :actions 
	# list of all state variables associated with the service
	attr_reader :stateVariables
	# control address (to form control URL with)
	attr_reader :controlAddr
	# description address (to form SCDP URL with)
	attr_reader :descAddr
	# eventing address (to form event subscription URL with)
	attr_reader :eventAddr
	# subscriptions attached to the service
	attr_reader :subscriptions

=begin rdoc
Set up the serivce with the Service Type (e.g. ContentDirectory) and version number
=end
	
	def initialize(t, v)
		@type = t
		@version = v
		@actions = Hash.new
		@stateVariables =  Hash.new
		@subscriptions = Hash.new
	end
	
=begin rdoc
Links a State Variable to the service
=end
	def addStateVariable(s)
		@stateVariables[s.name]  = s
		s.service = self
	end
	
=begin rdoc
Convenience method - links multiple state variables to the service
=end
	def addStateVariables(*a)
		a.each { |s| addStateVariable(s) }
	end
	
=begin rdoc
Links an Action to the service
=end
	def addAction(a)
		@actions[a.name] = a
		a.linkToService(self)
	end
	
=begin rdoc
Links multiple Actions to the service
=end
	def addActions(*a)
		a.each {|s| addAction(s)}
	end
	
=begin rdoc
Links the Service to a UPnP Device
=end
	def linkToDevice(d)
		@device = d
		servAddr = "#{d.urlBase}/services/#{d.name}/#{@type}/"
		@eventAddr = servAddr + "event.xml"
		@controlAddr = servAddr + "control.xml"
		@descAddr = servAddr + "description.xml"
		@log = @device.rootDevice.log
	end
	
=begin rdoc
returns a REXML::Document object containing the UPnP Service Description XML
=end
	def createDescriptionXML
		
		rootE =  REXML::Element.new("scpd")
		rootE.add_namespace("urn:schemas-upnp-org:device-1-0")
		
		spv = REXML::Element.new("specVersion")
		spv.add_element("major").add_text("1")
		spv.add_element("minor").add_text("0")
		rootE.add_element(spv)

		al = REXML::Element.new("actionList")
		@actions.each_value do |a|
			ae = REXML::Element.new("action")
			ae.add_element("name").add_text(a.name)
			gle = REXML::Element.new("argumentList")
			ae.add_element(gle)
			x = Array.new
			a.args.each_value { |ag| x << ag }
			x.sort! {|a,b| [a.arg.direction, a.seq] <=> [b.arg.direction, b.seq]}
			x.each do |ag|
				g = ag.arg
				ge = REXML::Element.new("argument")
				ge.add_element("name").add_text(g.name)
				ge.add_element("direction").add_text(g.direction.to_s)
				if (g.returnValue?)
					ge.add_element("retval")
				end
				ge.add_element("relatedStateVariable").add_text(g.relatedStateVariable.name)
				gle.add_element(ge)
			end
			al.add_element(ae)
		end
		
		svl = REXML::Element.new("serviceStateTable")
		@stateVariables.each_value do |sv|
			sve = REXML::Element.new("stateVariable")
			if sv.evented?
				sve.add_attribute("sendEvents","yes")
			else
				sve.add_attribute("sendEvents","no")
			end
			sve.add_element("name").add_text(sv.name)
			sve.add_element("dataType").add_text(sv.type)
			sve.add_element("defaultValue").add_text(sv.defaultValue) if (sv.defaultValue)
			if sv.allowedValueList?
				avle = REXML::Element.new("allowedValueList")
				sv.allowedValues.each_value do |v|
					avle.add_element("allowedValue").add_text(v.to_s)
				end
				sve.add_element(avle)
			elsif	sv.allowedValueRange?
				avre = REXML::Element.new("allowedValueRange")
				avre.add_element("minimum").add_text(sv.allowedMin)
				avre.add_element("maximum").add_text(sv.allowedMax)				
				avre.add_element("step").add_text(sv.allowedIncrement)
				sve.add_element(avre)
			end
			svl.add_element(sve)
		end
		
		rootE.add_element(al)
		rootE.add_element(svl)
		
		doc = REXML::Document.new
		doc << REXML::XMLDecl.new(1.0)
		doc.add_element(rootE)
		
		return doc

	end
	
	
	def handleEvent(req, res)
	
	#decode the XML
	#new cancel or renew?
	#
	#new - set up new subscription
	s = Subscription.new(callbackHeader, expiry)
	unless s.invalid? then @subscriptions[s.sid] = s end
	
	#new - send events - needs to be deferred for later, how?
	#
	#cancel - find subscription 
	#cancel - set subscription to expired
	#
	#renew - find subscription
	#renew - set expiry time
	
	#delete expired subscriptions
	
	#create response
	
	
	
	end
	
=begin
Takes the XML sent by a control point (and the SOAPACTION part of the http header), validates it and extracts the name and arguments of the action requested.
=end
	def processActionXML(xml,soapaction)

		@log.debug("XML: #{xml}")
		@log.debug("soapaction field: #{soapaction}")
		
		re = /^"(.*)#(.*)"$/
		md = re.match(soapaction)
		
		if (md != nil) && (md[1] != nil) && (md[2] != nil)
			namespace = md[1]
			action = md[2]
		else
			@log.warn("SOAPACTION header invalid - was :#{soapaction}:")
			raise ActionError.new(401)
		end
		@log.debug ("Namespace #{namespace} and Action #{action} obtained from header")


		begin
			doc = REXML::Document.new xml
		rescue REXML::ParseException => e
			@log.warn("XML didn't parse #{e}")
			raise ActionError.new(401)
		end

		soapbody = REXML::XPath.first(doc, "//m:Envelope/m:Body", {"m"=>"http://schemas.xmlsoap.org/soap/envelope/"})
		unless soapbody
			@log.warn("Couldn't get SOAP body out of #{xml}")
			raise ActionError.new(401)
		end
		
		argsxml =  REXML::XPath.first(soapbody,"//p:#{action}",{"p" => "#{namespace}"})
		unless argsxml
			@log.warn("Couldn't get action name out of #{xml} with SOAPACTION header :#{soapaction}:")
			raise ActionError.new(401)
		end

		if (action != argsxml.name)
			@log.warn("SOAPACTION header :#{soapaction}: didn't match XML name #{xml}")
			raise ActionError,401
		end

		args = Hash.new
		
		argsxml.elements.each {|e| args[e.name] = e.text}
		
		return action, args

	end
	
=begin rdoc
Called by the Webserver when something is posted to the Control URL for the service.
Extracts the requested action and arguments (via call to #processActionXML)
Checks that the action exists
Validates the arguments passed in
Invokes the action
Validates the arguments passed back from the invoke
Constructs a response indicating success or failure
=end
	def handleControl(req, res)
	
		@log.debug("in handleControl for service #{@name}")
	
		begin
			actionname, args = processActionXML(req.body,req.header["soapaction"].join)
			action = @actions[actionname]
			if action == nil
				@log.warn("Action #{actionname} doesn't exist in service #{@name}")
				raise ActionError.new(401)
			else
				action.validateInArgs(args)
				outArgs = action.invoke(args)
				action.validateOutArgs(outArgs)
				action.responseOK(res,outArgs)
			end
		rescue ActionError => e
			@log.warn("Service #{@name}, Exception message #{e.message}")
			responseError(res,e.code)
		end
	
	end

=begin rdoc
Called by the Webserver when something is requested from the Description URL for the service.
Returns the service description in XML format
=end

	
	def handleDescription(req, res)
		@log.debug("Description (service) request: #{req}")
		res.body = createDescriptionXML.to_s
		res.content_type = "text/xml"
	end
	
=begin rdoc
Not sure if I need to put anything here yet
=end
	def validate
	end
		
end


=begin rdoc
The argument class defines a single parameter that is passed in or out of the server during the Control process.  Note that it contains just the "metadata" about the argument in general, not the value of any one argument during a call in particular

=end

class Argument
	
	# argument name
	attr_reader :name 
	# each argument must be linked to a state variable.  No idea why
	attr_reader :relatedStateVariable
	# whether this is an input or output argument
	attr_reader :direction
	# the action this argument is associated with
	attr_writer :action
	
	
=begin rdoc

Initialize with 
Name
Direction, either :in or :out
Related State Variable - needs to be a StateVariable object
Return Value flag - if this is the return value for the Action set to true. Defaults to false

=end
	
	def initialize(n,d,s, r=false)

		if ((d != :in) && (d != :out))  then raise "Argument initialize method: direction not :in or :out, was #{d}" end
		
		@name = n
		@relatedStateVariable = s
		@direction = d
		@retval = r
	end
	
	def returnValue?
		@retval
	end
	
	def linkToAction(a)
		@action = a
	end
end

# Structure to hold Argument and Sequence pair
ArgSeq = Struct.new(:arg, :seq)

class Action
	
	# the name of the action
	attr_reader :name
	# Hash containing all the arguments (in and out) associated with this service
	attr_reader :args
	# Array containing the out arguments only
	attr_reader :outArgs
	# Array containing the in arguments only
	attr_reader :inArgs
	# Retval argument
	attr_reader :returnArg
	# Service this Action is linked to
	attr_reader :service
	
=begin rdoc
Called with the name of the action and a (non-UPnP) object / method that will be invoked to do the actual work
=end
	
	def initialize(name, obj, method)
		@name = name
		@args = Hash.new
		@inArgs = Hash.new
		@outArgs = Hash.new
		@retArg = nil
		@object = obj
		@method = method
	end
	
=begin rdoc
Tiny helper method to return the entries in the @outArgs hash in sequence
=end
	
	def outArgsInSequence
		return @outArgs.values.sort! { |x,y| x.seq <=> y.seq }
	end
	
=begin rdoc
Adds an existing argument to the Action.  The spec says that arguments must have a defined sequence, so a sequence number (starting from 1) must be passed as well as the argument object to be added.  Populates the @inArgs and @outArgs hashes
=end
	
	def addArgument(arg, seq)


		if (@args[arg.name]) then raise SetupError, "Action addArgument method: attempting to add duplicate argument #{arg.name}" end

		@args.each_value do |checkArg|
			if (checkArg.arg.direction == arg.direction) && (checkArg.seq == seq)
				raise SetupError, "Attempting to add duplicate sequence for #{arg.direction}, #{seq}"
			end
		end

		@args[arg.name] = ArgSeq[arg, seq]
		arg.linkToAction(self)
		
		if (arg.direction == :in)
			@inArgs[arg.name] = ArgSeq[arg, seq]
		else
			@outArgs[arg.name] = ArgSeq[arg, seq]
		end
		
		if (arg.returnValue?)
			
			if (seq != 1) then raise SetupError, "Action addArgument method: return value must be first Out argument added" end
			@retArg = arg

		end
		

		
	end
		
=begin rdoc
	Associates the Action with a Service object
=end
		
	def linkToService(s)
		@service = s
	end
	
=begin rdoc

	The object / method passed to the Action during initialisation is called.  This is how non-UPnP code is linked to the UPnP processing.  The method MUST accept the following, in order:
	
	Hash containing all the parameters (in arguments) the action was invoked with (name/value pairs)
	Service object (so that State Variables may be changed)
	
	The method should (via the service object) change any State Variables that it needs to
	The method may be called concurrently, if this is a problem then use a Mutex or similar approach inside the 	thread-critical code to ensure it's single threaded (it will be necessary to do this when appending to a State Variable or	incrementing a count held in one, for example)
	
	The method MUST return a Hash containing name/value pairs of all out arguements.
	If it encounters an error it must raise an ActionError exception

=end
	
	def invoke(params)

		if !(@object.respond_to?(@method))
			raise ActionError.new(402)
			@log.error("Can't invoke #{@method} on #{@object}")
		else
			begin
				outargs = @object.send(@method,params,@service)
			rescue ActionError => e
				@log.error("Problem when invoking #{@method} on #{@object} #{e}")
				raise
			end
		end

	end
	
	
=begin rdoc
Private method; takes a name/value hash of Arguments passed to the the action and compares it
with a hash of expected arguments
=end
	
	def validateArgs(args, expArgs)
		
		# check that the number of arguments passed in is what's expected
		if (args == nil)
			@log.warn("No Arguments to validate #{@service.name} - #{@name}")
			raise ActionError.new(402)
		end
		
		if args.size != expArgs.size
			@log.warn("Argument size mismatch for #{@service.name} - #{@name}, expected #{expArgs.each_key.join('/')} but got #{args.each_key.join('/')}")
			raise ActionError.new(402)
		end
		
		# check that the names of the arguments passed in are what's expected
		#  I love the next line of code, it's amazing how Ruby lets you do so much writing so little
		
		args.each_key.sort.zip(expArgs.each_key.sort).each do |argpair| 			
			if argpair[0] != argpair[1]
				@log.warn("Argument name mismatch for #{@service.name} - #{@name}, expected #{expArgs.each_key.join('/')} but got #{args.each_key.join('/')}")
				raise ActionError,402
			end
		end
		

		
	end

=begin rdoc
Checks that the arguments in the name/value hash passed to the method: 
1. match up with the expected argument names in @inArgs
2. have valid values (when validated against RelatedStateVariable for the argument)
=end
	def validateInArgs(args)
		
		validateArgs(args,@inArgs)
		
		args.each_pair do |name,value|
			sv = @inArgs[name].arg.relatedStateVariable
			begin
				args[name] = sv.interpret(value)
			rescue StateVariableError => e
				raise ActionError.new(600), e.message
			rescue StateVariableRangeError
				raise ActionError.new(601), e.message
			end
		end
		
	end

=begin rdoc
Checks that the arguments in the name/value hash passed to the method atch up with the expected argument names in @outArgs
=end

	def validateOutArgs(args)
		validateArgs(args,@outArgs)

	end
	
=begin rdoc
Populates the httpResponse object passed from the webserver with the correct headers and xml for a successful response to an Action call
=end
	
	def responseOK(res,args)
	
=begin
HTTP/1.1 200 OK
CONTENT-LENGTH: bytes in body
CONTENT-TYPE: text/xml; charset="utf-8"
DATE: when response was generated
EXT:
SERVER: OS/version UPnP/1.0 product/version
<?xml version="1.0"?>
<s:Envelope
xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
<s:Body>
<u:actionNameResponse xmlns:u="urn:schemas-upnp-org:service:serviceType:v">
<argumentName>out arg value</argumentName>
other out args and their values go here, if any
</u:actionNameResponse>
</s:Body>
</s:Envelope>
=end
		
		
		#create response body (xml) and headers
		rootE =  REXML::Element.new("s:Envelope")
		rootE.add_namespace("s","http://schemas.xmlsoap.org/soap/envelope/")
		rootE.attributes["s:encodingStyle"] = "http://schemas.xmlsoap.org/soap/encoding/"
		
		bod = REXML::Element.new("s:Body")
		
		resp = REXML::Element.new("u:#{@name}Response")
		resp.add_namespace("u","urn:schemas-upnp-org:service:#{@service.type}:#{@service.version}")

		
		outArgsInSequence.each do |arg|
			a  = REXML::Element.new("u:#{arg[0].name}")
			value = args[arg[0].name].to_s
			stringValue = arg[0].relatedStateVariable.represent(value)
			a.add_text(stringValue)  
			resp.add_element(a)
		end
		
		bod.add_element(resp)
		rootE.add_element(bod)
		
		
		doc = REXML::Document.new
		doc.context[:attribute_quote] = :quote
		doc << REXML::XMLDecl.new(1.0)
		doc.add_element(rootE)
		
		doc.write(res.body,2)

	end

=begin rdoc
Populates the httpResponse object passed from the webserver with the correct headers and xml for an unsuccessful response to an Action call
=end

	def responseError(res,code)
		#create response body (xml) and headers
		res.body = "not OK #{code}"
	end
	
	private :validateArgs
	
end



class Subscription
	attr_reader :sid
	attr_reader :expiryTime
	attr_reader :callbackURLs
	attr_reader :eventSeq
	
	def initialise(callback, expiry)
		self.renew(expiry)
		@callbackURLs = Array.new
		@sid = SecureRandom.uuid
		@eventSeq = 0
		#TODO #parse callback line and put into array
		#TODO find a way of ensuring all evented variables are sent
		
		#if callback can't be parsedlog.warn
	end
	
	def expired?
		(@expiryTime <= Time.now)
	end
	
	def invalid?
		(@callbackURLs.size == 0)
	end
	
	def renew(expiry)
		if (expiry > 0)
			@expiryTime = Time.now + expiry
		else
			@expiryTime = nil
		end
	end
	
	def cancel
		@expiryTime = Time.now
	end
	
	def increment
		@eventSeq += 1
	end

end

end