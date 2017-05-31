

=begin

	
=end

require 'minitest/autorun'
require_relative '../lib/tapiola/UPnP.rb'
require 'nokogiri'
require 'net/http'
require  'rexml/document'

UUIDREGEXP = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"

DEVICEXSD = <<ENDXML
<?xml version="1.0" encoding="UTF-8"?>
<xs:schema
  targetNamespace="urn:schemas-upnp-org:device-1-0"
  xmlns:tns="urn:schemas-upnp-org:device-1-0"
  xmlns="urn:schemas-upnp-org:device-1-0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  attributeFormDefault="qualified" elementFormDefault="qualified">
 
  <xs:annotation>
    <xs:documentation>
      XML Schema for UPnP device descriptions in real XSD format
      (not like the XDR one from Microsoft)
      Created by Michael Weinrich 2007
      Amended by James Wyper 2015 to replace the xs:sequence tag with xs:all for DeviceType
      as the UPnP specification states that the order of elements is insignificant
      (at least it does for 1.0)
    </xs:documentation>
  </xs:annotation>

  <xs:element name="root">
    <xs:complexType>
      <xs:all>
        <xs:element name="specVersion" type="SpecVersionType" minOccurs="1" maxOccurs="1" />
        <xs:element name="URLBase" type="xs:string" minOccurs="0" maxOccurs="1" />
        <xs:element name="device" type="DeviceType" minOccurs="1" maxOccurs="1" />
      </xs:all>
      <xs:anyAttribute/>
    </xs:complexType>
  </xs:element>

  <xs:complexType name="SpecVersionType">
    <xs:all>
      <xs:element name="major" type="xs:int" minOccurs="1" />
      <xs:element name="minor" type="xs:int" minOccurs="1"/>
    </xs:all>
  </xs:complexType>



  <xs:complexType name="DeviceType">
    <xs:all>
      <xs:element name="deviceType" type="xs:string" minOccurs="1" maxOccurs="1" />
      <xs:element name="friendlyName" type="xs:string" minOccurs="1" maxOccurs="1" />
      <xs:element name="manufacturer" type="xs:string" minOccurs="1" maxOccurs="1" />
      <xs:element name="manufacturerURL" type="xs:string" minOccurs="0" maxOccurs="1" />
      <xs:element name="modelDescription" type="xs:string" minOccurs="0" maxOccurs="1" />
      <xs:element name="modelName" type="xs:string" minOccurs="1" maxOccurs="1" />
      <xs:element name="modelNumber" type="xs:string" minOccurs="0" maxOccurs="1" />
      <xs:element name="modelURL" type="xs:string" minOccurs="0" maxOccurs="1" />
      <xs:element name="serialNumber" type="xs:string" minOccurs="0" maxOccurs="1" />
      <xs:element name="UDN" type="xs:string" minOccurs="1" maxOccurs="1" />
      <xs:element name="UPC" type="xs:string" minOccurs="0" maxOccurs="1" />
      <xs:element name="iconList" type="IconListType" minOccurs="0" maxOccurs="1" />
      <xs:element name="serviceList" type="ServiceListType" minOccurs="0" maxOccurs="1" />
      <xs:element name="deviceList" type="DeviceListType" minOccurs="0" maxOccurs="1" />
      <xs:element name="presentationURL" type="xs:string" minOccurs="0" maxOccurs="1" />
   </xs:all>
  </xs:complexType>
 
 
  <xs:complexType name="IconListType">
    <xs:sequence>
      <xs:element name="icon" minOccurs="1" maxOccurs="unbounded">
        <xs:complexType>
          <xs:all>
            <xs:element name="mimetype" type="xs:string" minOccurs="1" maxOccurs="1" />
            <xs:element name="width" type="xs:int" minOccurs="1" maxOccurs="1" />
            <xs:element name="height" type="xs:int" minOccurs="1" maxOccurs="1" />
            <xs:element name="depth" type="xs:int" minOccurs="1" maxOccurs="1" />
            <xs:element name="url" type="xs:string" minOccurs="1" maxOccurs="1" />
          </xs:all>
        </xs:complexType>
      </xs:element>
    </xs:sequence>
  </xs:complexType>

  <xs:complexType name="ServiceListType">
    <xs:sequence>
      <xs:element name="service" minOccurs="1" maxOccurs="unbounded">
        <xs:complexType>
          <xs:all>
            <xs:element name="serviceType" type="xs:string" minOccurs="1" maxOccurs="1" />
            <xs:element name="serviceId" type="xs:string" minOccurs="1" maxOccurs="1" />
            <xs:element name="SCPDURL" type="xs:string" minOccurs="1" maxOccurs="1" />
            <xs:element name="controlURL" type="xs:string" minOccurs="1" maxOccurs="1" />
            <xs:element name="eventSubURL" type="xs:string" minOccurs="1" maxOccurs="1" />
          </xs:all>
        </xs:complexType>
      </xs:element>
    </xs:sequence>
  </xs:complexType>

  <xs:complexType name="DeviceListType">
    <xs:sequence>
      <xs:element name="device" type="DeviceType" minOccurs="1" maxOccurs="unbounded"/>
    </xs:sequence>
  </xs:complexType>
 	 
