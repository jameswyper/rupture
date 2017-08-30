

=begin
Tests to do

Set up an action badly
 - arguments not in or out
 - retval in wrong place
 - duplicate argument
 
 Set up a good action
  - call it
  - call a different action
  - call an unimplemented optional action
  - call with missing arguments
  - call with extra arguments
  - call with both missing and extra
  - call with values that don't match SV for type
  - call with values that don't match SV for range
  - call with args that make the service fail
  - have the service return the wrong number of arguments
  
  NB for fun we should have the service increment an state variable as a counter of number of times called, and event this
	
=end

require 'minitest/autorun'
require_relative '../lib/tapiola/UPnP.rb'
require 'nokogiri'
require 'net/http'
require  'rexml/document'
require 'pry'





class TestSimpleDescription < Minitest::Test
	
	
	
		
	def setup

		@root = UPnP::RootDevice.new(:type => "SampleOne", :version => 1, :name => "sample1", :friendlyName => "SampleApp Root Device",
			:product => "Sample/1.0", :manufacturer => "James", :modelName => "JamesSample",	:modelNumber => "43",
			:modelURL => "github.com/jameswyper/tapiola", :cacheControl => 15,
			:serialNumber => "12345678", :modelDescription => "Sample App Root Device, to illustrate use of tapiola UPnP framework", 
			:URLBase => "test", :ip => "127.0.0.1", :port => 54321, :logLevel => Logger::INFO)
		
		@serv1 = UPnP::Service.new("Math",1)
		
		@sv1 = UPnP::StateVariableInt.new( :name => "A_ARG_TYPE_FIRST")
		@sv2 = UPnP::StateVariableInt.new( :name => "A_ARG_TYPE_SECOND")		
		@sv3 = UPnP::StateVariableInt.new( :name => "A_ARG_TYPE_OUT")		
		
		@act1 = UPnP::Action.new("Add")
		@act1.addArgument(UPnP::Argument.new("First",:in,@sv1))
		@act1.addArgument(UPnP::Argument.new("Second",:in,@sv2))
		@act1.addArgument(UPnP::Argument.new("Result",:out,@sv3,true))
		
		@serv1.addStateVariables(@sv1, @sv2, @sv3)
		@serv1.addAction(@act1)
		
		@root.addService(@serv1)		
		Thread.new {@root.start}


	end
	

	
	
	def test_simple
		
		

		desc = Net::HTTP.get(URI("http://#{@root.ip}:#{@root.port}/test/description/description.xml"))

		
		
		document = REXML::Document.new desc
		
		list = [
		["specVersion/major",1,"1"],
		["specVersion/minor",1,"0"],
		["device/deviceType",1,"urn:schemas-upnp-org:device:SampleOne:1"],
		["device/friendlyName",1,"SampleApp Root Device"],
		["device/manufacturer",1,"James"],
		["device/modelDescription",1,"Sample App Root Device, to illustrate use of tapiola UPnP framework"],
		["device/modelName",1,"JamesSample"],
		["device/modelURL",1,"github.com/jameswyper/tapiola"],
		["device/serialNumber",1,"12345678"],
		["device/modelNumber",1,"43"],
		["device/UDN",1,"uuid:#{@root.uuid}"],
		["device/iconList",0,""],
		["device/serviceList/service/serviceType",1,"urn:schemas-upnp-org:service:Math:1"],
		["device/serviceList/service/serviceId",1,"urn:upnp-org:serviceId:Math"],
		["device/serviceList/service/SCPDURL",1,"http://127.0.0.1:54321/test/services/sample1/Math/description.xml"],
		["device/serviceList/service/controlURL",1,"http://127.0.0.1:54321/test/services/sample1/Math/control.xml"],
		["device/serviceList/service/eventSubURL",1,"http://127.0.0.1:54321/test/services/sample1/Math/event.xml"],
		["device/presentationURL",1,"http://127.0.0.1:54321/test/presentation/sample1/presentation.html"]
		]
		
		list.each do |l|
			min = document.root.elements[l[0]]
			if l[1] == 0
				assert_nil min, "#{l[0]} element found, wasn't expected"
			else
				refute_nil min, "#{l[0]} not found in XML: #{desc}"
				assert_equal l[1],min.size
				assert_equal  l[2], min[0].to_s
			end
		end
		
		
		
		desc = Net::HTTP.get(URI("http://127.0.0.1:54321/test/services/sample1/Math/description.xml"))

		puts desc
		
		document = Nokogiri::XML(desc)
		errs = schema2.validate(document)
		errs.each do |e|
			puts e.to_s
		end
		assert_equal 0, errs.size, "xml didn't validate against service.xsd"

		
		document = REXML::Document.new desc
		
		list = [
		["specVersion/major",1,"1"],
		["specVersion/minor",1,"0"],
		["actionList/action/name",1,"Add"],
		["actionList/action/argumentList/argument/name",3,["First","Second","Result"]],
		["actionList/action/argumentList/argument/direction",3,["in","in","out"]],
		["actionList/action/argumentList/argument/relatedStateVariable",3,["A_ARG_TYPE_FIRST","A_ARG_TYPE_SECOND","A_ARG_TYPE_OUT"]],
		["actionList/action/argumentList/argument[name='First']/retval",0,nil],
		["actionList/action/argumentList/argument[name='Second']/retval",0,nil],
		["actionList/action/argumentList/argument[name='Result']/retval",1,""],
		["serviceStateTable/stateVariable/name",3,["A_ARG_TYPE_FIRST","A_ARG_TYPE_SECOND","A_ARG_TYPE_OUT"]],
		]
		

		
		list.each do |l|
			min = Array.new
			document.elements.each("*/" + l[0]) {|m|  min << m.text}
			if l[1] == 0
				assert_empty min, "#{l[0]} element found, wasn't expected"
			else
				refute_nil min, "#{l[0]} not found in XML: #{desc}"
				assert_equal l[1],min.size, "#{l[0]} expected / actual number of elements don't match"
				if  l[2].kind_of?(Array) 
					min.each  { |m| assert_includes l[2],m.to_s }
				else
					assert_equal l[2],min[0].to_s
				end
			end
		end
		
end	
	
	
	def teardown

	@root.stop
		
	end
	
end

