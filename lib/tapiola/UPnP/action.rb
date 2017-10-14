
#Copyright 2017 James Wyper


require_relative 'common'
require_relative 'stateVariable'
require 'rexml/document'
require 'rexml/xmldecl'

module UPnP



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

		if ((d != :in) && (d != :out))  then raise  SetupError, "Argument initialize method: direction not :in or :out, was #{d}" end
		
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

# Structure to hold Argument and Sequence pair
ArgSeq = Struct.new(:arg, :seq)

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
	
=begin rdoc
Called with the name of the action and a (non-UPnP) object / method that will be invoked to do the actual work
=end
	
	def initialize(name, obj, method)
		@name = name
		@args = Hash.new
		@inArgs = Hash.new
		@outArgs = Hash.new
		@retArg = nil
		@object = obj
		@method = method
	end
	
=begin rdoc
Tiny helper method to return the entries in the @outArgs hash in sequence
=end
	
	def outArgsInSequence
		return @outArgs.values.sort! { |x,y| x.seq <=> y.seq }
	end
	
=begin rdoc
Adds an existing argument to the Action.  The spec says that arguments must have a defined sequence, so a sequence number (starting from 1) must be passed as well as the argument object to be added.  Populates the @inArgs and @outArgs hashes
=end
	
	def addArgument(arg, seq)


		if (@args[arg.name]) then raise SetupError, "Action addArgument method: attempting to add duplicate argument #{arg.name}" end

		@args.each_value do |checkArg|
			if (checkArg.arg.direction == arg.direction) && (checkArg.seq == seq)
				raise SetupError, "Attempting to add duplicate sequence for #{arg.direction}, #{seq}"
			end
		end

		@args[arg.name] = ArgSeq[arg, seq]
		arg.linkToAction(self)
		
		if (arg.direction == :in)
			@inArgs[arg.name] = ArgSeq[arg, seq]
		else
			@outArgs[arg.name] = ArgSeq[arg, seq]
		end
		
		if (arg.returnValue?)
			
			if (seq != 1) then raise SetupError, "Action addArgument method: return value must be first Out argument added" end
			@retArg = arg

		end
		

		
	end
		
=begin rdoc
	Associates the Action with a Service object
=end
		
	def linkToService(s)
		@service = s
	end
	
=begin rdoc

	The object / method passed to the Action during initialisation is called.  This is how non-UPnP code is linked to the UPnP processing.  The method MUST accept the a	Hash containing all the parameters (in arguments) the action was invoked with (name/value pairs).
	
	The method should change any State Variables that it needs to; the cleanest way to achieve this is to pass the stateVariables of the service to the object when it is initialised eg
	
	myserv = UPnP::Service.new("example",1)
	
	class My_non_UPnP_class
	    def initialize(s)
			@stateVariables = s
		end
		def do_action(inargs)
		   .. do things here..
		   @stateVariables["VAR_NAME"].assign(1)
		end
	end
	
	my_non_UPnP_obj = My_non_UPnP_class.New(myserv.stateVariables)
	
	
	
	The method may be called concurrently, if this is a problem then use a Mutex or similar approach inside the thread-critical code to ensure it's single threaded (it will be necessary to do this when appending to a State Variable or incrementing a count held in one, for example)
	
	The method MUST return a Hash containing name/value pairs of all out arguements.
	If it encounters an error it must raise an ActionError exception
	It should handle StateVariable exceptions if it changes any state variables

=end
	
	def invoke(params)

		if !(@object.respond_to?(@method))
			raise ActionError.new(402)
			$log.error("Can't invoke #{@method} on #{@object}")
		else
			begin
				outargs = @object.send(@method,params)
			rescue ActionError => e
				$log.error("Problem when invoking #{@method} on #{@object} #{e}")
				raise
			end
		end

	end
	
	
