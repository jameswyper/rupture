

module UPnP

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
		
			self.validate(v)
		
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
	
	
		def validate(v)
			
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
			
			case @type
				when :ui1
				when :ui2
				when :ui4
				when :i1
				when :i2
				when :i4
				when :int
				when :r4
				when :r8
				when :fixed144
				when :number
				when :float
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
			
		end
	end
	

	
	def self.eventsXML(vars)
		p = REXML::Element.new("propertyset")
		p.add_namespace("e", "urn:schemas.upnp.org:event-1-0")
		vars.each do |v|
			p.add_element("property").add_text(v.to_s)
		end
		
		doc = REXML::Document.new
		doc << REXML::XMLDecl.new(1.0)
		doc.add_element(p)
		
		return doc.to_s
	end
	
	
end #class StateVariable


end