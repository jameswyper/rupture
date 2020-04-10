# requires sox and flac packages
rec empty.wav trim 0 1
flac -f empty.wav
cp empty.flac album1_track1.flac
while read line
do
  tmp=$(mktemp)
  fields=($line)
  f=${fields[0]}.flac
  a=${fields[@]:1}
  cat $a > $tmp
  metaflac $f --import-tags-from=$tmp
  rm -f $tmp
 done <<EOM
album1_track1 rec_album1 rec_album2
EOM

cp album1_track1.flac pic1.flac
metaflac pic1.flac --import-picture-from='3||||bbs1.jpg'
cp pic1.flac pic2.flac
metaflac pic2.flac --import-picture-from='4||||bbs2.jpg'
cp pic2.flac pic3.flac
metaflac pic3.flac --import-picture-from='3||||bbs2.jpg'
