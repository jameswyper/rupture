

#Copyright 2017 James Wyper

require 'minitest/autorun'
require_relative '../lib/tapiola/UPnP.rb'
require  'rexml/document'
require 'pry'
require 'httpclient'
require 'webrick'

=begin

proper subscription
one with infinite timeout
one with actual timeout
one with below minimum timeout

	

=end

class TestSimpleEvent < Minitest::Test
	
	
	class Adder
		def initialize(sv)
			@count = 0
			@stateVariables = sv
			Thread.new { sleep (1); @stateVariables["TICKER"] .assign(@stateVariables["TICKER"].value + 1) }
		end
		def add(inargs)
			outargs = Hash.new
			@count += 1
			@stateVariables["COUNT"].assign(@count)
			outargs["Result"] = inargs["First"] + inargs["Second"]
			@stateVariables["ACCUMULATOR"].assign(@stateVariables["ACCUMULATOR"].value + outargs["Result"])
			return outargs
		end
	end
	

	class Subscriber

		class SubscriberServlet < WEBrick::HTTPServlet::AbstractServlet
			def do_NOTIFY(req,res)
				$eventMsgs[@options[0]].push([req.header,req.body,Time.now])
			end
		end
	

		def initialize(port)
			@port = port
			@webserver = WEBrick::HTTPServer.new(:Port=>port)
			@webserver.mount "/messageshere",SubscriberServlet, port
			Thread.new {@webserver.start}
			$eventMsgs[@port]=Queue.new
		end
		
		def stop
			@webserver.stop
		end

		def subscribe(uri,timeout=nil)
			c = HTTPClient.new
			if timeout
				d= c.request("SUBSCRIBE",uri,:header =>{"nt"=>"upnp:event","timeout"=>"seconds-#{timeout}","callback"=>"localhost:#{@port}/messageshere/"})
			else
				d= c.request("SUBSCRIBE",uri,:header =>{"nt"=>"upnp:event","timeout"=>"infinite","callback"=>"localhost:#{@port}/messageshere/"})
			end
			@sid = d.headers["Sid"]
			@headers = d.headers
		end

		attr_reader :headers, :sid

	end
	

	def checkSubscriptionResponse(sub,expected)
		expected.each do |k,v| 
			assert_equal v, sub.headers[k], "On Subscription - Difference for header #{k}"
		end
		refute_nil(sub.sid,"Subscription ID is nil")
	end
	
	
	
	def checkEventMessage(headers,body,expHeaders,expValues,context="")
		expHeaders.each do |k,v| 
			assert_equal v, headers[k][0], "#{context}: Event notification: Difference for header #{k}"
		end
		doc = REXML::Document.new(body)
		
		ps = REXML::XPath.match(doc, "//m:propertyset", {"m"=>"urn:schemas-upnp-org:event-1-0"})
		p = REXML::XPath.match(doc, "//m:propertyset/m:property", {"m"=>"urn:schemas-upnp-org:event-1-0"})
		
		assert_equal(1, ps.size, "#{context}: Response XML didn't have exactly 1 propertyset element")
		
		h = Hash.new
		
		p.each do |prop|
			assert_equal(1,prop.elements.size,"#{context}: Reponse XML didn't have one variable per property tag")
			prop.each_element do |e|
				h[e.name] = e.text
			end
		end
		
		assert_equal(expValues.size,h.size,"#{context}: Number of variables in notification")
		
		expValues.each do |k,v|
			assert_equal v,h[k],"#{context}: Event variable #{k} value differs"
		end

	end

	def setup
	
		
		$eventMsgs = Hash.new
		@regular= Subscriber.new(60000)
		@second = Subscriber.new(60001)
	
		@root = UPnP::RootDevice.new(:type => "SampleOne", :version => 1, :name => "sample1", :friendlyName => "SampleApp Root Device",
			:product => "Sample/1.0", :manufacturer => "James", :modelName => "JamesSample",	:modelNumber => "43",
			:modelURL => "github.com/jameswyper/tapiola", :cacheControl => 15,
			:serialNumber => "12345678", :modelDescription => "Sample App Root Device, to illustrate use of tapiola UPnP framework", 
			:URLBase => "test", :ip => "127.0.0.1", :port => 54321, 
			:logLevel => Logger::DEBUG)
		
		@serv1 = UPnP::Service.new("Math",1)
		
		@sv1 = UPnP::StateVariableInt.new( :name => "A_ARG_TYPE_FIRST")
		@sv2 = UPnP::StateVariableInt.new( :name => "A_ARG_TYPE_SECOND")		
		@sv3 = UPnP::StateVariableInt.new( :name => "A_ARG_TYPE_OUT")		
		@sv4 = UPnP::StateVariableInt.new( :name => "COUNT", :evented => true, :initialValue => 0)
		@sv5 = UPnP::StateVariableInt.new( :name => "ACCUMULATOR", :evented => true, :initialValue => 0, :moderationType => :delta, :minimumDelta => 10, :allowedIncrement => 1 )
		@sv6 = UPnP::StateVariableInt.new( :name => "TICKER", :evented => true, :initialValue => 0, :maximumRate => 3,:moderationType => :rate )
		@serv1.addStateVariables(@sv1, @sv2, @sv3, @sv4, @sv5, @sv6)
		@adder = Adder.new(@serv1.stateVariables)		


		@act1 = UPnP::Action.new("Add",@adder,:add)
		@act1.addArgument(UPnP::Argument.new("Second",:in,@sv2),2)
		@act1.addArgument(UPnP::Argument.new("First",:in,@sv1),1)
		@act1.addArgument(UPnP::Argument.new("Result",:out,@sv3,true),1)
		

		@serv1.addAction(@act1)
		
		@root.addService(@serv1)		
		Thread.new {@root.start}

		sleep(0.1)
	end
	

	def call_action(a,b)
		
		c = HTTPClient.new
		d= c.request("POST",'http://127.0.0.1:54321/test/services/sample1/Math/control.xml',
		:header =>{"soapaction"=>'"urn:schemas-upnp-org:service:Math:1#Add"'},
		:body => '<?xml version="1.0"?> 
			<s:Envelope
			xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
			s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
			<s:Body>
			<u:Add xmlns:u="urn:schemas-upnp-org:service:Math:1">
			<First>' + a.to_s + '</First>
			<Second>' + b.to_s + '</Second>
			</u:Add>
			</s:Body>
			</s:Envelope>')
			
		assert_equal 200,d.code,"Call to action failed"

	end
	
	def test_event
		
		
		
	uri = "http://127.0.0.1:54321/test/services/sample1/Math/event.xml"
	@regular.subscribe(uri,60000)

	checkSubscriptionResponse(@regular,{ "Timeout" => "infinite" })

	call_action(2,2)

	x = $eventMsgs[60000].pop
	checkEventMessage(x[0],x[1],{"sid"=>@regular.sid, "seq" => "0", "host" => "localhost:60000", "content-type" => "text/xml","nt"=>"upnp:event","nts"=>"upnp:propchange"},
	{"COUNT"=>"0", "TICKER" => "0", "ACCUMULATOR" => "0"},"Initial Subscription")
	
	x = $eventMsgs[60000].pop
	checkEventMessage(x[0],x[1],{"sid"=>@regular.sid, "seq" => "1", "host" => "localhost:60000", "content-type" => "text/xml","nt"=>"upnp:event","nts"=>"upnp:propchange"},
	{"COUNT"=>"1"},"First action")

	call_action(3,3)

	x = $eventMsgs[60000].pop
	checkEventMessage(x[0],x[1],{"sid"=>@regular.sid, "seq" => "2", "host" => "localhost:60000", "content-type" => "text/xml","nt"=>"upnp:event","nts"=>"upnp:propchange"},
	{"COUNT" => "2"},"Second action - count #{x[1]}")

	x = $eventMsgs[60000].pop
	checkEventMessage(x[0],x[1],{"sid"=>@regular.sid, "seq" => "3", "host" => "localhost:60000", "content-type" => "text/xml","nt"=>"upnp:event","nts"=>"upnp:propchange"},
	{"ACCUMULATOR" => "10"},"Second action - accumulator #{x[1]}")	
	
	sleep(1.1)
	
	@second.subscribe(uri,30)
	checkSubscriptionResponse(@second,{ "Timeout" => "infinite" })	
	
	x = $eventMsgs[60001].pop
	checkEventMessage(x[0],x[1],{"sid"=>@second.sid, "seq" => "0", "host" => "localhost:60001", "content-type" => "text/xml","nt"=>"upnp:event","nts"=>"upnp:propchange"},
	{"COUNT"=>"2", "TICKER" => "1", "ACCUMULATOR" => "10"},"Second Subscription #{x[1]}")	
	
	assert_equal($eventMsgs[60000].size,0,"Queue for first sub not empty")
	assert_equal($eventMsgs[60001].size,0,"Queue for second sub not empty")	
	
	sleep(2)
	x = $eventMsgs[60001].pop
	checkEventMessage(x[0],x[1],{"sid"=>@second.sid, "seq" => "1", "host" => "localhost:60001", "content-type" => "text/xml","nt"=>"upnp:event","nts"=>"upnp:propchange"},
	{"TICKER" => "3"},"Second Subscription #{x[1]}")	
	x = $eventMsgs[60000].pop
	checkEventMessage(x[0],x[1],{"sid"=>@second.sid, "seq" => "4", "host" => "localhost:60001", "content-type" => "text/xml","nt"=>"upnp:event","nts"=>"upnp:propchange"},
	{"TICKER" => "3", },"Second Subscription #{x[1]}")	

	call_action(3,3)
	x = $eventMsgs[60001].pop
	checkEventMessage(x[0],x[1],{"sid"=>@regular.sid, "seq" => "2", "host" => "localhost:60000", "content-type" => "text/xml","nt"=>"upnp:event","nts"=>"upnp:propchange"},
	{"COUNT" => "3"},"Third action - count #{x[1]}")
	x = $eventMsgs[60000].pop
	checkEventMessage(x[0],x[1],{"sid"=>@regular.sid, "seq" => "5", "host" => "localhost:60000", "content-type" => "text/xml","nt"=>"upnp:event","nts"=>"upnp:propchange"},
	{"COUNT" => "3"},"Third action - count #{x[1]}")


	assert_equal($eventMsgs[60000].size,0,"Queue for first sub not empty")
	assert_equal($eventMsgs[60001].size,0,"Queue for second sub not empty")	

#still to test
#cancelling a sub
#renewing a sub


	end
	
	
	def teardown

	@root.stop
	@regular.stop
		
	end

end

