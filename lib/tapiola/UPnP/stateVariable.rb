
#Copyright 2017 James Wyper

require_relative 'common'
require 'rexml/document'
require 'rexml/xmldecl'

module UPnP

=begin rdoc
	State Variables are modelled by a hierarchy of classes, with StateVariable at the top.  The subclasses process different types of variable ie Strings, Numbers, Boolean and Dates / Times.  State Variables are used not only to describe the state of a UPnP service but also to validate the arguments passed to and from UPnP actions.
	
	There are three important methods which are overridden by the derived classes
	
	represent - provide the textual representation of a variable's value, to use in the XML sent by the device (both Events and Action responses)
	interpret - essentially to do represent in reverse, take a textual representation (e.g. from XML input) and create a value e.g. "1.45E2" to 145.  The interpret method will also validate the new value (is it within the allowed range / list of values / format?)
	assign - update the State Variable with a new value, carry out any validation on the change in value, and trigger eventing
	

=end

class StateVariable

=begin
	@@SVTypes = [:ui1,:ui2,:ui4,:i1,:i2,:i4,:int,
				:r4,:r8,:fixed14,:number,:float,
				:char,:string,
				:date,:dateTime,:dateTimetz,:time,:timetz,
				:boolean,:binbase64,:binhex,:uri,:uuid]

=end
	
	@@SVValidation = {
					:ui1 => [Fixnum, 0, 255],
					:ui2 => [Fixnum, 0, 65535],
					:ui4 => [Fixnum, 0, 4294967295],
					:i1 => [Fixnum, -128, 127],
					:i2 => [Fixnum, -32768, 32767],
					:i4 => [Fixnum, -2147483648,-2147483647],
					:int => [Fixnum, -9223372036854775808 , 9223372036854775807],
					:r4 => [Float, 0,-3.40282347e+38,3.40282347e+38],
					:r8 => [Float, 0, -1.79769313486232e308 ,1.79769313486232e308],
					:fixed14 => [Float, -99999999999999.9999, -99999999999999.9999],
					:number => [Float, -1.79769313486232e308 ,1.79769313486232e308]
		}
	
	# variable name - should be as per the Service specification
	attr_reader :name 
	# current value 
	attr_reader :value 
	# default value for the variable
	attr_reader :defaultValue
	# pemitted values for strings
	attr_reader :allowedValues
	# maximum value for numbers
	attr_reader :allowedMax
	# minimum value for numbers
	attr_reader :allowedMin
	# the smallest amount the value of this variable (if numeric) can change by
	attr_reader :allowedIncrement
	# service the variable is attached to
	attr_accessor :service
	# time that an event was last fired for a moderated variable
	attr_accessor :lastEventedTime
	# event rate
	attr_reader :maximumRate
	# state variable type
	attr_reader :type
	
=begin rdoc

initialize takes a hash of parameter name / value pairs e.g. :type => :SV_string

Required parameters are

:Name
:Type which must be one of  :ui1,:ui2,:ui4,:i1,:i2,:i4,:int,:r4,:r8,:fixed14,:number,:float,:char,:string,:date,:dateTime,:dateTimetz,:time,:timetz,:boolean,:binbase64,:binhex,:uri,:uuid]
(at the moment the code doesn't actually treat these types differently ie the value of a state variable isn't type-checked)


Optional parameters are

:DefaultValue - what the variable is initialised to

:AllowedValues - ensures the variable is validated against a set of allowed values which should be passed in as a hash e.g.

:AllowedValues => [ "this", "that"] or, for numbers, [ 1, 2, 3 ] but be careful with floating values, specify these as e.g. [1.0, 1.5, 2.0] as in ruby 1 <> 1.0

:AllowedMin, :AllowedMax - ensures validation against a range.  Can't be combined with :AllowedValues
:AllowedIncrement - ensures variable only changes by the given increment

:Evented - true/false depending on whether events should fire for changes
:ResetAfterEvent - although it's not part of the standard, some devices e.g MediaServer require that a variable is cleared after an event fires.  Specify the value to which a variable should be reset.  Can be "" or 0 but should not be nil.

