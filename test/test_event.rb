



require 'minitest/autorun'
require_relative '../lib/tapiola/UPnP.rb'
require  'rexml/document'
require 'pry'
require 'httpclient'




class TestSimpleAction < Minitest::Test
	
	
	class Adder
		def initialize(sv)
			@count = 0
			@stateVariables = sv
		end
		def add(inargs)
			outargs = Hash.new
			@count += 1
			outargs["Result"] = inargs["First"] + inargs["Second"]
			return outargs
		end
	end
	
	
		
	def setup

		@root = UPnP::RootDevice.new(:type => "SampleOne", :version => 1, :name => "sample1", :friendlyName => "SampleApp Root Device",
			:product => "Sample/1.0", :manufacturer => "James", :modelName => "JamesSample",	:modelNumber => "43",
			:modelURL => "github.com/jameswyper/tapiola", :cacheControl => 15,
			:serialNumber => "12345678", :modelDescription => "Sample App Root Device, to illustrate use of tapiola UPnP framework", 
			:URLBase => "test", :ip => "127.0.0.1", :port => 54321, :logLevel => Logger::WARN)
		
		@serv1 = UPnP::Service.new("Math",1)
		
		@sv1 = UPnP::StateVariableInt.new( :name => "A_ARG_TYPE_FIRST")
		@sv2 = UPnP::StateVariableInt.new( :name => "A_ARG_TYPE_SECOND")		
		@sv3 = UPnP::StateVariableInt.new( :name => "A_ARG_TYPE_OUT")		
		@sv4 = UPnP::StateVariableInt.new( :name => "COUNT", :evented => true)		
		
		@adder = Adder.new(@serv1.stateVariables)

		@act1 = UPnP::Action.new("Add",@adder,:add)
		@act1.addArgument(UPnP::Argument.new("Second",:in,@sv2),2)
		@act1.addArgument(UPnP::Argument.new("First",:in,@sv1),1)
		@act1.addArgument(UPnP::Argument.new("Result",:out,@sv3,true),1)
		
		@serv1.addStateVariables(@sv1, @sv2, @sv3, @sv4)

		@serv1.addAction(@act1)
		
		@root.addService(@serv1)		
		Thread.new {@root.start}


	end
	

	
	
	def test_event
		
		
		
	uri = "http://127.0.0.1:54321/test/services/sample1/Math/event.xml"
	
	c = HTTPClient.new
	
	d= c.request("SUBSCRIBE",uri,:header =>{"nt"=>"upnp:event","timeout"=>"seconds-60","callback"=>"localhost:60000"})
	
	puts d.headers.inspect

		
		
	end
	
	
	def teardown

	@root.stop
		
	end

end

