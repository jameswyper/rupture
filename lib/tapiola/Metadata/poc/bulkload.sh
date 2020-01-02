#!/bin/bash


# lbzip2 needs to be installed!

dlfile="$1"/mb.tar.bz2

database="$1"/mb.db

function load {
srcfile=$1
table=$2
columns=$3
sourcecols=$4
u_index=$5
index=$6

# set up a file to hold the SQLite commands and write the commands to it
# create the table with the required columns
# bulkload via piped input

cmdfile=`mktemp`
echo ".mode tabs " > $cmdfile
echo "create table $table ($columns);" >> $cmdfile
echo ".import /dev/stdin $table" >> $cmdfile

# create unique indexes

for i in $u_index; do
  echo "create unique index x${table}${i} on $table ( ${i} );" >> $cmdfile
done

# create other indexes

for i in $index; do
  echo "create index x${table}${i} on $table ( ${i} );" >> $cmdfile
done

# set up the boilerplate code for the awk script that will reduce the columns on the file to the ones we want to load

awk1="BEGIN {FS=\"\t\";OFS=\"\t\";} {print "
awk2="}"

# pipeline to
# 1. extract the data to be loaded from our tar archive
# 2. reduce the columns in the data to the ones we want
# 3. double up any quotes and enclose the complete field in quotes when we do this (sed hack stolen from stackoverflow)
# 4. pipe the result to SQLite to run against our create table / load / create index script

echo `date` - processing $table
tar -I lbzip2 -xOf $dlfile --occurrence mbdump/$srcfile  | awk "${awk1}${sourcecols}${awk2}" | sed 's/"/""/g;s/[^\t]*/"&"/g' | sqlite3 $database ".read $cmdfile"

# the source files have \N to represent null values; we need to fix this for every column in the table
 
for col in `sqlite3 $database "pragma table_info ($table);" | awk -F '|' '{print $2}'`  
do sqlite3 $database "update $table set $col = NULL where $col = '\N';"
done


# clean up

rm -f $cmdfile

}

rm -f $database


load artist artists 'id integer primary key, gid text, name text, sort_name text' '$1,$2,$3,$4' id gid
load artist_credit_name artist_credit_names 'artist_credit_id integer, position integer, artist_id integer, name text, join_phrase text' '$1,$2,$3,$4,$5'
load artist_credit  artist_credits 'id integer primary key, name text' '$1,$2' id
load artist_alias artist_aliases 'id integer primary key, artist_id integer, name text, locale text, sort_name text' '$1,$2,$3,$4,$8' id artist_id
load recording recordings 'id integer primary key, gid text, name text, artist_credit_id integer' '$1,$2,$3,$4' id "artist_credit_id gid"
load track tracks 'id integer primary key, gid text, recording_id integer, medium_id integer, position integer, number integer, name text, artist_credit_id integer' '$1,$2,$3,$4,$5,$6,$7,$8' id 'recording_id medium_id artist_credit_id'
load medium media 'id integer primary key,release_id integer, position integer, media_format_id integer, name text' '$1,$2,$3,$4,$5' id 'release_id media_format_id'
load medium_format media_formats 'id integer primary key, name text' '$1,$2' id
load medium_cdtoc medium_cdtocs 'id integer primary key, medium_id integer, cdtoc_id integer' '$1,$2,$3' id 'medium_id cdtoc_id'
load cdtoc cdtocs 'id integer primary key, discid text, freedb_id text, track_count integer, leadout_offset integer, track_offset text' '$1,$2,$3,$4,$5,$6'  id discid
load release  releases 'id integer primary key, gid text, name text, artist_credit_id integer, release_group_id integer' '$1,$2,$3,$4,$5' id 'gid artist_credit_id release_group_id'
load release_group  release_groups 'id integer primary key, gid text, name text, artist_credit_id integer' '$1,$2,$3,$4' id 
load work_alias work_aliases 'id integer primary key, work_id integer, name text, locale text, work_alias_type_id integer, sort_name text' '$1,$2,$3,$4,$7,$8' id 'work_id work_alias_type_id'
load work works 'id integer primary key, gid text,  name text, work_type_id integer' '$1,$2,$3,$4' id "work_type_id gid"
load work_type work_types 'id integer primary key, name text' '$1,$2' id
load link links 'id integer primary key, link_type_id integer' '$1,$2' id
load l_artist_work l_artist_works 'id integer primary key, link_id integer, artist_id integer, work_id integer' '$1,$2,$3,$4' id 'link_id artist_id work_id'
load l_work_work  l_work_works 'id integer primary key, link_id, work0_id integer, work1_id integer, link_order integer' '$1,$2,$3,$4,$6' id 'link_id work0_id work1_id'
load link_type  link_types 'id integer primary key, link_type_id integer, child_order integer, gid text, entity_type0 text, entity_type1 text, name text, description text, link_phrase text, reverse_link_phrase text, long_link_phrase text' '$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11' id link_type_id
load l_release_group_url l_release_group_urls 'id integer primary key, link_id integer, release_group_id integer, url_id integer,link_order integer' '$1,$2,$3,$4,$6' id 'link_id release_group_id'
load l_release_url l_release_urls 'id integer primary key, link_id integer, release_id integer, url_id integer,link_order integer' '$1,$2,$3,$4,$7' id 'link_id release_id'
load l_recording_work l_recording_works 'id integer primary key, link_id integer, recording_id integer, work_id integer' '$1,$2,$3,$4' id 'recording_id'
load url urls 'id integer primary key, url text' '$1,$3' id
load link_attribute link_attributes 'link_id integer, link_attribute_type_id integer' '$1,$2'
load link_attribute_type link_attribute_types 'id integer primary key, parent_id integer, root_id integer, child_order integer, gid text, name text, description text' '$1,$2,$3,$4,$5,$6,$7' id

