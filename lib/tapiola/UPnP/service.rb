
#Copyright 2017 James Wyper

require_relative 'common'
require_relative 'stateVariable'
require 'rexml/document'
require 'rexml/xmldecl'

module UPnP

=begin

A UPnP Service consists of state variables and actions, this is a class to hold essential information about the service.

A real service should instantiate this class, set up the state variables and actions (which are also derived from simple base classes #UPnPAction and #UPnPStateVariable) and use #addStateVariable and #addAction to associate them with the service.
   
   
=end

class Service
	
	# standard UPnP name for the service e.g. ConnectionManager
	attr_reader :type 
	# standard UPnP version, an integer
	attr_reader :version 
	# list of all actions associated with the service
	attr_reader :actions 
	# list of all state variables associated with the service
	attr_reader :stateVariables
	# control address (to form control URL with)
	attr_reader :controlAddr
	# description address (to form SCDP URL with)
	attr_reader :descAddr
	# eventing address (to form event subscription URL with)
	attr_reader :eventAddr
	# subscriptions attached to the service
	attr_reader :subscriptions
	# device the service is attached to
	attr_reader :device

=begin rdoc
Set up the serivce with the Service Type (e.g. ContentDirectory) and version number
=end
	
	def initialize(t, v)
		@type = t
		@version = v
		@actions = Hash.new
		@stateVariables =  Hash.new
		@subscriptions = Hash.new
	end
	
=begin rdoc
Links a State Variable to the service
=end
	def addStateVariable(s)
		@stateVariables[s.name]  = s
		s.service = self
	end
	
=begin rdoc
Convenience method - links multiple state variables to the service
=end
	def addStateVariables(*a)
		a.each { |s| addStateVariable(s) }
	end
	
=begin rdoc
Links an Action to the service
=end
	def addAction(a)
		@actions[a.name] = a
		a.linkToService(self)
	end
	
=begin rdoc
Links multiple Actions to the service
=end
	def addActions(*a)
		a.each {|s| addAction(s)}
	end
	
=begin rdoc
Links the Service to a UPnP Device
=end
	def linkToDevice(d)
		@device = d
		servAddr = "#{d.urlBase}/services/#{d.name}/#{@type}/"
		@eventAddr = servAddr + "event.xml"
		@controlAddr = servAddr + "control.xml"
		@descAddr = servAddr + "description.xml"
	end
	
=begin rdoc
returns a REXML::Document object containing the UPnP Service Description XML
=end
	def createDescriptionXML
		
		rootE =  REXML::Element.new("scpd")
		rootE.add_namespace("urn:schemas-upnp-org:device-1-0")
		
		spv = REXML::Element.new("specVersion")
		spv.add_element("major").add_text("1")
		spv.add_element("minor").add_text("0")
		rootE.add_element(spv)

		al = REXML::Element.new("actionList")
		@actions.each_value do |a|
			ae = REXML::Element.new("action")
			ae.add_element("name").add_text(a.name)
			gle = REXML::Element.new("argumentList")
			ae.add_element(gle)
			x = Array.new
			a.args.each_value { |ag| x << ag }
			x.sort! {|a,b| [a.arg.direction, a.seq] <=> [b.arg.direction, b.seq]}
			x.each do |ag|
				g = ag.arg
				ge = REXML::Element.new("argument")
				ge.add_element("name").add_text(g.name)
				ge.add_element("direction").add_text(g.direction.to_s)
				if (g.returnValue?)
					ge.add_element("retval")
				end
				ge.add_element("relatedStateVariable").add_text(g.relatedStateVariable.name)
				gle.add_element(ge)
			end
			al.add_element(ae)
		end
		
		svl = REXML::Element.new("serviceStateTable")
		@stateVariables.each_value do |sv|
			sve = REXML::Element.new("stateVariable")
			if sv.evented?
				sve.add_attribute("sendEvents","yes")
			else
				sve.add_attribute("sendEvents","no")
			end
			sve.add_element("name").add_text(sv.name)
			sve.add_element("dataType").add_text(sv.type)
			sve.add_element("defaultValue").add_text(sv.defaultValue) if (sv.defaultValue)
			if sv.allowedValueList?
				avle = REXML::Element.new("allowedValueList")
				sv.allowedValues.each_value do |v|
					avle.add_element("allowedValue").add_text(v.to_s)
				end
				sve.add_element(avle)
			elsif	sv.allowedValueRange?
				avre = REXML::Element.new("allowedValueRange")
				avre.add_element("minimum").add_text(sv.allowedMin)
				avre.add_element("maximum").add_text(sv.allowedMax)				
				avre.add_element("step").add_text(sv.allowedIncrement)
				sve.add_element(avre)
			end
			svl.add_element(sve)
		end
		
		rootE.add_element(al)
		rootE.add_element(svl)
		
		doc = REXML::Document.new
		doc << REXML::XMLDecl.new(1.0)
		doc.add_element(rootE)
		
		return doc

	end
	
=begin	
	def handleEvent(req, res)
	
	#decode the XML
	#new cancel or renew?
	#
	#new - set up new subscription
	s = Subscription.new(callbackHeader, expiry)
	unless s.invalid? then @subscriptions[s.sid] = s end
	
	#new - send events - needs to be deferred for later, how?
	#
	#cancel - find subscription 
	#cancel - set subscription to expired
	#
	#renew - find subscription
	#renew - set expiry time
	
	#delete expired subscriptions
	
	#create response
		
	end
=end
	
	def handleSubscribe(req,res)
		
		$log.debug("Event subscription request, headers follow")
		req.header.each { |k,v| $log.debug ("Header: #{k} Value: #{v}") }
		
		host = req.header["host"][0]
		nt = req.header["nt"][0]
		callback = req.header["callback"][0]
		timeout = req.header["timeout"][0]
		sid = req.header["sid"][0]

		seconds = 0
		if timeout
			md = /seconds-\\d+/.match(timeout)
			if (md)
				seconds = md[1]
				if seconds < 1800 then seconds = 1800 end
			end
		end

		if !host
			res.status = 400
			$log.warn("event subscription with no host header")
		else
			if (nt != "upnp:event") && (!sid)
				res.status = 412
				$log.warn("event subscription with no nt header")
			else
				if callback && !sid
					if  callback =~ URI::regexp
						sub = Subscription.new(self,callback,seconds)

=begin
	The next few lines of code need a bit of explanation.  We cannot send the initial subscription message (containing the values of all the state variables) until we are sure that the subscriber has received the response to their subscription request.  But Webrick doesn't provide a way of telling us that this has happened.  
	So what we do is to override the send_response method within Webrick by creating a singleton method (ie one that's assoicated with just this instance of the res object, not the whole class).  We also attach an extra variable to this object, a reference to the subscription we are setting up via a second singleton method.
	The first singleton (send_response) firstly locates and calls the original send_response method for the res object and calls that.  That means we know that the subscriber has received the SID and it's OK to send the initial subscription message.  So we then queue that up for sending, and set the subscription as active (ie subsequent changes to the evented state variables for the service will be sent via this subscription).  Note that this singleton is *defined* here but it's not actually *executed* until Webrick processes the response later on.
	The second singleton simply stores the subscription for the first method to use later, it needs to run here and now so it is first defined and then executed.
	
	I love that Ruby allows you to do this kind of thing but I still can't decide whether it's brilliant or horrible that I've done it.
=end

						def res.send_response(sock)
							self.class.instance_method(:send_response).bind(self).call(sock)
							@stashedSub.service.device.rootDevice.queueEvent(@stashedSub,@stashedSub.service.stateVariables.values)
							@stashedSub.activate
						end
						
						def res.stash_subscription(s)
							@stashedSub = s
						end
						
						res.stash_subscription(sub)
						
# create the headers for the http response
						if seconds == 0
							res.header["timeout"] = "infinite"
						else
							res.header["timeout"] = "seconds-#{seconds}"
						end
						res.header["sid"] = sub.sid
						
					else
						res.status = 412
						$log.warn("invalid callback url #{callback} received for event subscription")
					end
				else
					if sid && !callback
						if !nt  #then create the renewal
							sub = @subscriptions[sid]
							if sub
								sub.renew(seconds)
							else
								res.status = 412
								$log.warn("SID #{sid} not found for subscription renewal")
							end
						else
							res.status = 400 # specified SID and NT together
							$log.warn("SID and NT headers both found in event subscription")
						end
					else
						res.status = 400 
						$log.warn("SID and Callback headers neither or both found in event subscription")
					end
				end
			end
		end
					
	end
	
	def handleUnsubscribe(req,res)
		$log.debug("Event subscription cancellation request, headers follow")
		req.header.each { |k,v| $log.debug ("Header: #{k} Value: #{v}") }
		
		host = req.header["host"][0]
		sid = req.header["sid"][0]
		nt = req.header["nt"][0]
		callback = req.header["callback"][0]		
		
		if !host
			res.status = 400
			$log.warn("event subscription with no host header")
		else
			if (!sid)
				res.status = 412
				$log.warn("No SID header for subscription cancellation")				
			else
				if (nt || callback)
					res.status = 400
					$log.warn("NT and CALLBACK headers for subscription cancellation")				
				else
					sub = @subscriptions[sid]	
					if sub
						sub.cancel
					else
						res.status = 412
						$log.warn("SID #{sid} not found for subscription cancellation")				
					end
				end
			end
		end
	end
	
	def addSubscription(sub)
		@subscriptions[sub.sid] = sub
	end
	
	def removeSubscription(sub)
		@subscriptions[sub.sid].delete
	end
	
=begin
Takes the XML sent by a control point (and the SOAPACTION part of the http header), validates it and extracts the name and arguments of the action requested.
=end
	def processActionXML(xml,soapaction)

		$log.debug("XML: #{xml}")
		$log.debug("soapaction field: #{soapaction}")
		
		re = /^"(.*)#(.*)"$/
		md = re.match(soapaction)
		
		if (md != nil) && (md[1] != nil) && (md[2] != nil)
			namespace = md[1]
			action = md[2]
		else
			$log.warn("SOAPACTION header invalid - was :#{soapaction}:")
			raise ActionError.new(401)
		end
		$log.debug ("Namespace #{namespace} and Action #{action} obtained from header")


		begin
			doc = REXML::Document.new xml
		rescue REXML::ParseException => e
			$log.warn("XML didn't parse #{e}")
			raise ActionError.new(401)
		end

		soapbody = REXML::XPath.first(doc, "//m:Envelope/m:Body", {"m"=>"http://schemas.xmlsoap.org/soap/envelope/"})
		unless soapbody
			$log.warn("Couldn't get SOAP body out of #{xml}")
			raise ActionError.new(401)
		end
		
		argsxml =  REXML::XPath.first(soapbody,"//p:#{action}",{"p" => "#{namespace}"})
		unless argsxml
			$log.warn("Couldn't get action name out of #{xml} with SOAPACTION header :#{soapaction}:")
			raise ActionError.new(401)
		end

		if (action != argsxml.name)
			$log.warn("SOAPACTION header :#{soapaction}: didn't match XML name #{xml}")
			raise ActionError,401
		end

		args = Hash.new
		
		argsxml.elements.each {|e| args[e.name] = e.text}
		
		return action, args

	end
	
=begin rdoc
Called by the Webserver when something is posted to the Control URL for the service.
Extracts the requested action and arguments (via call to #processActionXML)
Checks that the action exists
Validates the arguments passed in
Invokes the action
Validates the arguments passed back from the invoke
Constructs a response indicating success or failure
=end
	def handleControl(req, res)
	
		$log.debug("in handleControl for service #{@name}")
	
		begin
			actionname, args = processActionXML(req.body,req.header["soapaction"].join)
			action = @actions[actionname]
			if action == nil
				$log.warn("Action #{actionname} doesn't exist in service #{@name}")
				raise ActionError.new(401)
			else
				action.validateInArgs(args)
				outArgs = action.invoke(args)
				action.validateOutArgs(outArgs)
				action.responseOK(res,outArgs)
				return true
			end
		rescue ActionError => e
			$log.warn("Service #{@name}, Exception message #{e.message}")
			responseError(res,e.code)
			return false
		end
		
	end

=begin rdoc
Populates the httpResponse object passed from the webserver with the correct headers and xml for an unsuccessful response to an Action call
This needs to be a method on the service class, not action, because the error may be that the action doesn't exist
=end



	def responseError(res,code)
		
		rootE =  REXML::Element.new("s:Envelope")
		rootE.add_namespace("s","http://schemas.xmlsoap.org/soap/envelope/")
		rootE.attributes["s:encodingStyle"] = "http://schemas.xmlsoap.org/soap/encoding/"
		
		bod = REXML::Element.new("s:Body")
		
		fault = REXML::Element.new("s:Fault")
		faultcode = REXML::Element.new("faultcode").add_text("s:Client")
		faultstring = REXML::Element.new("faultstring").add_text("UPnPError")
		detail = REXML::Element.new("detail")
		upnpError = REXML::Element.new("UPnPError").add_namespace("urn:schemas-upnp-org:control-1-0")
		errorCode = REXML::Element.new("errorCode").add_text(code.to_s)
		
		upnpError.add_element(errorCode)
		detail.add_element(upnpError)
		fault.add_element(faultcode)
		fault.add_element(faultstring)
		fault.add_element(detail)
		bod.add_element(fault)
		rootE.add_element(bod)
		
		
		doc = REXML::Document.new
		doc.context[:attribute_quote] = :quote
		doc << REXML::XMLDecl.new(1.0)
		doc.add_element(rootE)
		

		res.status = 500
		doc.write(res.body)

		res.content_type = 'text/xml; charset="utf-8"'
		res["ext"] = ""
		res["server"] = "#{@device.rootDevice.os} UPnP/1.0 #{@device.rootDevice.product}"
	end

=begin rdoc
Called by the Webserver when something is requested from the Description URL for the service.
Returns the service description in XML format
=end

	
	def handleDescription(req, res)
		$log.debug("Description (service) request: #{req}")
		res.body = createDescriptionXML.to_s
		res.content_type = "text/xml"
	end
	
=begin rdoc
Not sure if I need to put anything here yet
=end
	def validate
	end
		
end


end