:ModerationType - should be :Rate or :Delta with :MaximumRate (number of seconds between events) or :MinimumDelta (number of :AllowedIncrement steps before an event fires) supplied as well

=end
		
	def initialize(params)
		
		
		#check that all required parameters are present
		
		
		unless params[:name] 
			raise SetupError, "StateVariable initialize method: name missing" 
		end
		@name = params[:name]

					
		@defaultValue = params [:defaultValue]
		
		#create hash to store allowed values, note this hash will be empty if all values are allowed
		
		@allowedValues = Hash.new
		if (params[:allowedValues]) 
			params[:allowedValues].each {|k| @allowedValues[k] = true } 
		end
		
		@allowedMax = params[:allowedMax]
		@allowedMin = params[:allowedMin]
		@allowedIncrement = params[:allowedIncrement]
		
		#A state variable may be validate by a list of allowed values, or a range, but not both
		
		if  ((@allowedMax) || (@allowedMin) )
			@allowedRange = true 
		else 
			@allowedRange = false 
		end
		
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
		
		if params[:initialValue]
			@value = params[:initialValue]
			@lastEventedValue = @value
		else
			if @defaultValue 
				@value = @defaultValue
				@lastEventedValue = @value
			end
		end
		
		@evented = params[:evented]
		@resetValue = params[:resetAfterEvent]
		
		#cross-check moderation parameters
		
		if (params[:moderationType] == :delta)
			@moderatedByDelta = true
			@moderatedByRate = false
			@minimumDelta = params[:minimumDelta]
			unless @minimumDelta then raise SetupError, "Statevariable initialize method: for name #{@name} :MinimumDelta not specified" end
			unless @allowedIncrement then raise SetupError, "Statevariable initialize method: for name #{@name} :MinimumDelta requires :AllowedIncrement to also be set" end
		elsif (params[:moderationType] == :rate)
			@moderatedByRate = true
			@moderatedByDelta = false
			@lastEventedTime = Time.now
			@maximumRate = params[:maximumRate]
			unless @maximumRate then raise SetupError, "Statevariable initialize method: for name #{@name} :MaximumRate not specified" end
		else
			@moderatedByRate = false
			@moderatedByDelta = false
		end
		
		@semaphore = Mutex.new
		
	end

=begin rdoc
    Check to see if the variable is evented
=end
	
	# check if the state variable is evented or not
	def evented? 
		@evented
	end
	
=begin rdoc
     Simple check to see if the variable is moderated by rate (e.g. only produces an event at most n times a second)
=end
	def moderatedByRate?
		@moderatedByRate
	end
	
=begin rdoc
     Simple check to see if the variable is moderated by delta (e.g. only produces an event if the value has changed "significantly")
=end
	
	def allowedValueRange?
		@allowedRange
	end
	
	def allowedValueList?
		@allowedList
	end
	
	def moderatedByDelta?
		@moderatedByDelta
	end
	
	# although not part of the generic UPnP specification the ContentDirectory spec has a state variable that is reset after it has been evented (ContainerUpdateIDs)
	# I'm not sure if the reset function is actually what we need here.  Processing should be along the lines of..
	# 
	#  ContentDirectory object maintains set of ContainerUpdateIDs to notify
	#  
	#  Update SV when state changes
	#     --> Test to see if event has taken place since last update
	#     --> Reset set of ContainerUpdateIDs to notify to blank if event has, upsert latest update otherwise
	#   
	#  so I think we can replace this with processing to check and flag if last update evented yet, will need a semaphore thing since eventing has its own thread.  Yeuch
	
	def reset
		@value = @resetValue
		@lastEventedValue = @value
	end
	
	
=begin rdoc	
	assign a new value and trigger eventing if necessary.  Must be called with the actual value not the string representation (call interpret first if necessary)
