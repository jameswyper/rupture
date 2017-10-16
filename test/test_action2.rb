

=begin
Tests to do


  
  - call with values that don't match SV for range
  - call with args that make the service fail
  - have the service return the wrong number of arguments

  - call an unimplemented optional action


  NB for fun we should have the service increment an state variable as a counter of number of times called, and event this
	
=end

require 'minitest/autorun'
require_relative '../lib/tapiola/UPnP.rb'
require 'nokogiri'
require 'net/http'
require  'rexml/document'
require 'pry'





class TestMoreActions < Minitest::Test
	
	
	class Adder
		def initialize
			@count = 0
		end
		def add(inargs,service)
			outargs = Hash.new
			@count += 1
			outargs["Result"] = inargs["First"] + inargs["Second"]
			return outargs
		end
	end
	
	class Divider
		def div(inargs,service)
			outargs = Hash.new
			outargs["Result"] = inargs["Top"] / inargs["Bottom"]
			outargs["Modulo"] = inargs["Top"] % inargs["Bottom"]
			return outargs
		end	
	end
	
	# I think service needs to be passed to our objects when they are initialised, or at least the state variables should be....
	
	class Reverser
		def initialize
		end
		def rev(inargs,service)
			outargs = Hash.new
			outargs["Reversed"] = inargs["String"].reverse
			return outargs
		end
	end
	
		
	def setup

		@root = UPnP::RootDevice.new(:type => "SampleOne", :version => 1, :name => "sample1", :friendlyName => "SampleApp Root Device",
			:product => "Sample/1.0", :manufacturer => "James", :modelName => "JamesSample",	:modelNumber => "43",
			:modelURL => "github.com/jameswyper/tapiola", :cacheControl => 15,
			:serialNumber => "12345678", :modelDescription => "Sample App Root Device, to illustrate use of tapiola UPnP framework", 
			:URLBase => "test", :ip => "127.0.0.1", :port => 54321, :logLevel => Logger::INFO)
		
		@serv1 = UPnP::Service.new("Math",1)
		
		@sv1 = UPnP::StateVariableInt.new( :name => "A_ARG_TYPE_ADD1")
		@sv2 = UPnP::StateVariableInt.new( :name => "A_ARG_TYPE_ADD2")		
		@sv3 = UPnP::StateVariableInt.new( :name => "A_ARG_TYPE_ADD_RES")		
		@sv4 = UPnP::StateVariableInt.new( :name => "COUNT", :evented => true)		
		@sv5 = UPnP::StateVariableInt.new( :name => "A_ARG_TYPE_DIV1")
		@sv6 = UPnP::StateVariableInt.new( :name => "A_ARG_TYPE_DIV2")		
		@sv7 = UPnP::StateVariableInt.new( :name => "A_ARG_TYPE_DIV_RES_DIV")		
		@sv8 = UPnP::StateVariableInt.new( :name => "A_ARG_TYPE_DIV_RES_MOD")		
		@sv9 = UPnP::StateVariableString.new( :name => "A_ARG_TYPE_REV_IN")		
		@sv10 = UPnP::StateVariableString.new( :name => "A_ARG_TYPE_REV_OUT")		
		@sv11 = UPnP::StateVariableString.new( :name => "CHARS",:evented => true)		
		
		@adder = Adder.new
		@divider = Divider.new
		@reverser = Reverser.new

		@act1 = UPnP::Action.new("Add",@adder,:add)
		@act1.addArgument(UPnP::Argument.new("Second",:in,@sv2),2)
		@act1.addArgument(UPnP::Argument.new("First",:in,@sv1),1)
		@act1.addArgument(UPnP::Argument.new("Result",:out,@sv3,true),1)
		
		@serv1.addStateVariables(@sv1, @sv2, @sv3, @sv4)

		@serv1.addAction(@act1)
		
		@root.addService(@serv1)		
		Thread.new {@root.start}


	end
	

	
	
	def test_simple
		
		
# start by checking the device and service descriptions
# rather than write loads of assert statement by hand I've put the expected XML content for each xPath into an array


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
		["serviceStateTable/stateVariable/name",4,["A_ARG_TYPE_FIRST","A_ARG_TYPE_SECOND","A_ARG_TYPE_OUT","COUNT"]],
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
		
		uri = URI('http://127.0.0.1:54321/test/services/sample1/Math/control.xml')

# make a successful control call


		req = Net::HTTP::Post.new(uri)
		req['SOAPACTION'] = '"urn:schemas-upnp-org:service:Math:1#Add"'
		req.body='<?xml version="1.0"?> 
			<s:Envelope
			xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
			s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
			<s:Body>
			<u:Add xmlns:u="urn:schemas-upnp-org:service:Math:1">
			<First>2</First>
			<Second>2</Second>
			</u:Add>
			</s:Body>
			</s:Envelope>'

		res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }

		assert(res.is_a?(Net::HTTPSuccess))
		assert_equal("200",res.code)
		
		document = REXML::Document.new res.body

		w = REXML::XPath.first(document, "//m:Envelope/", {"m"=>"http://schemas.xmlsoap.org/soap/envelope/"})
		x = REXML::XPath.first(document, "//m:Envelope/m:Body", {"m"=>"http://schemas.xmlsoap.org/soap/envelope/"})
		y =  REXML::XPath.first(x,"//p:AddResponse",{"p" => "urn:schemas-upnp-org:service:Math:1"})
		
		assert_equal("http://schemas.xmlsoap.org/soap/encoding/",w.attributes["s:encodingStyle"])
		assert_equal(1,y.elements.size,"returned arguments")
		assert_equal("Result",y.elements[1].name,"argument name")
		assert_equal("4",y.elements[1].text,"argument value")

		assert_match  Regexp.new("\\d+", Regexp::IGNORECASE), res.to_hash["content-length"] [0]
		assert_match  res.body.size.to_s, res.to_hash["content-length"] [0]
		assert_match  "", res.to_hash["ext"] [0]
		assert_match  'text/xml; charset="utf-8"', res.to_hash["content-type"] [0]

	
	end
	
	
	def teardown

	@root.stop
		
	end

end

