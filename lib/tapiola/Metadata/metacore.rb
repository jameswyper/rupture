
module Meta

module Core

class DBBase
	
	def self.openDatabase(f)
		@@db = SQLite3::Database.new(f)

		@@db.execute_batch("
		create table if not exists md_track (id integer, filename text, pathname text, genre text, artist text, composer text, album_artist text,
			album text, track integer, title text, mb_recording_id text, md_disc_id integer, samplerate integer, samples integer,
			discnumber integer, comment text);
		create table if not exists md_disc (id integer, mb_discID text, mb_release_id text, pathname text, discnumber integer);
		create table if not exists xx_id (name text, id int);
		create table if not exists md_track_tags (md_track_id integer, tag text, value text);
		create table if not exists md_track2work (track_id integer, work_mb_id text, performing_work_mb_id text, performing_work_sequence real);
		create table if not exists md_disc_not_on_mb(path text, discnumber integer, discID text, toc text);
		create unique index if not exists i_md_track1 on md_track(id);
		create index if not exists i_md_track2 on md_track(md_disc_id);
		create index if not exists i_md_track3 on md_track(pathname, discnumber);
		create index if not exists i_md_track2work1 on md_track2work(work_mb_id);
		vacuum;
		")

	end
	

	
	def self.getID( table)

		@@db.execute('create table if not exists xx_id (name text, id int)')

		r = @@db.execute('select id from xx_id where name  = ?', table)

		if  (r.size == 0)
			@@db.execute('insert into xx_id values (?,?)',table,1)
			return 1
		else
			@@db.execute('update xx_id set id = ? where name = ?', r[0][0] + 1, table)
			return (r[0][0] + 1)
		end
	end
	
	def addTrack(tr)
		i = DBBase.getID("md_track")
		@@db.execute('insert into 
				md_track(id , filename , 
						pathname ) values (?,?,?)',
			i,tr.filename,tr.pathname)
		return i
	end
	
	def updateTrack(tr)

		@@db.execute('update md_track set artist = ?, composer = ?, album_artist = ?, album = ?, 
				track = ?, title = ?,  mb_recording_id = ?, md_disc_id = ?, samplerate = ?, genre = ?,
				samples = ?, discnumber = ?, comment =? , filename = ?, pathname = ? where id = ?',
				tr.artist, tr.composer, tr.albumArtist, tr.album,tr.track, tr.title, tr.recordingMbid, tr.discId, 
				tr.sampleRate, tr.genre, tr.samples, (tr.discNumber || 0), tr.comment, tr.filename,tr.pathname,tr.id)
	end
			
	def selectById(id,tr)
		rows = @@db.execute('select artist,composer,album_artist,album,track,title,mb_recording_id,md_disc_id,samplerate,
				genre,samples,discnumber,comment,filename,pathname from md_track where id = ?',id)
		tr.artist = rows[0][0]
		tr.composer  = rows[0][1]
		tr.albumArtist = rows[0][2]
		tr.album = rows[0][3]
		tr.track = rows[0][4]
		tr.title = rows[0][5]
		tr.recordingMbid = rows[0][6]
		tr.discId = rows[0][7]
		tr.sampleRate = rows[0][8]
		tr.genre = rows[0][9]
		tr.samples = rows[0][10]
		tr.discNumber = rows[0][11]
		tr.comment = rows[0][12]
		tr.filename = rows[0][13]
		tr.pathname = rows[0][14]
		return tr
	end
	

	
	def selectTracksForDisc(disc)
		rows = @@db.execute('select id from md_track where md_disc_id = ?',disc.id)
		rows.each do |row|
			tr = self.selectById(row[0],Meta::Core::Track.new)
			tr.id = row[0]
			if (tr.track.is_a?(Numeric))
				disc.tracks[tr.track] = tr
			else
				disc.tracks[tr.track.split("/")[0].to_i] = tr
			end
		end
	end
	
	def insertTrack2Work(track,work)
		@@db.execute('insert into md_track2work (track_id,work_mb_id) values (?,?)',track,work)
	end

=begin
	def insertWork(work) 
		@db.execute('insert into mb_work (work_mb_id , title , type , key , composer,
		arranger,sequence, parent_mb_id) 
		values (?,?,?,?,?,?,?,?)',
		work.mbid, 
		work.title, work.type, work.key,
		(work.artists["composer"]) ? work.artists["composer"][0] .name: nil, 
		(work.artists["arranger"]) ? work.artists["arranger"][0] .name: nil ,
		work.parentSeq, work.parent)
	end	

	
	
	def selectDistinctWorkIDs
		rows = @db.execute('select distinct work_mb_id from md_track2work')
		w = Array.new
		rows.each {|r| w << r[0]}
		return w
	end
	
	def setPerformingWork(work,perfWork,sequence)
		@db.execute('update md_track2work set performing_work_mb_id = ?, performing_work_sequence = ? where work_mb_id = ?',perfWork,sequence,work)
	end
=end	
	def self.beginLUW
		@@db.transaction
	end
	
	def self.endLUW
		@@db.commit
	end
	
	def addTag(tr,t,v)
		@@db.execute("insert into md_track_tags(md_track_id, tag, value) values (?,?,?)",
		tr.id,t,v)
	end
	
end

class Track < DBBase
	attr_accessor :id, :filename, :pathname, :genre,  :artist, :composer, :albumArtist,
			:album, :track, :title, :recordingMbid, :discNumber, :discId, :sampleRate, :samples,
			:comment 
	def createFromFilename(file)
		path = Pathname.new(file)
		@pathname = path.dirname.to_s
		@filename = path.basename.to_s
		@id = addTrack(self)
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
		updateTrack(self)
	end
	def fetch(id)
		selectById(id,self)
	end
	def addWork(work)
		insertTrack2Work(@id,work)
	end
	
end

class Tag < DBBase
	def initialize(track,tag,value)
		addTag(track,tag,value)
	end
end


class Disc < DBBase
	attr_accessor :tracks, :pathname, :discNumber, :mbDiscID, :mbReleaseId, :id
	
	def initialize
		@tracks = Hash.new
	end
	
	def fetchTracks
		selectTracksForDisc(self)
	end
	
	
	def self.createDiscsFromTracks
		rows = @@db.execute('select distinct pathname,discnumber from md_track')
		rows.each do |row|
			id = DBBase.getID('md_disc')
			@@db.execute('insert into md_disc (id, pathname, discnumber) values (?,?,?)',id,row[0],row[1])
			@@db.execute('update md_track set md_disc_id = ? where pathname = ? and discnumber = ?',id,row[0],row[1])
		end
	end
	
	def self.fetchAllDiscs
		rows = @@db.execute('select id, pathname, discnumber,mb_discID, mb_release_id from md_disc')
		discs = Array.new
		rows.each do |row|
			disc = Meta::Core::Disc.new
			disc.id = row[0]
			disc.pathname = row[1]
			disc.discNumber = row[2]
			disc.mbDiscID = row[3]
			disc.mbReleaseId = row[4]
			#puts "fetched disc #{disc.id} #{disc.pathname} #{disc.discNumber}"
			disc.fetchTracks
			discs << disc
		end
		return discs
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

class Folder
	def initialize(t)
		@top = t
	end
	def scan
		count = 0
		total = 0
		eta = DateTime.now + 1
		files = Dir[@top+'/**/*.flac']
		total = files.size
		yield count, total, eta
		started = Time.now
		
		files.each do |file|
			stdout,stderr,status = Open3.capture3("metaflac --show-sample-rate --show-total-samples --export-tags-to=- #{Shellwords.escape(file)}")
			if status != 0 then raise RuntimeError, "metaflac failed #{stderr}" end
			
			
			tr = Meta::Core::Track.new
			tr.createFromFilename(file)
			
			tr.sampleRate = stdout.split("\n")[0].to_i
			tr.samples = stdout.split("\n")[1].to_i

			stdout.split("\n")[2..-1].each do |line|
				if (m = /(.*)=(.*)/.match(line))
					tag = m[1]
					value = m[2]
					Meta::Core::Tag.new(tr,tag,value)
					tr.updateFromTag(tag,value)
				end
			end
			tr.store
			count = count + 1
			if ((count % 100) == 0)
				now = Time.now
				rate = (count * 1.0) / (now - started)
				eta = started + (total / rate)
				perc = (count * 100.0) / total
#				yield "Stage 1: #{sprintf("%2.1f",perc)}% complete, ETC #{eta.strftime("%b-%d %H:%M.%S")}"
				yield count,total,eta
			end
		end
		yield count, total, Time.now
		Meta::Core::Disc.createDiscsFromTracks
	end
	def fetchDiscs
		return Meta::Core::Disc.fetchAllDiscs
	end
end

end #Core

end #Meta