</xs:schema>
ENDXML

SERVICEXSD = <<ENDXML

ENDXML

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
		@act1.addArgument(UPnP::Argument.new("Result",:out,@sv3))
		
		@serv1.addStateVariables(@sv1, @sv2, @sv3)
		@serv1.addAction(@act1)
		
		@root.addService(@serv1)		
		Thread.new {@root.start}


	end
	

	
	
	def test_simple
		
		

		#s = File.read('device.xsd')
		begin
		schema1 = Nokogiri::XML::Schema(DEVICEXSD)
		rescue => e
			puts "Device Schema didn't validate - message and line number follows"
			puts e, e.line
		end
		begin
		schema1 = Nokogiri::XML::Schema(SERVICEXSD)
		rescue => e
			puts "Service Schema didn't validate - message and line number follows"
			puts e, e.line
		end
	
	
	
		desc = Net::HTTP.get(URI("http://#{@root.ip}:#{@root.port}/test/description/description.xml"))

		
		document = Nokogiri::XML(desc)
		errs = schema1.validate(document)
		assert_equal 0, errs.size, "xml didn't validate against device.xsd"
		
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
		
		#document = Nokogiri::XML(desc)
		#errs = schema2.validate(document)
		#assert_equal 0, errs.size, "xml didn't validate against device.xsd"
		
		document = REXML::Document.new desc
		
end	
	
	
	def teardown

	@root.stop
		
	end
	
end

=begin
class TestComplexDescription < Minitest::Test
	
		
	def setup


	@root = UPnP::RootDevice.new(:Type => "SampleTwo", :Version => 2, :Name => "sample2", :FriendlyName => "SampleApp Root Device v2",
			:Product => "Sample/1.0", :Manufacturer => "James", :ModelName => "JamesSample",	:ModelNumber => "43",
			:ModelURL => "github.com/jameswyper/tapiola", :CacheControl => 15,
			:SerialNumber => "12345678", :ModelDescription => "Sample App Root Device, to illustrate use of tapiola UPnP framework", 
			:URLBase => "test", :IP => "127.0.0.1", :port => 54322, :LogLevel => Logger::INFO)
		
		
		@emb = UPnP::Device.new(:Type => "SampleThree", :Version => 3, :Name => "sample3", :FriendlyName => "SampleApp Embedded Device",
			 :Manufacturer => "James inc", :ModelName => "JamesSample III",	:ModelNumber => "42",	:ModelURL => "github.com/jameswyper/tapiola",
			:UPC => "987654321", :ModelDescription => "Sample App Embedded Device, to illustrate use of tapiola UPnP framework")
	
		@serv1 = UPnP::Service.new("Add",1)
		@serv2 = UPnP::Service.new("Find",3)
		@serv3 = UPnP::Service.new("Change",2)
		
		@root.addDevice(@emb)
		@root.addService(@serv1)
		@root.addService(@serv2)
		@emb.addService(@serv3)
		
		Thread.new {@root.start}

	
	end
	

	
	
	def test_SSDP
	
	end	
	
	
	def teardown
	
		@root.stop
	end
	
end
=end