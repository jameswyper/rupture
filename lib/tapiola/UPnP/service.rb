
require_relative 'common'

module UPnP

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
		a.service = self
	end
	
	def linkToDevice(d)
		@device = d
		servAddr = "#{URLBase}/services/#{@device.name}/#{@type}/"
		@eventAddr = servAddr + "event.xml"
		@controlAddr = servAddr + "control.xml"
		@descAddr = servAddr + "description.xml"
	end
	
	def handleEvent(req)
	end
	
	def handleControl(req)
	end
	
	def handleDescription(req)
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
	
	def initialize(n,d,s)
		@name = n
		@relatedStateVariable = s
		@direction = d
	end
end

class Action
	
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

end