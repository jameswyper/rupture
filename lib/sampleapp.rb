

=begin 

This program sets up a UPnP server device using the tapiola framework.  By itself it doesn't do anything useful whatsoever. Its purpose is to show how a real UPnP server would be built from the framework and provide enough comments to get you started on your own.

The SampleApp device will contain one embedded device (not sure how much embedded devices are used in the real world)
The embedded device will contain a single, simple service with one evented and one non-evented state variable
The root device will contain two slightly more complex services and a full range of state variables

=end

require_relative 'tapiola/UPnP.rb'

=begin 
We begin by creating the rootDevice.  This must be created first in order for things like the logger to work.  The only behaviour we need to specialise is that for the Presentation part of the specification.
=end

root = UPnP::RootDevice.new(:Type => "SampleOne", :Version => 1, :Name => "sample1", :FriendlyName => "SampleApp Root Device",
			:Product => "Sample/1.0", :Manufacturer => "James", :ModelName => "JamesSample",	:ModelNumber => "43",	:ModelURL => "github.com/jameswyper/tapiola",
			:SerialNumber => "12345678", :ModelDescription => "Sample App Root Device, for to illustrate use of tapiola UPnP framework")
	
=begin 
Any Presentation functionality required should be provided by this method.
req and res are the standard WEBrick request and response objects as processed by WEBrick::AbstractServlet
action will be a symbol, either :GET or :POST depending on the http request passed to WEBrick (most of the time I'd expect this to be :GET but if you are using the Presentation functionality to change the behaviour of the server then :POST might be useful)
url is the URL that was entered in the browser, stripped of some preceeding parts
The method must return (not raise) the WEBrick exception required (usually WEBrick::HTTPStatus::OK or NotFound)

In the example below the URL and HTTP action are validated and a simple response returned.  Real implementations will be much more complex.
=end
	
def root.handlePresentation(req,res,action,url)
	if (url == "presentation.xml")
		if (action == :GET)
			res.body = "SampleApp root device presentation on #{self.ipPort}\r\n"
			return WEBrick::HTTPStatus::OK
		else
			return WEBrick::HTTPStatus::Error
		end
	else
		return WEBrick::HTTPStatus::NotFound
	else
end
	


=begin 
We will create the embedded device next, and not override the standard (even more minimal) handlePresentation method
=end

emb = UPnP::Device.new(:Type => "SampleTwo", :Version => 3, :Name => "sample2", :FriendlyName => "SampleApp Embedded Device",
			 :Manufacturer => "James inc", :ModelName => "JamesSample II",	:ModelNumber => "42",	:ModelURL => "github.com/jameswyper/tapiola",
			:UPC => "987654321", :ModelDescription => "Sample App Embedded Device, to illustrate use of tapiola UPnP framework")
	



=begin
Services are, to begin with, just containers for State Variables and Actions.  So they are very easy to set up, just provide a type and version
=end

serv1 = UPnP::Service.new("Add",1)
serv2 = UPnP::Service.new("Find",2)
serv3 = UPnP::Service.new("ChangeVariable",1)

=begin


=end

sv1 = UPnP::StateVariable.new


# Then we link our device and services together

root.addDevice(emb)
root.addService(serv1)
root.addService(serv2)
emb.addService(serv3)

# note that root.devices["sample2"]

# finally we set a kernel trap for SIGINT to stop the server gracefully and start the WEBrick and UDP servers

kernel.trap("INT") do 
	root.stop
end

root.start


