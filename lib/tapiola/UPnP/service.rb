
require_relative 'common'
require_relative 'stateVariable'

module UPnP

=begin
   A UPnP Service consists of state variables and actions, this is a simple base class to hold essential information about the service
   A real service should implement a class derived from this one, set up the state variables and actions (which are also derived from simple base classes #UPnPAction
   and #UPnPStateVariable) and use #addStateVariable and #addAction to associate them with the service
   
  I think that we don't need to derive classes from Service, just instantiate them, as no code is specific to the service
  However there is code that's specific to each action, so that needs to be via derived classes and instantiated (as it could be run at the same time from two clients in two threads, so it must be thread-safe)
  
  So.. s = service.new; sv1 = statevariable.new; s.addStateVariable(sv1), repeat.. 
  def action1 < action
     during initialise, create and add arguments (as instance variables)

  end
  def action2 < action
  end
  s.addaction(action1)
  s.addaction(action2) (so the service linked to an action must be a CLASS variable)
  
  when handleControl is called
  object of the correction action1/2 class will be created
  arguments checked against the object and passed in  (this can, I think, be a generic method on action)
  action.invoke -> find and run the right method, including looking up and changing arguments (so arguments need a value they aren't just metadata)
  check return arguments and assemble returning XML
   
	TODO

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
	

	- 
   
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


	
	def initialize(t, v)
		@type = t
		@version = v
		@actions = Hash.new
		@stateVariables =  Hash.new
		@subscriptions = Hash.new
	end
	
	def addStateVariable(s)
		@stateVariables[s.name]  = s
		s.service = self
	end
	
	def addStateVariables(*a)
		a.each { |s| addStateVariable(s) }
	end
	
	def addAction(a)
		@actions[a.name] = a
		a.linkToService(self)
	end
	
	def linkToDevice(d)
		@device = d
		servAddr = "#{d.urlBase}/services/#{d.name}/#{@type}/"
		@eventAddr = servAddr + "event.xml"
		@controlAddr = servAddr + "control.xml"
		@descAddr = servAddr + "description.xml"
		@log = @device.rootDevice.log
	end
	
	
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
			a.args.each_value do |g|
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
	
	def processActionXML(xml,soapaction)

		
		re = /^"(.*)#(.*)"$/
		md = re.match(soapaction)
		
		if (md != nil) && (md[1] != nil) && (md[2] != nil)
			namespace = md[1]
			action = md[2]
		else
			@log.warn("SOAPACTION header invalid - was :#{soapaction}:")
			raise ActionError, 401
		end


		doc = REXML::Document.new xml

		soapbody = REXML::XPath.first(doc, "//m:Envelope/m:Body", {"m"=>"http://schemas.xmlsoap.org/soap/envelope/"})
		unless soapbody
			@log.warn("Couldn't get SOAP body out of #{xml}")
			raise ActionError, 401
		end
		
		argsxml =  REXML::XPath.first(soapbody,"//p:#{action}",{"p" => "#{namespace}"})
		unless argsxml
			@log.warn("Couldn't get action name out of #{xml} with SOAPACTION header :#{soapaction}:")
			raise ActionError, 401
		end

		if (action != argsxml.name)
			@log.warn("SOAPACTION header :#{soapaction}: didn't match XML name #{xml}")
			raise ActionError,401
		end

		args = Hash.new
		
		argsxml.elements.each {|e| args[e.name] = e.text}
		
		return action, args

	end
	
	def handleControl(req, res)
	
		begin
			actionname, args = processActionXML(req.body,req.header["SOAPACTION"])
			action = @actions[actionname]
			if action == nil
				@log.warn("Action #{actionname} doesn't exist in service #{@name}")
				raise ActionError, 401
			else
				action.validateinArgs(args)
				outArgs = action.invoke
				res = action.responseOK(args)
			end
		rescue ActionError, code
			res = action.responseError(code)
		end
	
	#decode the XML
	#find the action by name
	#confirm that the "in" arguments have all been supplied
	#validate all "in" arguements against state variables
	#set up params hash
	#invoke action
	#validate "out" arguments against state variables
	
	#assemble SOAP response	
	end
	
	def handleDescription(req, res)
		@log.debug("Description (service) request: #{req}")
		res.body = createDescriptionXML.to_s
		res.content_type = "text/xml"
	end
	
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
	
	def initialize(n)
		@name = n
		@args = Hash.new
		@inArgs = Hash.new
		@outArgs = Hash.new
		@retArg = nil
	end
	
	def addArgument(arg)

# this needs looking at as @inargs @outargs should be ordered but it's also good if they are hashes

		if (@args[arg.name]) then raise SetupError, "Action addArgument method: attempting to add duplicate argument #{arg.name}" end
		
		@args[arg.name] = arg
		arg.linkToAction(self)
		
		if (arg.direction == :in)
			@inArgs[arg.name] = arg
		else
			@outArgs[arg.name] = arg
		end
		
		if (arg.returnValue?)
			
			if (@outArgs.size > 1) then raise SetupError, "Action addArgument method: return value must be first Out argument added" end
			@retArg = arg

		end
		
	end
		
	def linkToService(s)
		@service = s
	end
	
	def invoke(params)
		raise SetupError, "Action invoke method: base class method called (did you supply a method in the derived class?)"
		return Hash.new
	end
	
	def validateArgs(args, expArgs)
		
		# check that the number of arguments passed in is what's expected
		
		if args.size != expArgs.size
			@log.warn("Argument size mismatch for #{@service.name} - #{@name}, expected #{expArgs.each_key.join('/')} but got #{args.each_key.join('/')}")
			raise ActionError, 402
		end
		
		# check that the names of the arguments passed in are what's expected
		#  I love the next line of code, it's amazing how Ruby lets you do so much writing so little
		
		args.each_key.sort.zip(expArgs.each_key.sort).each do |argpair| 			
			if argpair[0] != argpair[1]
				@log.warn("Argument name mismatch for #{@service.name} - #{@name}, expected #{expArgs.each_key.join('/')} but got #{args.each_key.join('/')}")
				raise ActionError,402
			end
		end
		
		args.each_pair do |name,value|
			sv = expArgs[name].relatedStateVariable
			begin
				sv.validate(value)
			rescue StateVariableError
				raise ActionError, 600
			rescue StateVariableRangeError
				raise ActionError, 601
			end
			
		end
		
	end
	
	def validateinArgs(args)
		validateArgs(args,@inArgs)
	end
	
	def validateoutArgs(args)
		validateArgs(args,@outArgs)

	end
	
	def responseOK(args)
		#create response body (xml) and headers
	end
	
	def responseError(args)
		#create response body (xml) and headers
	end
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