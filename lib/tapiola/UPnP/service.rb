
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
	
	def handleControl(req, res)
	
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
		@inArgs = Array.new
		@outArgs = Array.new
		@retArg = nil
	end
	
	def addArgument(arg)
		if (@args[arg.name]) then raise SetupError, "Action addArgument method: attempting to add duplicate argument #{arg.name}" end
		
		@args[arg.name] = arg
		arg.linkToAction(self)
		
		if (arg.direction == :in)
			@inArgs << arg
		else
			@outArgs << arg
		end
		
		if (arg.returnValue?)
			
			if (@outArgs.size > 1) then raise SetupError, "Action addArgument method: return value must be first Out argument added" end
			
			if (@returnArg)
				raise SetupError, "Action addArgument method: attempting to add #{arg.name} as a return value when #{@returnArg.name} already set as one"
			else
				@returnArg = arg
			end
		end
		
	end
		
	def linkToService(s)
		@service = s
	end
	
	def invoke(params)
		raise ActionError, "Action invoke method: base class method called (did you supply a method in the derived class?)"
		return Hash.new
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