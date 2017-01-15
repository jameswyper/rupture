
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

class StateVariable
	
	@@SVtypes = [:ui1,:ui2,:ui4,:i1,:i2,:i4,:int,
				:r4,:r8,:fixed14,:numbe,:float,
				:char,:string,
				:date,:dateTime,:dateTimetz,:time,:timetz,
				:boolean,:binbase64,:binhex,:uri,:uuid]


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
	# time that an event was last fired for a moderated variable
	attr_accessor :lastEventedTime
	
=begin rdoc

initialize takes a hash of parameter name / value pairs e.g. :type => :SV_string

Required parameters are

:Name
:Type which must be one of  :ui1,:ui2,:ui4,:i1,:i2,:i4,:int,:r4,:r8,:fixed14,:numbe,:float,:char,:string,:date,:dateTime,:dateTimetz,:time,:timetz,:boolean,:binbase64,:binhex,:uri,:uuid]
(at the moment the code doesn't actually treat these types differently ie the value of a state variable isn't type-checked)


Optional parameters are

:DefaultValue - what the variable is initialised to

:AllowedValues - ensures the variable is validated against a set of allowed values which should be passed in as a hash e.g.

:AllowedValues => { :ipsum => 0, :lorem => 0} (it doesn't matter what the values are, 0 is fine, so long as they are not nil or false

:AllowedMin, :AllowedMax - ensures validation against a range.  Can't be combined with :AllowedValues
:AllowedIncrement - ensures variable only changes by the given increment

:Evented - true/false depending on whether events should fire for changes
:ResetAfterEvent - although it's not part of the standard, some devices e.g MediaServer require that a variable is cleared after an event fires.  Specify the value to which a variable should be reset.  Can be "" or 0 but should not be nil.

:ModerationType - should be :Rate or :Delta with :MaximumRate (number of seconds between events) or :MinimumDelta (number of :AllowedIncrement steps before an event fires) supplied as well

=end
		
	def initialize(params)
		
		
		#check that all required parameters are present
		
		[:Name,:Type].each do |p|
			unless params[p] then raise SetupError, "StateVariable initialize method: for name:#{params[:Name]} required parameter :#{p} missing" end
		end
		
		@name = params[:Name]
		@type = params[:Type]
		@defaultValue = params [:DefaultValue]
		@allowedValues = params[:AllowedValues]
		@allowedMax = params[:AllowedMax]
		@allowedMin = params[:AllowedMin]
		@allowedIncrement = params[:AllowedIncrement]
		
		#A state variable may be validate by a list of allowed values, or a range, but not both
		
		if (@allowedMax) || @allowedMin) then @allowedRange = true else @allowedRange = false end
		if (@allowedRange)
			unless (@allowedMin && @allowedMax) then raise SetupError, "Statevariable initialize method: for name #{@name} :AllowedMin and :AllowedMax must both be specified" end
		end
		
		# Validate the default value
		
		if (@allowedRange && @allowedValues) then raise SetupError, "Statevariable initialize method: for name #{@name} :AllowedMin/Max and :AllowedValues cannot both be specified" end
		
		if (@allowedRange && @defaultValue)
			if ((@defaultValue > @allowedMax) || (@defaultValue < @allowedMin)) then raise SetupError, "Statevariable initialize method: for name #{@name} :DefaultValue outside :AllowedMin/Max" end
		elsif (@allowedValues && @defaultValue)
			unless (@allowedValues[@defaultValue]) then raise SetupError, "Statevariable initialize method: for name #{@name} :DefaultValue not in :AllowedValues list" end 
		end
		
		if @defaultValue 
			@value = @defaultValue
			@lastEventedValue = @value
		end
		
		@evented = params[:Evented]
		@resetValue = params[:ResetAfterEvent]
		
		#cross-check moderation parameters
		
		if (params[:ModerationType] == :Delta)
			@moderationbyDelta = true
			@moderationbyRate = false
			@minimumDelta = params[:MinimumDelta]
			unless @minimumDelta then raise SetupError, "Statevariable initialize method: for name #{@name} :MinimumDelta not specified"
			unless @allowedIncrement then raise SetupError, "Statevariable initialize method: for name #{@name} :MinimumDelta requires :AllowedIncrement to also be set"
		elsif (params[:ModerationType] == :Rate)
			@moderationbyRate = true
			@moderationbyDelta = false
			@maximumRate = params[:MaximumRate]
			unless @maximumRate then raise SetupError, "Statevariable initialize method: for name #{@name} :MaximumRate not specified"
		else
			@moderationbyRate = false
			@moderationbyDelta = false
		end
		
		@semaphore = Mutex.new
		
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
	
	def reset
		@value = @resetValue
		@lastEventedValue = @value
	end
	
	# assign a new value and trigger eventing if necessary
	def update(v)
		
		
		@semaphore.synchronize do
			
		# validate the changed value
		
			if (@allowedIncrement)
				if  (((@value - v) % @allowedIncrement) != 0)
					raise StateVariableError, "allowedIncrement violation, previous value #{@value} new value #{v} allowed increment #{@allowedIncrement}"
				end
			end
		
			if (@allowedRange)
				if ((v < @allowedMin) || (v > @allowedMax))
					raise StateVariableError, "allowedRange violation, attempt to set #{v}, min #{@allowedMin}, max #{@allowedMax}"
				end
			end

			if (@allowedValues)
				unless (@allowedValues[v]) then raise StateVariableError, "value #{v} not in allowed value list" end
			end
		
			# assign it to the state variable
		
			@value =  v
		
			# check that eventing is enabled and fire an event unless it's moderated in some way
		
			if ((self.evented?) && !(self.moderatedByRate? || self.moderatedByDelta?))
				@service.device.rootDevice.eventTriggers.push(@value)
			end
		
			# if the event is moderated by delta (only fires once the variable has changed by a sufficient amount) check for the size of change
		
			if self.moderatedByDelta?
				if ((@lastEventedValue - v).abs > (@minimumDelta * @allowedIncrement))
					@lastEventedValue = v
					@service.device.rootDevice.eventTriggers.push(@value)
				end
			end
		
		end #semaphore
	
	end
	
	
	
end

end