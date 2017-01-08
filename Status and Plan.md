#Progress and Next Steps

January 2017

Discovery works
Device description works
Framework has been set up for HTTP services (description, presentation, control, eventing)

TODO

Webrick Servlets - make existing do_method generic and call it
Logging (debug) - add File / method / object references to each statement


Replace device properties with symbols 

Write method to start / stop all servers, including validation of device / service data

Check out arguments list as hash, consider using symbols for that

Sample application

Copyright notices

Test suite based on Sample application including devices / services that don't validate

State variable setup and attaching to services
Actions / argument setup


Events - moderator and subscriber threads need to be part of the root device.

root will contain a list of Subscriptions and the event queue

an individual subscription will be associated with a service, have a sid and expiry time (may be nil)

state variable will be defined individually, then attached to a service, with type, allowedlist | range, default value, moderation type and value (iime / increment), previous event time or value 

action will be defined with name and list of arguments, (name, direction, retval, reference to state variable)









Notes to self

"rdoc lib" to document everything
run a unit test just by running the __test.rb file


