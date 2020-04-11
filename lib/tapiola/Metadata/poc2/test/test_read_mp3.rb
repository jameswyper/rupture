require_relative '../tag.rb'

mp3 = GenericTag::Metadata.from_mp3("/media/james/karelia/Music/mp3/originals/rock/1988 - Tommy/[wedding present] - [tommy] - 03 - once more.mp3")

puts mp3.artist
puts mp3.title
puts mp3.album
