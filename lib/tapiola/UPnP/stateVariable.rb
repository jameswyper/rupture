

module UPnP

class StateVariable
	
	@@SVTypes = [:ui1,:ui2,:ui4,:i1,:i2,:i4,:int,
				:r4,:r8,:fixed14,:number,:float,
				:char,:string,
				:date,:dateTime,:dateTimetz,:time,:timetz,
				:boolean,:binbase64,:binhex,:uri,:uuid]

	
	@@SVValidation = {
					:ui1 => [Fixnum, 0, 255],
					:ui2 => [Fixnum, 0, 65535],
					:ui4 => [Fixnum, 0, 4294967295],
					:i1 => [Fixnum, -128, 127],
					:i2 => [Fixnum, -32768, 32767],
					:i4 => [Fixnum, -2147483648,-2147483647],
					:int => [Fixnum, -9223372036854775808 , 9223372036854775807],
					:r4 => [Float, 0,-3.40282347e+38,3.40282347e+38]
					:r8 => [Float, 0, -1.79769313486232e308 ,1.79769313486232e308],
					:fixed14 => [Float, -99999999999999.9999, -99999999999999.9999],
					:number => [Float, -1.79769313486232e308 ,1.79769313486232e308]
		}
	
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
		
		[:Name,:Type].each do |p|
			unless params[p] then raise SetupError, "StateVariable initialize method: for name:#{params[:Name]} required parameter :#{p} missing" end
		end
		
		@name = params[:Name]
		@type = params[:Type]
		
		if (!@@SVTypes.include? (@type) ) then raise SetupError, "StateVariable initialize method: #{@name} has invalid type #{@type}" end
			
		@defaultValue = params [:DefaultValue]
		@allowedValues = Hash.new
		params[:AllowedValues].each {|k| @allowedValues[k] = true }
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
	
	# assign a new value and trigger eventing if necessary
	def update(v)
		
		
		@semaphore.synchronize do
			
		# validate the changed value
		
			self.validate(v)
		
			# assign it to the state variable
			# todo - provide string representations in format expected
		
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
	
	def validate(v)
		
				
		if (@allowedIncrement)
			if  (((@value - v) % @allowedIncrement) != 0)
				raise StateVariableError, "#{@name}: allowedIncrement violation, previous value #{@value} new value #{v} allowed increment #{@allowedIncrement}"
			end
		end
		
		if (@allowedRange)
			if ((v < @allowedMin) || (v > @allowedMax))
				raise StateVariableError, "#{@name}: allowedRange violation, attempt to set #{v}, min #{@allowedMin}, max #{@allowedMax}"
			end
		end

		if (@allowedValues)
			unless (@allowedValues[v]) then raise StateVariableError, "#{@name}: value #{v} not in allowed value list" end
		end
		
		
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
		
		case @type
			when :ui1, :ui2, :ui4, :int, :i1, :i4, :i2
				begin
					return Integer(v)
				rescue ArgumentError
					raise StateVariableError "Couldn't convert #{v} to type #{@type}"
				end
			when :r4. :r8, :number, :fixed144, :float
				begin
					return Float(v)
				rescue ArgumentError
					raise StateVariableError "Couldn't convert #{v} to type #{@type}"
				end
			when :char, :string, :uri, :uuid, :binbase64, :binhex
				return v
			when :date
			when :dateTime
			when :dateTimetz
			when :time
			when :timetz
			when :boolean
				if (["0","no","false"].include?(v)) return false
				else
					if (["1","yes","true"].include(v)) return true
				else
					raise StateVariableError "Couldn't convert #{v} to type #{@type}"
				end
			end
			
			
				
	end
		
=begin rdoc
    returns the string representation of a StateVariable
=end
	def 	represent
		
	end

=begin rdoc
    creates the XML for one or more state variable event notifications.  Normally this would only contain one notification but when a new subscription starts up
    all evented variables must be sent in a single message to allow the subscriber to initialise itself properly
=end
	
	
	
	def self.eventsXML(vars)   #class method because multiple variables could be passed in at once
		p = REXML::Element.new("propertyset")
		p.add_namespace("e", "urn:schemas.upnp.org:event-1-0")
		vars.each do |v|
			p.add_element("property").add_text(v.represent) # was v.to_s but I think that's wrong
		end
		
		doc = REXML::Document.new
		doc << REXML::XMLDecl.new(1.0)
		doc.add_element(p)
		
		return doc.to_s
	end
	
	
end #class StateVariable


class NumericStateVariable < StateVariable
end

class FloatStateVariable < NumericStateVariable
end

class IntegerStateVariable < NumericStateVariable
end

class StringStateVariable < StateVariable
end

class BooleanStateVariable < StateVariable
	
	def validate(v)
	end
	
	def interpret(v)
	end
	
	def represent
	end

end


end # module