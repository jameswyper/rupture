#Progress and Next Steps

January 2017

Discovery works
Device description works
Framework has been set up for HTTP services (description, presentation, control, eventing)

TODO

1. Webrick Servlets - make existing do_method generic and call it

2. Logging (debug) - add File / method / object references to each statement

3. Replace device properties with symbols 

4. Write method to start / stop all servers, including validation of device / service data

5. Check out arguments list as hash, use symbols for that

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

TEST PLAN

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




Notes to self

"rdoc lib" to document everything
run a unit test just by running the __test.rb file


