require 'taglib'
=begin
#userframe = TagLib::ID3v2::UserTextIdentificationFrame.new("UserFrame",TagLib::String::UTF8)
userframe = TagLib::ID3v2::UserTextIdentificationFrame.new("UserFrame","Some User Text" ,TagLib::String::UTF8)
#userframe = TagLib::ID3v2::UserTextIdentificationFrame.new(TagLib::String::UTF8)
userframe.description = "UserFrame"
userframe.text = "Some User Text"
puts userframe.frame_id, userframe.to_string
=end
userframe = TagLib::ID3v2::UniqueFileIdentifierFrame.new("musicbrainz.org","abcde")
#userframe = TagLib::ID3v2::UserTextIdentificationFrame.new(TagLib::String::UTF8)
#userframe.description = "UserFrame"
#userframe.text = "Some User Text"
puts userframe.frame_id, userframe.owner,userframe.identifier