
require_relative 'common'

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
	end
	
	def handleControl(req, res)
	
	#decode the XML
	#find the action by name
	#confirm that the "in" arguments have all been supplied
	#Thread.current[:action] = object.const_get(derived_action_classname).new
	
	#derived action will, when it initialises, name itself and add arguments
	
	#Thread.current[:action] = object.const_get(derived_action_classname).new
		
	end
	
	def handleDescription(req, res)
	end
	
	def validate
	end
		
end

class Argument
	
	# argument name
	attr_reader :name 
	# each argument must be linked to a state variable.  No idea why
	attr_reader :relatedStateVariable
	# whether this is an input or output argument
	attr_reader :direction
	# the action this argument is associated with
	attr_writer :action
	# the argument's value
	attr_accessor :value
	
	def initialize(n,d,r,s)

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
		if (@args[arg.name]) then raise "Action addArgument method: attempting to add duplicate argument #{arg.name}" end
		
		@args[arg.name] = arg
		arg.linkToAction(self)
		
		if (arg.direction == :in)
			@inArgs << arg
		else
			@outArgs << arg
		end
		
		if (arg.returnValue?)
			
			if (@outArgs.size > 1) then raise "Action addArgument method: return value must be first Out argument added" end
			
			if (@returnArg)
				raise "Action addArgument method: attempting to add #{arg.name} as a return value when #{@returnArg.name} already set as one"
			else
				@returnArg = arg
			end
		end
		
	end
		
	def linkToService(s)
		@service = s
	end
end

class StateVariable
	
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
	# service the variable is attached to
	attr_reader :service
	
		
	def initialize(n, t, dv, av, amx, amn, ai, ev = true, moderation = nil)
		@name = n
		@defaultValue = dv
		@type = t
		@allowedValues = av
		@allowedMax = amx
		@allowedMin = amn
		@allowedIncrement = ai
		@evented = ev
		if moderation = :Delta
			@moderationbyDelta = true
			@moderationbyRate = false
		elsif moderation = :Rate
			@moderationbyRate = true
			@moderationbyDelta = false
		else
			@moderationbyRate = false
			@moderationbyDelta = false
		end
	end
	
	# check if the state variable is evented or not
	def evented? 
		@evented
	end
	
	def moderatedByRate?
		@moderatedByRate
	end
	
	def moderatedByDelta?
		@moderatedByDelta
	end
	
	# assign a new value and trigger eventing if necessary
	def update(v)
		
		#this needs to be in a Mutex
		value =  v
		if ((self.evented?) && !(self.moderatedByRate || self.moderatedByDelta))
			@service.device.rootDevice.eventTriggers.push(v)
		end
		#end mutex
	end
	
	
	
end

end