
module Meta

module Core

class Primitive
	def self.setDatabase(db)
		@@db = db
	end
end

class Track < Primitive
	attr_accessor :id, :filename, :pathname, :genre,  :artist, :composer, :albumArtist,
			:album, :track, :title, :recordingMbid, :discNumber, :discId, :sampleRate, :samples,
			:comment 
	def createFromFilename(file)
		path = Pathname.new(file)
		@pathname = path.dirname.to_s
		@filename = path.basename.to_s
		@id = @@db.addTrack(self)
	end
	def updateFromTag(tag,value)
		case tag.downcase
		when "artist"
			@artist = value
		when "composer"
			@composer = value
		when "album"
			@album = value
		when "genre"
			@genre = value
		when "tracknumber"
			@track = value
		when "title"
			@title = value
		when "discnumber"
			@discNumber = value
		when "comment"
			@comment = value
		end
	end
	def store
		@@db.updateTrack(self)
	end
	
end

class Tag < Primitive
	def initialize(track,tag,value)
		@@db.addTag(track,tag,value)
	end
end


class Disc < Primitive
	attr_reader :tracks, :pathname, :discNumber
	def initialize
		@tracks = Hash.new
	end
end	

end

end