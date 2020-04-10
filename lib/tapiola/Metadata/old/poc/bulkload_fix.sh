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

load link_attribute_type link_attribute_types 'id integer primary key, parent_id integer, root_id integer, child_order integer, gid text, name text, description text' '$1,$2,$3,$4,$5,$6,$7' id

echo `date` - all loads complete
# create some extra indexes that the function couldn't handle


ruby ./offsetfix.rb "$1"/mb.db

echo `date` - discIds fixed up
