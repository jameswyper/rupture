
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
	def fetch(id)
		@@db.selectById(id,self)
	end
	def addWork(work)
		@@db.insertTrack2Work(@id,work)
	end
	
end

class Tag < Primitive
	def initialize(track,tag,value)
		@@db.addTag(track,tag,value)
	end
end


class Disc < Primitive
	attr_accessor :tracks, :pathname, :discNumber, :mbDiscID, :mbReleaseId, :id
	
	def initialize
		@tracks = Hash.new
	end
	
	def fetchTracks
		@@db.selectTracksForDisc(self)
	end
	
	def calcMbDiscID(offset)

		s = sprintf("%02X",1)
		s << sprintf("%02X",@tracks.size)
		
		lo = offset
		@tracks.keys.sort.each {|k| lo = lo + ((@tracks[k].samples * 75) / @tracks[k].sampleRate) }
		s << sprintf("%08X",lo)

		fo = offset
		@tracks.keys.sort.each do |k|
			s << sprintf("%08X",fo)
			fo = fo + ((@tracks[k].samples * 75) / @tracks[k].sampleRate)
		end
		if @tracks.size < 99 
			((@tracks.size + 1)..99).each  {|i| s << sprintf("%08X",0) }
		end
		t = ::Digest::SHA1.digest(s)
		b = ::Base64.strict_encode64(t).gsub('+','.').gsub('/','_').gsub('=','-')
		return b
	end
	
end	



end

end