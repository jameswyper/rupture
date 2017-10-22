

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
		def initialize(sv)
			@sv = sv
			@count = 0
		end
		def add(inargs)
			outargs = Hash.new
			@count += 1
			outargs["Result"] = inargs["First"] + inargs["Second"]
			@sv["COUNT"].assign(@count)
			return outargs
		end
	end
	
	class Divider
		def initialize(sv)
			@sv = sv
		end
		def div(inargs)
			outargs = Hash.new
			outargs["Result"] = inargs["Top"] / inargs["Bottom"]
			outargs["Modulo"] = inargs["Top"] % inargs["Bottom"]
			return outargs
		end	
	end
	
	
	
	class Reverser
		def initialize(sv)
			@sv = sv
		end
		def rev(inargs)
			outargs = Hash.new
			outargs["Reversed"] = inargs["String"].reverse
			@sv["CHARS"].assign(outargs["Reversed"].length)
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
		@serv2 = UPnP::Service.new("String",1)
		
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
		@sv12 = UPnP::StateVariableString.new( :name => "A_ARG_TYPE_BADREV_IN")
		@sv13 = UPnP::StateVariableString.new( :name => "A_ARG_TYPE_BADREV_OUT")
		@sv14 = UPnP::StateVariableString.new( :name => "A_ARG_TYPE_BADREV_OUT2")
		
		@adder = Adder.new(@serv1.stateVariables)
		@divider = Divider.new(@serv1.stateVariables)
		@reverser = Reverser.new(@serv2.stateVariables)

		@act1 = UPnP::Action.new("Add",@adder,:add)
		@act1.addArgument(UPnP::Argument.new("Second",:in,@sv2),2)
		@act1.addArgument(UPnP::Argument.new("First",:in,@sv1),1)
		@act1.addArgument(UPnP::Argument.new("Result",:out,@sv3,true),1)
		
		@act2 = UPnP::Action.new("Divide",@divider,:div)
		@act2.addArgument(UPnP::Argument.new("Top",:in,@sv5),1)
		@act2.addArgument(UPnP::Argument.new("Bottom",:in,@sv6),2)		
		@act2.addArgument(UPnP::Argument.new("Result",:out,@sv7,true),1)
		@act2.addArgument(UPnP::Argument.new("Modulo",:out,@sv8),2)

		@act3 = UPnP::Action.new("Reverse",@reverser,:rev)
		@act3.addArgument(UPnP::Argument.new("String",:in,@sv9),1)
		@act3.addArgument(UPnP::Argument.new("Reversed",:out,@sv10,true),1)	

		@act4 = UPnP::Action.new("BadReverse",@reverser,:rev)
		@act4.addArgument(UPnP::Argument.new("String",:in,@sv12),1)
		@act4.addArgument(UPnP::Argument.new("BadExtra",:out,@sv13),2)
		@act4.addArgument(UPnP::Argument.new("Reversed",:out,@sv14,true),1)			


		@serv1.addStateVariables(@sv1, @sv2, @sv3, @sv4,@sv5,@sv6,@sv7,@sv8)
		@serv2.addStateVariables(@sv9,@sv10,@sv11,@sv12,@sv13,@sv14)

		@serv1.addAction(@act1)
		@serv1.addAction(@act2)		
		
		@serv2.addAction(@act3)
		@serv2.addAction(@act4)
		
		
		@root.addService(@serv1)
		@root.addService(@serv2)
		
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
		["device/serviceList/service/serviceType",2,["urn:schemas-upnp-org:service:Math:1","urn:schemas-upnp-org:service:String:1"]],
		["device/serviceList/service/serviceId",2,["urn:upnp-org:serviceId:Math","urn:upnp-org:serviceId:String"]],
		["device/serviceList/service/SCPDURL",2,["http://127.0.0.1:54321/test/services/sample1/Math/description.xml","http://127.0.0.1:54321/test/services/sample1/String/description.xml"]],
		["device/serviceList/service/controlURL",2,["http://127.0.0.1:54321/test/services/sample1/Math/control.xml","http://127.0.0.1:54321/test/services/sample1/String/control.xml"]],
		["device/serviceList/service/eventSubURL",2,["http://127.0.0.1:54321/test/services/sample1/Math/event.xml","http://127.0.0.1:54321/test/services/sample1/String/event.xml"]],
		["device/presentationURL",1,"http://127.0.0.1:54321/test/presentation/sample1/presentation.html"]
		]
		
