require 'logger'

module UPnP
	
	$log = Logger.new(STDOUT)
	
# Exception class for issues related to the setup / initialisation of the UPnP subsystem	
	class SetupError < ::StandardError
	end

# Exception class for problems validating a state variable 
	class StateVariableError < ::StandardError
	end

# Exception class for problems when a State Variable is out of allowed range
	class StateVariableRangeError < ::StandardError
	end
	
# Exception class for problems processing an UPnP Action; the code is passed back as an error code to the Control point (there are standard codes for standard types of error)
	class ActionError < ::StandardError
		attr_reader :code
		def initialize(code)
			@code = code
		end
	end

end