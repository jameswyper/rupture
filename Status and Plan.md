#Progress and Next Steps

December 2016

The basic UPnP objects are defined
Code to advertise and create responses to search requests during Discovery is written (needs tiny bit of FIXME)
Need to refactor / move into Base class the code that does the networking

Re-read and fix the code that creates the Description response

Think about how best to put this in Webrick setup

UPnPBase will create a Webrick instance called webserver

When UPnPBase is started (not just initialised) this webserver will be started, and it will terminate on INT via a trap - the same one that will shut down the discovery stuff
When UPnPBase is initialised a procedure will be attached to the webserver to call the description-handling code