=begin
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
=end
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
		
		
		desc = Net::HTTP.get(URI("http://127.0.0.1:54321/test/services/sample1/Math/description.xml"))

		puts desc
		
		
		document = REXML::Document.new desc
		
		list = [
		["specVersion/major",1,"1"],
		["specVersion/minor",1,"0"],
		["actionList/action/name",2,"Add","Divide"],
		["actionList/action/argumentList/argument/name",7,["First","Second","Result","Top","Bottom","Result","Modulo"]],
		["actionList/action/argumentList/argument/direction",7,["in","in","out","in","in","out","out"]],
		["actionList/action/argumentList/argument/relatedStateVariable",7,
			["A_ARG_TYPE_DIV1","A_ARG_TYPE_DIV2","A_ARG_TYPE_DIV_RES_DIV","A_ARG_TYPE_DIV_RES_MOD","A_ARG_TYPE_ADD1",
			"A_ARG_TYPE_ADD2","A_ARG_TYPE_ADD_RES"]],
		["actionList/action/argumentList/argument[name='First']/retval",0,nil],
		["actionList/action/argumentList/argument[name='Second']/retval",0,nil],
		["actionList/action/argumentList/argument[name='Result']/retval",2,""],
		["actionList/action/argumentList/argument[name='Top']/retval",0,nil],
		["actionList/action/argumentList/argument[name='Bottom']/retval",0,nil],
		["actionList/action/argumentList/argument[name='Modulo']/retval",0,nil],		
		["serviceStateTable/stateVariable/name",8,
			["A_ARG_TYPE_ADD1","A_ARG_TYPE_ADD2","A_ARG_TYPE_ADD_RES","COUNT","A_ARG_TYPE_DIV1",
			"A_ARG_TYPE_DIV2","A_ARG_TYPE_DIV_RES_DIV","A_ARG_TYPE_DIV_RES_MOD"]],
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
		
		
		desc = Net::HTTP.get(URI("http://127.0.0.1:54321/test/services/sample1/String/description.xml"))

		puts desc
		
		
		document = REXML::Document.new desc
		
		list = [
		["specVersion/major",1,"1"],
		["specVersion/minor",1,"0"],
		["actionList/action/name",2,["Reverse","BadReverse"]],
		["actionList/action/argumentList/argument/name",5,["String","Reversed","BadExtra"]],
		["actionList/action/argumentList/argument/direction",5,["in","out"]],
		["actionList/action/argumentList/argument/relatedStateVariable",5,["A_ARG_TYPE_BADREV_IN","A_ARG_TYPE_BADREV_OUT","A_ARG_TYPE_BADREV_OUT2","A_ARG_TYPE_REV_IN","A_ARG_TYPE_REV_OUT"]],
		["actionList/action/argumentList/argument[name='String']/retval",0,nil],
		["actionList/action/argumentList/argument[name='Reversed']/retval",2,""],
		["actionList/action/argumentList/argument[name='BadExtra']/retval",0,nil],				
		["serviceStateTable/stateVariable/name",6,["A_ARG_TYPE_REV_IN","A_ARG_TYPE_REV_OUT","A_ARG_TYPE_BADREV_IN","A_ARG_TYPE_BADREV_OUT","A_ARG_TYPE_BADREV_OUT2","CHARS"]],
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
		uri2 = URI('http://127.0.0.1:54321/test/services/sample1/String/control.xml')
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


# call the modulo action

		req = Net::HTTP::Post.new(uri)
		req['SOAPACTION'] = '"urn:schemas-upnp-org:service:Math:1#Divide"'
		req.body='<?xml version="1.0"?> 
			<s:Envelope
			xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
			s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
			<s:Body>
			<u:Divide xmlns:u="urn:schemas-upnp-org:service:Math:1">
			<Top>5</Top>
			<Bottom>2</Bottom>
			</u:Divide>
			</s:Body>
			</s:Envelope>'

		res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }

		assert(res.is_a?(Net::HTTPSuccess))
		assert_equal("200",res.code)
		
		document = REXML::Document.new res.body

		w = REXML::XPath.first(document, "//m:Envelope/", {"m"=>"http://schemas.xmlsoap.org/soap/envelope/"})
		x = REXML::XPath.first(document, "//m:Envelope/m:Body", {"m"=>"http://schemas.xmlsoap.org/soap/envelope/"})
		y =  REXML::XPath.first(x,"//p:DivideResponse",{"p" => "urn:schemas-upnp-org:service:Math:1"})
		
		assert_equal("http://schemas.xmlsoap.org/soap/encoding/",w.attributes["s:encodingStyle"])
		assert_equal(2,y.elements.size,"returned arguments")
		assert_equal("Result",y.elements[1].name,"argument name")
		assert_equal("2",y.elements[1].text,"argument value")
		assert_equal("Modulo",y.elements[2].name,"argument name")
		assert_equal("1",y.elements[2].text,"argument value")

		assert_match  Regexp.new("\\d+", Regexp::IGNORECASE), res.to_hash["content-length"] [0]
		assert_match  res.body.size.to_s, res.to_hash["content-length"] [0]
		assert_match  "", res.to_hash["ext"] [0]
		assert_match  'text/xml; charset="utf-8"', res.to_hash["content-type"] [0]


# call the modulo action with inappropriate arguments 

		req = Net::HTTP::Post.new(uri)
		req['SOAPACTION'] = '"urn:schemas-upnp-org:service:Math:1#Divide"'
		req.body='<?xml version="1.0"?> 
			<s:Envelope
			xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
			s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
			<s:Body>
			<u:Divide xmlns:u="urn:schemas-upnp-org:service:Math:1">
			<Top>5.8</Top>
			<Bottom>2.1</Bottom>
			</u:Divide>
			</s:Body>
			</s:Envelope>'

		res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }

		refute(res.is_a?(Net::HTTPSuccess))
		assert_equal("500",res.code)
		
		ec = REXML::XPath.first(REXML::Document.new(res.body), "//m:Envelope/m:Body/m:Fault/detail/n:UPnPError/n:errorCode", {"m"=>"http://schemas.xmlsoap.org/soap/envelope/", "n"=>"urn:schemas-upnp-org:control-1-0"})		
		assert_equal("402",ec.text,"Call modulo with incorrect arguments")
		
		
		req = Net::HTTP::Post.new(uri)
		req['SOAPACTION'] = '"urn:schemas-upnp-org:service:Math:1#Divide"'
		req.body='<?xml version="1.0"?> 
			<s:Envelope
			xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
			s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
			<s:Body>
			<u:Divide xmlns:u="urn:schemas-upnp-org:service:Math:1">
			<Top>Five</Top>
			<Bottom>2</Bottom>
			</u:Divide>
			</s:Body>
			</s:Envelope>'

		res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }

		refute(res.is_a?(Net::HTTPSuccess))
		assert_equal("500",res.code)
		ec = REXML::XPath.first(REXML::Document.new(res.body), "//m:Envelope/m:Body/m:Fault/detail/n:UPnPError/n:errorCode", {"m"=>"http://schemas.xmlsoap.org/soap/envelope/", "n"=>"urn:schemas-upnp-org:control-1-0"})		
		assert_equal("402",ec.text,"Call modulo with incorrect arguments")
				
		