load work_attribute work_attributes 'id integer primary key,work_id integer, work_attribute_type_id integer, work_attribute_type_allowed_value_id integer,work_attribute_text text' '$1,$2,$3,$4,$5' id
load work_attribute_type_allowed_value  work_attribute_type_allowed_values 'id integer primary key, work_attribute_type_id integer, value text' '$1,$2,$3' id
load work_attribute_type work_attribute_types 'id integer primary key, name text, parent integer, gid text' '$1,$2,$5,$8' id 'parent'

# not doing these next two as they are in a separate download and we can live without them
#load release_meta releases_meta 'id integer primary key, amazon_asin text, amazon_store text, coverart_presence text' '$1,$4,$5,$6' id 
#load release_coverart releases_coverart 'id integer primary key, url text' '$1,$3' id

echo `date` - all loads complete
# create some extra indexes that the function couldn't handle

sqlite3 $database "create unique index xacp on artist_credit_names (artist_credit_id, position);"
sqlite3 $database "create index xac on artist_credit_names (artist_credit_id);"
sqlite3 $database "create index xart on artist_credit_names (artist_id);"
sqlite3 $database "create index xlinka1 on link_attributes (link_id);"
sqlite3 $database "create index xlinka2 on link_attributes (link_attribute_type_id);"

# materialise the parent/child view for works (performance is poor otherwise)

#sqlite3 $database "create view parent_works as select work0_id as parent_id, work1_id as id from l_work_work w, links l, link_types lt where w.link_id = l.id and l.link_type_id = lt.id and lt.name = 'parts' and lt.entity_type0 = 'work' and lt.entity_type1 = 'work';"
#sqlite3 $database "create table worksp as select w.* , p.parent_id from works w left outer join parent_works p on w.id = p.id;"
#sqlite3 $database "create index xworkspid on worksp(id);"
#sqlite3 $database "create index xworkspparentid on worksp(parent_id);"

sqlite3 $database "create table files (id integer primary key, disc_id integer, basename text, pathname test, track integer, disc integer);"
sqlite3 $database "create unique index xfileid on files(id); create index xfilediscid on files(disc_id);"
sqlite3 $database "create table discs (id integer primary key, pathname text, number integer)"
sqlite3 $database "create unique index xdiscid on discs(id);"
sqlite3 $database "create table tags (id integer primary key, file_id integer, name text, value text);"
sqlite3 $database "create unique index xtagid on tags(id); create index xtagfileid on tags(file_id);"

sqlite3 $database "create table medium_offset_candidates (id integer primary key, medium_id integer, disc_id integer)"
sqlite3 $database "create table medium_acoust_candidates (id integer primary key, medium_id integer, disc_id integer)"
#sqlite3 $database ""
#sqlite3 $database ""


sqlite3 $database "analyze;"

echo `date` - extra indexes complete

ruby ./offsetfix.rb "$1"/mb.db

echo `date` - discIds fixed up
