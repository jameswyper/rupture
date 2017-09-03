

module UPnP
	
	class SetupError < ::StandardError
	end
	
	class StateVariableError < ::StandardError
	end
	
	class StateVariableRangeError < ::StandardError
	end
	
	class ActionError < ::StandardError
		attr_reader :code
		def initialize(code)
			@code = code
		end
	end

end