# call the reverser action

		req = Net::HTTP::Post.new(uri2)
		req['SOAPACTION'] = '"urn:schemas-upnp-org:service:String:1#Reverse"'
		req.body='<?xml version="1.0"?> 
			<s:Envelope
			xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
			s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
			<s:Body>
			<u:Reverse xmlns:u="urn:schemas-upnp-org:service:String:1">
			<String>Not a Palindrome!</String>
			</u:Reverse>
			</s:Body>
			</s:Envelope>'

		res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }

		assert(res.is_a?(Net::HTTPSuccess))
		assert_equal("200",res.code)
		
		document = REXML::Document.new res.body

		w = REXML::XPath.first(document, "//m:Envelope/", {"m"=>"http://schemas.xmlsoap.org/soap/envelope/"})
		x = REXML::XPath.first(document, "//m:Envelope/m:Body", {"m"=>"http://schemas.xmlsoap.org/soap/envelope/"})
		y =  REXML::XPath.first(x,"//p:ReverseResponse",{"p" => "urn:schemas-upnp-org:service:String:1"})
		
		assert_equal("http://schemas.xmlsoap.org/soap/encoding/",w.attributes["s:encodingStyle"])
		assert_equal(1,y.elements.size,"returned arguments")
		assert_equal("Reversed",y.elements[1].name,"argument name")
		assert_equal("!emordnilaP a toN",y.elements[1].text,"argument value")

		assert_match  Regexp.new("\\d+", Regexp::IGNORECASE), res.to_hash["content-length"] [0]
		assert_match  res.body.size.to_s, res.to_hash["content-length"] [0]
		assert_match  "", res.to_hash["ext"] [0]
		assert_match  'text/xml; charset="utf-8"', res.to_hash["content-type"] [0]