=begin rdoc
Private method; takes a name/value hash of Arguments passed to the the action and compares it
with a hash of expected arguments
=end
	
	def validateArgs(args, expArgs)
		
		# check that the number of arguments passed in is what's expected
		if (args == nil)
			$log.warn("No Arguments to validate #{@service.type} - #{@name}")
			raise ActionError.new(402)
		end
		
		if args.size != expArgs.size
			$log.warn("Argument size mismatch for #{@service.type} - #{@name}, expected #{expArgs.keys.join('/')} but got #{args.keys.join('/')}")
			raise ActionError.new(402)
		end
		
		# check that the names of the arguments passed in are what's expected
		#  I love the next line of code, it's amazing how Ruby lets you do so much writing so little
		
		args.each_key.sort.zip(expArgs.each_key.sort).each do |argpair| 			
			if argpair[0] != argpair[1]
				$log.warn("Argument name mismatch for #{@service.type} - #{@name}, expected #{expArgs.keys.join('/')} but got #{args.keys.join('/')}")
				raise ActionError,402
			end
		end
		

		
	end

=begin rdoc
Checks that the arguments in the name/value hash passed to the method: 
1. match up with the expected argument names in @inArgs
2. have valid values (when validated against RelatedStateVariable for the argument)
=end
	def validateInArgs(args)
		
		validateArgs(args,@inArgs)
		
		args.each_pair do |name,value|
			sv = @inArgs[name].arg.relatedStateVariable
			begin
				args[name] = sv.interpret(value)
			rescue StateVariableError => e
				raise ActionError.new(600), e.message
			rescue StateVariableRangeError
				raise ActionError.new(601), e.message
			end
		end
		
	end

=begin rdoc
Checks that the arguments in the name/value hash passed to the method atch up with the expected argument names in @outArgs
=end

	def validateOutArgs(args)
		validateArgs(args,@outArgs)

	end
	
=begin rdoc
Populates the httpResponse object passed from the webserver with the correct headers and xml for a successful response to an Action call
=end
	
	def responseOK(res,args)
	
=begin
HTTP/1.1 200 OK
CONTENT-LENGTH: bytes in body
CONTENT-TYPE: text/xml; charset="utf-8"
DATE: when response was generated
EXT:
SERVER: OS/version UPnP/1.0 product/version
<?xml version="1.0"?>
<s:Envelope
xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
<s:Body>
<u:actionNameResponse xmlns:u="urn:schemas-upnp-org:service:serviceType:v">
<argumentName>out arg value</argumentName>
other out args and their values go here, if any
</u:actionNameResponse>
</s:Body>
</s:Envelope>
=end
		
		
		#create response body (xml) and headers
		rootE =  REXML::Element.new("s:Envelope")
		rootE.add_namespace("s","http://schemas.xmlsoap.org/soap/envelope/")
		rootE.attributes["s:encodingStyle"] = "http://schemas.xmlsoap.org/soap/encoding/"
		
		bod = REXML::Element.new("s:Body")
		
		resp = REXML::Element.new("u:#{@name}Response")
		resp.add_namespace("u","urn:schemas-upnp-org:service:#{@service.type}:#{@service.version}")

		
		outArgsInSequence.each do |arg|
			a  = REXML::Element.new("u:#{arg[0].name}")
			value = args[arg[0].name].to_s
			stringValue = arg[0].relatedStateVariable.represent(value)
			a.add_text(stringValue)  
			resp.add_element(a)
		end
		
		bod.add_element(resp)
		rootE.add_element(bod)
		
		
		doc = REXML::Document.new
		doc.context[:attribute_quote] = :quote
		doc << REXML::XMLDecl.new(1.0)
		doc.add_element(rootE)
		
		doc.write(res.body)
		
		res.content_type = 'text/xml; charset="utf-8"'
		res["ext"] = ""
		res["server"] = "#{@service.device.rootDevice.os} UPnP/1.0 #{@service.device.rootDevice.product}"

	end

	
	
end



end