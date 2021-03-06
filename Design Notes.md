#Notes on UPnP and my design

##The basic theory of how UPnP works

Some of this is abstracted from v1 of the UPnP Device Architecture document which can currently be found at http://upnp.org/specs/arch/UPnP-arch-DeviceArchitecture-v1.1.pdf

UPnP revolves around the concept of Devices, Services and Control Points.  Devices provide services.  Control Points use calls to services to make devices do things.  Tapiola does not support control points (it doesn't need to).

A device may be logically partitioned - the base or "root" device may - as well as providing services - contain other devices that themselves provide services.  I don't think that more than one level of nesting is allowed (ie a device can't be contained within any other device except the root device).  Any device may provide zero, one or many services.

In tapiola, these things are modelled as the classes UPnP::Device, UPnP::RootDevice and UPnP::Service.  Since a root device is a special kind of device, it's defined as a subclass of UPnPDevice.

Devices and services have two important properties: Type and Version.  The UPnP forum has created specs for standard types (e.g. MediaServer) but others can be defined.  The classes in tapiola only support standard types because that's all I need.  Version numbers are straight integers (no version 1.5).  Devices that contain a service at version x are expected to support versions 1 through x, not just x itself.

There are six things in UPnP that devices and/or services get involved with:

###1.  Addressing.  
This is the act of establishing a valid IP address for a device when it joins a network.  tapiola assumes it's running in an environment where the OS has taken care of all of this, so does not support Addressing.

###2.  Discovery.  
When a UPnP device starts up, it sends a series of "advertisment" messages using a protocol called SSDP.  These are sent as multicast UDP packets.  The number and content of the messages depends on whether the root device has any embedded devices, and which services are offered by the collection of devices.  There's a lot of boilerplate in the messages, the key things sent are the type and version for each device and each service offered by each device, as well as the uuid of the device (tapiola assigns a uuid when any instance of UPnPDevice is created).  A URL that's used for stage 3 (Description) is also sent.

The advertisment messages are repeated at a configurable interval, anything from 15 minutes upwards.

When the device shuts down (assuming it can do so gracefully) it will send another series of messages cancelling the advertisments.

The device also needs to listen for "search requests" which are sent by UPnP control points (things that request services) when they join the network (and maybe at other times?).  These search requests may ask for all root devices, all devices (root and embedded), devices or services of a specific type and version, or a device with a particular UUID.  The device must respond with information about the service(s) and device(s) that meet the request criteria, the format is similar to (and the key information the same as) the advertisments above.

The search requests are also sent over multicast UDP, the responses are also sent over UDP but just to the IP address and port that the request came from.

All messages are clear text and have a fairly simple, rigid format (parsing the search request just takes a handful of regular expressions).

###3.  Description.  
Technically this is much simpler than discovery.  By this time a control point knows that a device of interest is out there, and what services are offered.  It also has the device's Description URL.  The control point fires a standard http request to the URL and the device responds with a summary in XML format of

- the root device
- services offered by the root device, including URLs to retrieve a "Service Description", for Control and Eventing (see below)
- any embedded devices and services offered by them, in the same format as the root device and service(s)

The Service Description is a summary in XML format a bit like the interface description for a class.  Services have zero or more State Variables (variables) and Actions (methods).  State Variables have a data type and may have constraints on their values.  Actions have input arguments (with defined names and types) and output arguments (ditto).  For standard services defined by the UPnP forum the service description will be identical (except for XML formatting differences) across all devices offering the same service type and version.  Again service descriptions are retrieved via a standard http request to the relevant URL.

###4.  Control.   
Control points will issue a request over http to the Control URL for a service.  The request is a stream of XML (actually SOAP format) which contains the name of the action to be invoked and the arguments to use.  The device should invoke the action and send a http response with the output parameters in XML/SOAP.  If the invocation fails it sends an error message instead.

###5.  Eventing

Control points can keep track of the state of a device by subscribing to a service.  When this happens, the device will send the current values of all State Variables to the control point.  When any state variable value changes, for any reason, the device will send a message containing the new value.  All the messages are in XML format and sent over http.
  
Some state variables may change so frequently that they would flood the network with messages.  These variables need to be "moderated", which means update messages are only sent periodically (a few times a second) with the latest value if it has changed since the time the last message was sent.
  
Subscriptions can be renewed by sending a similar message to the original subscription.  If a subscription is not renewed it will eventually expire.

###6.  Presentation.  
This is an optional URL that a standard web browser can connect to to get information about, and potentially manipulate, the device through means other than UPnP. The specs are totally relaxed about whether and how this is used, I guess because it's not really UPnP.

____
##Networking protocols, Client / Server Processing and Threads

In summary, tapiola needs to do the following:

- Send multicast UDP messages (for advertisment and cancelling advertisments)  
- Act as a server for multicast UDP messages (for search requests)  
- Send non-multicast UDP messages (responding to search requests)  
- Act as a http server (for Discovery, Control, Presentation and handling state variable subscriptions / renewals / cancellations)  
- Act as a http client (sending event messages to control points when state variables change)  