# call the reverser action but on the Math URL

		req = Net::HTTP::Post.new(uri)
		req['SOAPACTION'] = '"urn:schemas-upnp-org:service:String:1#Reverse"'
		req.body='<?xml version="1.0"?> 
			<s:Envelope
			xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
			s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
			<s:Body>
			<u:Reverse xmlns:u="urn:schemas-upnp-org:service:String:1">
			<String>Not a Palindrome!</String>
			</u:Reverse>
			</s:Body>
			</s:Envelope>'

		res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }

		refute(res.is_a?(Net::HTTPSuccess))
		assert_equal("500",res.code)
		ec = REXML::XPath.first(REXML::Document.new(res.body), "//m:Envelope/m:Body/m:Fault/detail/n:UPnPError/n:errorCode", {"m"=>"http://schemas.xmlsoap.org/soap/envelope/", "n"=>"urn:schemas-upnp-org:control-1-0"})		
		assert_equal("401",ec.text,"Call String function on Math service")
			
# call the bad_reverse action	

		req = Net::HTTP::Post.new(uri2)
		req['SOAPACTION'] = '"urn:schemas-upnp-org:service:String:1#BadReverse"'
		req.body='<?xml version="1.0"?> 
			<s:Envelope
			xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
			s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
			<s:Body>
			<u:BadReverse xmlns:u="urn:schemas-upnp-org:service:String:1">
			<String>Not a Palindrome!</String>
			</u:BadReverse>
			</s:Body>
			</s:Envelope>'

		res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }

		refute(res.is_a?(Net::HTTPSuccess))
		assert_equal("500",res.code)
		ec = REXML::XPath.first(REXML::Document.new(res.body), "//m:Envelope/m:Body/m:Fault/detail/n:UPnPError/n:errorCode", {"m"=>"http://schemas.xmlsoap.org/soap/envelope/", "n"=>"urn:schemas-upnp-org:control-1-0"})		
		assert_equal("402",ec.text,"Call BadReverse action")
			
	end
	
	
	def teardown

	@root.stop
		
	end

end