=end
	def assign(v)
		
				
		if (@allowedIncrement)
			if  (((@value - v) % @allowedIncrement) != 0)
				raise StateVariableError, "#{@name}: allowedIncrement violation, previous value #{@value} new value #{v} allowed increment #{@allowedIncrement}"
			end
		end
		
		if (@allowedRange)
			if ((v < @allowedMin) || (v > @allowedMax))
				raise StateVariableRangeError, "#{@name}: allowedRange violation, attempt to set #{v}, min #{@allowedMin}, max #{@allowedMax}"
			end
		end

		if (!@allowedValues.empty?)
			unless (@allowedValues[v]) then raise StateVariableError, "#{@name}: value #{v} not in allowed value list" end
		end
		
		@semaphore.synchronize do
			
		# validate the changed value
		
		
			# assign it to the state variable
		
			@value =  v
		
			# check that eventing is enabled and fire an event unless it's moderated in some way
		
			if ((self.evented?) && !(self.moderatedByRate? || self.moderatedByDelta?))
				$log.debug("SV regular event for #{@name} about to trigger, value #{@value}")
				@service.subscriptions.each_value do |sub|
					if !sub.expired?
						@service.device.rootDevice.queueEvent(sub,[self])
					end
				end
			end
		
			# if the event is moderated by delta (only fires once the variable has changed by a sufficient amount) check for the size of change
		
			if self.moderatedByDelta?
				$log.debug("SV #{@name} is moderated by delta, last value was #{@lastEventedValue}, this value is #{v}")
				$log.debug("SV minimum delta and allowed increment are #{@minimumDelta} and #{@allowedIncrement}")
				if ((@lastEventedValue - v).abs >= (@minimumDelta * @allowedIncrement))
					$log.debug("SV so an event will fire")
					@lastEventedValue = v
					@service.subscriptions.each_value do |sub|
						if !sub.expired?
							@service.device.rootDevice.queueEvent(sub,[self])
						end
					end
				end
			end
		
		end #semaphore

	end
	

