#Progress and Next Steps

August 2017

Discovery works

Device description works

Framework has been set up for HTTP services (description, presentation, control, eventing)

TODO

1. Webrick Servlets - make existing do_method generic and call it

2. Logging (debug) - add File / method / object references to each statement [need to test]


4. Write method to start / stop all servers, including validation of device / service data



6.  allow PresentationURL to be overridden and not mounted
7.  write code to serve icons
8.  allow logging object to be overridden

9.  URLBase needs to be a property of the root device not the device


10. Sample application

11. Copyright notices

12. Test suite based on Sample application including devices / services that don't validate

13. State variable setup and attaching to services

14. Actions / argument setup

15. Events - moderator and subscriber threads need to be part of the root device.

(notes)

root will contain a list of Subscriptions and the event queue

an individual subscription will be associated with a service, have a sid and expiry time (may be nil)

state variable will be defined individually, then attached to a service, with type, allowedlist | range, default value, moderation type and value (iime / increment), previous event time or value 

action will be defined with name and list of arguments, (name, direction, retval, reference to state variable)

16. Add option to state variable to reset after eventing takes place

17.  If an optional Action is called that hasn't been coded we should return error code 602 (optional not implemented) not 401 (invalid action) - this requires us to allow Service to maintain a list of optional, unimplemented actions

##TEST PLAN

Setup:

Attempt to set up invalid devices (missing info, names break rules, etc).  Check validation exceptions thrown.

Discovery:

Set up SampleApp device.
Use socat to listen for (a) initial adverts, (b) periodic retries
Use socat to send different search requests.  Validate results.

Description:

Send Description request and validate result
Send malformed request (wrong url) 

Repeat Description test with device set up with explicit ip and port ie localhost

Presentation:

Confirm overridden presentation messages returned

Control

Call services, check results

Eventing

Subscribe, get events back


##Testing and Validation

I'm using gupnp-universal-cp (part of gupnp-tools) to test (socat has also been useful), via the command

strace -e trace=network -o tapiola.strace -s 1024 gupnp-universal-cp

it's possible to spy on traffic in and out of the gupnp program and from that I can confirm that the interaction between gupnp and Tapiola is working at the SSDP level (Tapiola's NOTIFY messages are being processed correctly, and it is sending the correct response to M-SEARCH messages), gupnp is also retrieving the root device description OK.  That's as far as I've got for now..



##Notes to self

"rdoc lib" to document everything
run a unit test just by running the __test.rb file
use REXML for starters to create / parse XML, switch the Nokogiri and/or builder if needed
