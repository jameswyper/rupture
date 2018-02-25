
module Meta

module Core

class Primitive
	def self.setDatabase(db)
		@@db = db
	end
end

class Track < Primitive
	attr_reader :id, :filename, :pathname, :genre,  :artist, :composer, :album_artist,
			:album, :track, :title, :recordingMbid, :disc, :samplerate, :samples,
			:comment 
	def createfromFile
	end
end

class Tags < Primitive
	def initialize(track)
		@track = track
		@tags = Hash.new
	end
	def tag(type)
	end
	def store(type, value)
		@tags[type.downcase] = value
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