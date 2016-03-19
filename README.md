# rupture
Will eventually be a UPnP music server, in Ruby

Why do this?

I've run a music server at home for many years, and looked at several different programs.  For me the key requirements are

- Ability to handle a very large collection (~30,000 tracks)
- Ability to customise the container hierarchy those tracks are put into, for ease of navigation (with that much music an "All Artists" view isn't going to be very helpful) - including support for the Composer tag as I listen to a lot of Classical
- Needs to run on my Linux server
 
Mediatomb was, for a while, perfect but it appears to be abandoned and no longer compiles on newer releases of Ubuntu.  And C/C++ feels too low-level for this kind of application.  Python-coherence won't build on my machine and is also unmaintained.  Various existing Ruby UPnP implementations are either obsolete, unfinished, undocumented and/or complicated (requiring Eventmachine for a low use server)?  I tried a DBus interface to Rygel but that couldn't handle the volumes required and diagnosis requires me to learn a whole new language and build system.. Minimserver is the closest match to my needs right now, although it's closed source (but free as in beer).

For now I just want something that will serve mp3 files but hopefully this can be extended in future to allow for transcoding and other content types (video / photos).

I'm going to split the logic up into (at least) two programs - something to create the virtual container hierarchy from a set of mp3 tags (reusing a lot from my failed attempt at doing the same with rygel) and store that in an SQLite database, and something to read that database and serve the hierarchy over UPnP.

The rough plan of attack is

- create some generic classes for UPnP devices and services
- create a server that will handle SSDP discovery & advertisement (basically a simple, threaded UDP server)
- extend this to add generic handling of Description, Control, Eventing and (maybe) Presentation
- start specialising the classes to handle serving audio
- create the virtual container hierarchy
- get the specialised classes to use that..
