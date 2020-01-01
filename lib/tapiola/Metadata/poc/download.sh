#!/bin/bash
srv="ftp://ftp.eu.metabrainz.org/pub/musicbrainz/data/fullexport/"


# get the "latest-is-xxxx" file and work out the value of xxxx
lis=`curl --list-only $srv | grep latest-is `
lat=${lis:10}

# download


curl ${srv}${lat}/mbdump.tar.bz2 -o /tmp/mb.tar.bz2