=begin
def validate(v)
		
				

		

		
		
		#check proposed value is a fixnum or float and within the allowed range for the type - all of which is held in the SVValidation class variable
		
		checks = @@SVValidation[@type]
		if (v.class != checks[0]) then raise StateVariableError "#{@name}: is of type #{@type}, must be assigned #{checks[0]} not #{v.class}" end
		if ((v < checks[1] || (v > checks[2])) then raise StateVariableError "#{name}: is of type #{@type}, value #{v} must be between #{checks[1]} and #{checks[2]}" end

		
		case @type
			when :float 
				if !(v =~ /^[+-]*\d\.*\d*E\d+$/) then raise StateVariableError "#{name}: is of type #{@type}, value #{v} must be of form (+/-)n.nnnEnn" end
			when :char
			when :string
			when :date
			when :dateTime
			when :dateTimetz
			when :time
			when :timetz
			when :boolean
			when :binbase64
			when :binhex
			when :uri
			when :uuid
		end
		
		
			
	end
		
	
		
	def interpret(v)
		

		v
			
				
	end
=end

=begin rdoc
    returns the string representation of the StateVariable's current value
=end
	def represent
		represent_value(self.value)
	end
=begin rdoc
	returns the string representation of a value that may or may not be currently assigned to the StateVariable
=end
	def represent_value(v)
		v.to_s
	end

=begin rdoc
    creates the XML for one or more state variable event notifications.  Normally this would only contain one notification but when a new subscription starts up
    all evented variables must be sent in a single message to allow the subscriber to initialise itself properly
=end
	
	
	
	def self.eventsXML(vars)   #class method because multiple variables could be passed in at once
		p = REXML::Element.new("e:propertyset")
		p.add_namespace("e", "urn:schemas-upnp-org:event-1-0")
		vars.each do |v|
			if v.evented?
				p.add_element("e:property").add_element(v.name).add_text(v.represent) 
			end
		end
		
		doc = REXML::Document.new
		doc.context[:attribute_quote] = :quote
		doc << REXML::XMLDecl.new(1.0)
		doc.add_element(p)

		return doc.to_s
	end
	
	
end #class StateVariable

=begin
	@@SVTypes = [:ui1,:ui2,:ui4,:i1,:i2,:i4,:int,
				:r4,:r8,:fixed14,:number,:float,
				:char,:string,
				:date,:dateTime,:dateTimetz,:time,:timetz,
				:boolean,:binbase64,:binhex,:uri,:uuid]
=end

=begin
   Not meant to be instantiated directly
=end

class StateVariableNumeric< StateVariable
	
	def initialize(p)
		@varMax = 0
		@varMin = 0
		super
	end
	



end

class StateVariableFloat < StateVariableNumeric
	
	def interpret(v)
		begin
			f = Float(v)
		rescue ArgumentError
			raise StateVariableError ,"Attempt to interpret #{v} as Integer State Variable #{@name}"
		end
		if ((f < @varMax) || (f > @varMin))
			raise StateVariableRangeError ,"Value #{v} outside allowed range (#{@varMax},#{@varMin}) for State Variable #{@name}"
		end
		return f
	end
end

class StateVariableInteger < StateVariableNumeric

	def interpret(v)
		
		begin
			i = Integer(v)
		rescue ArgumentError
			raise StateVariableError ,"Attempt to interpret #{v} as Integer State Variable #{@name}"
		end
		
		if ((i > @varMax) || (i < @varMin))
			raise StateVariableRangeError ,"Value #{v} outside allowed range (#{@varMin},#{@varMax}) for State Variable #{@name}"
		end
		
		return i
	end
end

class StateVariableUI1 < StateVariableInteger
	def initialize; super; @varMax = 255; @varMin = 0; end
end

class StateVariableUI2 < StateVariableInteger
	def initialize; super; @varMax = 65535; @varMin = 0; end
end

class StateVariableUI4 < StateVariableInteger
	def initialize; super; @varMax = 4294967295; @varMin = 0; end
end

class StateVariableI1 < StateVariableInteger
	def initialize; super; @varMax = 127; @varMin = -128; end
end

class StateVariableI2 < StateVariableInteger
	def initialize; super; @varMax = 32767; @varMin = -32768; end
end

class StateVariableI4 < StateVariableInteger
	def initialize(p); super; @varMax = 2147483647; @varMin = -2147483647; @type = "i4"; end
end

class StateVariableInt < StateVariableI4
	def initialize(p); super; @type = "int"; end
end

class StateVariableR4 < StateVariableFloat
	def initialize; super; @varMax = 3.402823437e38; @varMin = -3.402823437e38; end
end

class StateVariableR8 < StateVariableFloat
	def initialize; super; @varMax = 1.79769313486232E308; @varMin = -1.79769313486232E308; end
end

class StateVariableNumber < StateVariableR8
end

class StateVariableFixed144 < StateVariableFloat
	def initialize; super; @varMax=9999999999999.9999;@varMin=-99999999999999.9999;end
	def interpret(v)
		begin
			f = Float(v)
		rescue ArgumentError
			raise StateVariableError "Attempt to interpret #{v} as Integer State Variable #{@name}"
		end
		if ((f < varMax) || (f > varMin))
			raise StateVariableError "Value #{v} outside allowed range (#{@varMax},#{@varMin}) for State Variable #{@name}"
		end
		return f
	end
	def represent
		return @value.round(4).to_s
	end
end




class StateVariableString < StateVariable
	def interpret(v)
		v
	end
	def represent
		@value.to_s
	end
end

class StateVariableChar < StateVariableString
	def interpret(v)
		if v.length > 1 then raise StateVariableError "value #{v} not one character for State Variable #{@name}" end
		v
	end
end

class StateVariableURI < StateVariableString
end
	
class StateVariableUUID < StateVariableString
end
	
class StateVariableBinBase64 < StateVariableString
end

class StateVariableBinHex < StateVariableString
end




class StateVariableDateTime < StateVariable
end

class StateVariableDate < StateVariableDateTime
end

class StateVariableTime < StateVariableDateTime
end

class StateVariableDateTimeTZ < StateVariable
end

class StateVariableTimeTZ < StateVariable
end




class StateVariableBoolean < StateVariable
	

	def interpret(v)
		case v
		when "0", "false", "no"
			return false
		when "1", "true", "yes"
			return true
		else
			raise StateVariableError "Attempt to assign value #{v} to boolean variable #{@name}"
		end
	end
	
	def represent
		if (@value) then return "1" else return "0" end
	end

end


end # module