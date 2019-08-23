Okay, so this escalated quickly.. it was only ever meant to be a minor distraction

Metascan is (or will be, when it's finished) a tool to link collections of FLAC files to the metadata held on MusicBrainz.
It was written to help organise my large collection of files ripped from the original CDs, and in particular to provide a "work"
tag which the UPnP server can (when THAT's finally written) use so that if, for example, I want to play Beethoven's 7th symphony
I can navigate to the work and select the performance I want rather than going in on artist (all my files are tagged by performer
not composer).

Metascan is meant to be used iteratively, and on a collection that gets larger over time.  It works by attempting to match a set of music
files to MusicBrainz Releases (effectively albums).  Sometimes the match is exact, in other words a collection of 12 files corresponds 
to a single release.  At other times there may be multiple matching releases (e.g. if the album was re-released as part of a box set) or
not all files match up.  When this happens the script will write out the candidate matches to a tab-separated file which can be edited 
(either with a text editor or in Excel) to indicate which if any is the "correct" match and fed back into the next run.

The script uses two public web services:  MusicBrainz and AcoustID.  Both require rate-limiting and it's bad form to keep calling with the
same queries so all queries and responses are cached in SQLite databases.  That makes subsequent runs much faster than the first one.  
It's possible to download and maintain your own MusicBrainz server (in which case rate-limiting the calls to it isn't necessary) so I've
allowed a different URL for the MusicBrainz service as an option.

The script works on the assumption that your music files are grouped into directories, with each directory containing either
-  All the tracks from one (and only one) album
-  All the tracks from one disc of a multi-disc album (and only one album)
-  All the tracks from more than one disc of a multi-disc album, with the DISCNUMBER tag set so that discs are grouped together 
(ie same tag value for all tracks on the disc).  Provided that these tag values are unique across discs they don't have to be 1, 2 or
whatever.

A Release and Medium combination in MusicBrainz is equivalent to a disc of an album (with the proviso that multiple Releases may exist for
the same album)

The only required parameter for the script is the top level of the directory tree to scan for music files. 
After reading some configuration data (default location ~/.cache/metascan) the script will

1.  Scan the directory recursively for music files and collect tag and duration data from them.
1.  Sort the results by directory and discnumber (note the ALBUM tag in the metadata is not used here) so that we process a disc at a time.
1.  Check to see if there's a matching entry in the edited candidates file fed into the run and if so, assign the Release/Medium from there.
1.  Otherwise, use the lengths of the tracks in the disc to create a MusicBrainz 'discid' which can be used to look up the Release/Medium
from MusicBrainz.  Unfortunately part of what forms the discid is an offset of the number of sectors on the CD before the first track.  This 
can be almost any value; in practice it is *usually* 150 (two seconds).  But to to maximise the chances of a successful lookup the script calls
MusicBrainz with a few different offsets (you can change which ones are used) unless and until it gets a hit.
1.  The discid lookup may return one release (ideal) or more than one.  If there's more than one the information is written to a candidates file
so that the choice of the correct release can be fed into the next run.
1.  Not every Release on MusicBrainz has a discid.  For those that don't, the fallback is to create an acoustic fingerprint of the contents
of the music file and check for a match on the AcoustID site (which will return matching Releases from MusicBrainz).  AcoustID works at the
track (not disc) level, so we collect the results for all tracks on the disc and find the release that "best" matches the set of tracks (a popular
track could appear on its original album, the artist's "Greatest Hits" album, or possibly any number of compilations so we have to 
look at the complete set of tracks to find the best fit ie the release with the same number of tracks as we've processed, and with the highest number
of tracks matching up).  AcoustID is less reliable for classical music because the fingerprints for two performances of the same work will often 
be near-identical (same notes, same instruments).
1.  As with the discid method this may return more than one candidate Release/Medium combination in which case the choices are written out to
file.
1.  And that's as far as I've got so far - we don't yet write the tags back although this should be almost trivial.

TODO

Complete the workflow for assigning choices from previous runs
Test on my complete music collection (classical only so far)
Actually write the tags back
mp3 support

CONFIG

sudo mount -t cifs \\\\192.168.0.99\\james\\Music /media/Music/ -o user=james,pass=xxx