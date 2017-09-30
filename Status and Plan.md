#Progress and Next Steps

September 2017

Discovery works

Device description works

Control has been very lightly tested

Eventing is not yet supported

Framework has been set up for HTTP services (description, presentation, control, eventing)

TODO

High


15. Events
- need to cater for resetting after events
- code header responses for sub / cancel sub / renew
- how to notify when socket response has been sent?


Medium

20.  Test_discovery - fix random bug on Lenovo
10. Sample application
12. Test suite based on Sample application including devices / services that don't validate
18. Extend range of state variables
7.  write code to serve icons
16. Add option to state variable to reset after eventing takes place
21.  Check discovery returns correct http headers and add to test

Low

17.  If an optional Action is called that hasn't been coded we should return error code 602 (optional not implemented) not 401 (invalid action) - this requires us to allow Service to maintain a list of optional, unimplemented actions

2. Logging (debug) - add File / method / object references to each statement [need to test]
4. Write method to start / stop all servers, including validation of device / service data
6.  allow PresentationURL to be overridden and not mounted
8.  allow logging object to be overridden
9.  URLBase needs to be a property of the root device not the device
11. Copyright notices

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

##Eventing - how it's going to work

Statevariable has value, changedSinceLastEvent (boolean - new), lastEventedValue, lastEventTime (new)

Statevariable has a class method for creating event XML, reset changedSinceLastEvent and lastEventTime if appropriate too

Service has set of subscriptions

method: createEvent 
gets the XML for a set of StateVariables
for each subscriber creates and (unless expired) pushes a http client request onto the main device event queue (need to push subscriber and message)

method: eventModerator
new thread
ticks along checking each state variable
if time > lastEventTime + rate, calls createEvent
sleep for a tiny bit, repeat (unless service is stopped)

Device has
method: processEventQueue
pick off each event, send http request (see threads2 code in sketches)
any failures, cancel that subscriber


Subscriptions
methods:
create
renew
cancel
event - to create the message.  check first if sub has expired, update subscription ID number
