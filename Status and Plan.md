#Progress and Next Steps

October 2017

Everything is pretty much there.  Discovery, description, control and eventing have all been coded and tested, and there's a framework that allows you to provide your own Presentation handling code if you wish.
The major gaps are (a) only string and integer state variables have been catered for - there's just a lot of boilerplate to write for the rest and placeholders for the code are there, and (b) icons aren't properly supported or tested yet.  This will happen when I start to write the AV server.

Test scripts using MiniTest have been written, occasionally the discovery one will fail with address already in use, just re-run it.


TODO

High


15. Events
- need to cater for resetting after events


Medium

20.  Test_discovery - fix random bug on Lenovo VM
10. Sample application
12. Test suite based on Sample application including devices / services that don't validate
18. Extend range of state variables
7.  write code to serve icons
16. Add option to state variable to reset after eventing takes place
21.  Check description returns correct http headers and add to test
23.  Replace Webrick

Low

17.  If an optional Action is called that hasn't been coded we should return error code 602 (optional not implemented) not 401 (invalid action) - this requires us to allow Service to maintain a list of optional, unimplemented actions

4. Write method to start / stop all servers, including validation of device / service data
6.  allow PresentationURL to be overridden and not mounted
8.  allow logging object to be overridden
9.  URLBase needs to be a property of the root device not the device

22. Gemspec and test install on a clean VM.  Ideally at least one non-Ubuntu one too.

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


AV work

extend classes to include audioItem, musicTrack, album and musicAlbum
implement browse

create method(s) to add containers and items
containerupdateID processing and eventing

implement getSortCapabilities
implement search
implement getSearchCapabilities

create SQLite database from metadata
create AV classes from database

server for the actual media files
icons??