And in a bit more detail, this is how it works..

Quite a lot of the code in the Device and RootDevice classes is fairly dull, either initialising the base classes with data, assembling messages to send, or parsing messages that are received.

### Discovery (all the UDP stuff)

For SSDP Discovery, three threads are set up

1. A sender thread whose job it is to pick up any outbound messages from a queue, and send them over UDP
2. A responder thread that listens for SSDP M-SEARCH messages from the network, parses them, creates the response and adds the response message(s) to the queue
3. An advertiser thread that assembles the initial NOTIFY messages and adds them to the queue, then sleeps for a bit and assembles and queues them again, and repeat..

### HTTP Server 

All HTTP serving is handled by WEBrick, so for example the device Description is a simple method that's attached to WEBrick via mount_proc, all it does is assemble the required XML and returns it to WEBrick to get pushed out.

For device Presentation, Service Description, Service Control and Event Subscription, all this is again HTTP traffic so handled by WEBrick.  A couple of methods derived from WEBrick servlets will parse the incoming URLs and work out which action (Description / Control / Subscription / Presentation) is required on which Device / Service, then call the appropriate class method for that Device or Service to action the request and create the response.

Note there are a couple of good reasons why I'm likely to move away from WEBrick in the future

1.  The UPnP specification requires that a client control point should not be sent any event notifications until it has received confirmation that its subscription has been accepted.  WEBrick does not provide a way of signalling when it has completed the send of its reponse back to a client, so it's possible for a subscription to be set up and (because of activity in another thread) an event sent for it immediately, before the confirmation response has been assembled and sent back - a kind of race condition.  Simply pausing all event notifications for a few milliseconds when processing a subscription might fix this, but I've chosen a solution that's either brilliant or tackier, depending on your point of view.  It's documented in the subscription code and involves overriding what's effectively a private method within WEBrick so isn't guaranteed to stay stable as WEBrick evolves.

2.  At some point I'd like to offer streaming / transcoding and WEBrick doesn't support chunked transfer encoding properly.

My HTTP server needs are fairly simple so something based on gserver ought to do.
### Events

For Eventing, a further two threads are needed. When a state variable changes, it can (as already mentioned) be moderated or unmoderated.  If the variable is unmoderated a change will immediately be pushed to an event queue.  

1. A moderator thread will periodically (every 0.01 seconds or so), check to see whether any moderated variables have changed and, if so, whether they are now eligible to be pushed to the event queue (either because the change is sufficiently large, or enough time has elapsed since the last time an Event was sent, depending on how the variable is defined).

2. A publisher thread will pick up any events on the queue, check to see which subscriptions are still valid, and publish the event to any subscribers. 

## Class and Object structure

This has been through several iterations and will probably change again.

Recall that a UPnP server may serve multiple clients simultaneously.  The simplest, but ugly, solution is to make all the "service" code single-threaded.  I don't think this is necessary.  WEBrick will (as far as I know) kick off each servlet in a separate thread, we could enforce single-threading but that seems a bit naff.  So Actions definitely need to be dynamic (one action instantiated per servlet call), ie they need to be created from a class.

Devices can either be instantiated or subclassed and a single instance of the subclass created for each device (most UPnP servers will only create one device).  Initially I thought they would have to be subclassed ie

```ruby
class myDevice < rootDevice
    def handlePresentation (req,res)
#      device-specific code about the "Presentation" process goes here, req and res are WEBrick requests and responses
    end
end
```
but then I realised a singleton method should work just as well

```ruby
myDevice = rootDevice.new(......)
def myDevice.handlePresentation (req,res)
#   code as before, but use self.x to access instance variable x
end
```

The same is true of Services, since there should be no device-specific code associated (directly) with a service, so it can just be instantiated.

```ruby
myService = Service.new(.....)
```

None of the code in the Device or Service classes (other than during initialisation), affects the data in those classes, it's effectively "read only" code.  So it should be thread-safe.

Actions need to be associated with methods on one or more non-UPnP object that represents the work taking place.  In most cases I expect applications to define a single class representing each UPnP service, with methods for each action, but this isn't essential.  What is important is that these methods can access the services State Variables and the most convenient way of doing this is to pass the @stateVariables instance variable for the service to the non-UPnP object when it is initialised.

Each of the methods that perform actions must take a hash of the input arguments and return a hash of the output ones.

This will probably make more sense if you review the code for the sample application.


## known limitations and bugs

These are things that I'm unlikely to bother to fix

- The code doesn't check that every device has at least one service
- No testing has been done on pathological cases where a root and embedded device offer the same service
- The code doesn't check that if a service is provided at version 2 (or later), earlier version(s) of the service are also provided.  In fact I'm not sure that it could handle this at present..
- The code assumes (but doesn't check) that only standard UPnP device and service types are being used - handling of deviceType and serviceId tags in the description XML would need to improve to fix this
