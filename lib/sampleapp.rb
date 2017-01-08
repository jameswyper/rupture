

=begin rdoc

This program sets up a UPnP server device using the tapiola framework.  By itself it doesn't do anything useful whatsoever. Its purpose is to show how a real UPnP server would be built from the framework and provide enough comments to get you started on your own.

The SampleApp device will contain one embedded device (not sure how much embedded devices are used in the real world)
The embedded device will contain a single, simple service with one evented and one non-evented state variable
The root device will contain two slightly more complex services and a full range of state variables

=end

require_relative 'tapiola/UPnP.rb'

=begin rdoc
We begin by deriving classes from rootDevice and Device.  The only behaviour we need to specialise is that for the Presentation part of the specification; if we didn't want to do this (ie if we weren't bothering with the Presentation part of the specification, which is optional, then we could just use the base classes
=end

class SampleAppRoot < UPnP::RootDevice
	
=begin rdoc
Any Presentation functionality required should be provided by this method.
req and res are the standard WEBrick request and response objects as processed by WEBrick::AbstractServlet
action will be a symbol, either :GET or :POST depending on the http request passed to WEBrick (most of the time I'd expect this to be :GET but if you are using the Presentation functionality to change the behaviour of the server then :POST might be useful)
url is the URL that was entered in the browser, stripped of some preceeding parts
The method must return (not raise) the WEBrick exception required (usually WEBrick::HTTPStatus::OK or NotFound)

In the example below the URL and HTTP action are validated and a simple response returned.  Real implementations will be much more complex.
=end
	
	def handlePresentation(req,res,action,url)
		
		if (url == "presentation.xml")
			if (action == :GET)
				res.body = "SampleApp root device presentation on #{@ipPort}\r\n"
				return WEBrick::HTTPStatus::OK
			else
				return WEBrick::HTTPStatus::Error
			end
		else
			return WEBrick::HTTPStatus::NotFound
		else
	end
	
end

=begin rdoc
This behaves in exactly the same way as the SampleAppRoot class (RootDevice is derived from Device, and the default handlePresentation method lives there)
=end

class SampleAppEmbedded < UPnP::Device
	
	def handlePresentation(req,res,action,url)
		
		if (url == "presentation.xml")
			if (action == :GET)
				res.body = "SampleApp embedded device presentation on #{@ipPort}\r\n"
				return WEBrick::HTTPStatus::OK
			else
				return WEBrick::HTTPStatus::Error
			end
		else
			return WEBrick::HTTPStatus::NotFound
		else
	end
end

=begin rdoc

=end

class SampleAppServ1 < UPnP::Service
end

class SampleAppServ1 < UPnP::Service
end

class SampleAppServ1 < UPnP::Service
end




#Now we come to the real action
# First we create our root device

root = SampleAppRoot.new

# Then we add whichever properties are needed.  Some of these are optional but Friendly Name, Manufacturer, Model and Model Number are mandatory

root.properties[:FriendlyName] = "Sample App Root Server"

# Then we will create the embedded device.  We won't set a property

emb = SampleAppEmbedded.new
emb.properties[:FriendlyName] = "Sample App Embedded Server"

# Then we create the necessary services.  Because most of the specialisation is done at the class, rather than instance, level, this is very simple

s1 = SampleAppServ1.new
s2 = SampleAppServ2.new
s3 = SampleAppServ3.new

# Then we link our device and services together

root.addDevice(emb)
root.addService(s1)
root.addService(s2)
emb.addService(s3)

# finally we set a kernel trap for SIGINT to stop the server gracefully and start the WEBrick and UDP servers

kernel.trap("INT") do 
	root.stop
end

root.start


