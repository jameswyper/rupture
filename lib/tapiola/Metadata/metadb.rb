require 'sqlite3'
require 'fileutils'
require 'pathname'
require 'open3'
require 'shellwords'
require 'digest'
require 'base64'
require_relative 'metacore'

module Meta

class Database
	
	def initialize(f)
		@db = SQLite3::Database.new(f)
		Core::Primitive.setDatabase(self)
	end
	
	
	def resetTables

		@db.execute_batch("
		drop table if exists md_track;
		drop table if exists md_disc;
		drop table if exists xx_id;
		drop table if exists md_track_tags;
		drop table if exists md_track2work;
		drop table if exists mb_work2work;
		drop table if exists mb_work;
		drop table if exists md_disc_not_on_mb;
		create table if not exists md_track (id integer, filename text, pathname text, genre text, artist text, composer text, album_artist text,
			album text, track integer, title text, mb_recording_id text, md_disc_id integer, samplerate integer, samples integer,
			discnumber integer, comment text);
		create table if not exists md_disc (id integer, mb_discID text, mb_release_id text, pathname text, discnumber integer);
		create table if not exists xx_id (name text, id int);
		create table if not exists md_track_tags (md_track_id integer, tag text, value text);
		create table if not exists md_track2work (track_id integer, work_mb_id text, performing_work_mb_id text, performing_work_sequence real);
		create table if not exists mb_work (work_mb_id text, title text, type text, key text, composer text, arranger text, sequence integer, parent_mb_id text);
		create table if not exists md_disc_not_on_mb(path text, discnumber integer, discID text, toc text);
		delete from md_track;
		delete from md_disc;
		delete from md_track_tags;
		delete from xx_id;
		delete from md_track2work;
		delete from mb_work;

		delete from md_disc_not_on_mb;
		create table if not exists mb_cache (request text, code integer, body text);
		
		drop index if exists i_mb_cache;
		create unique index i_mb_cache on mb_cache(request);
		")
		
	end
	
	
	def getID( table)

		@db.execute('create table if not exists xx_id (name text, id int)')

		r = @db.execute('select id from xx_id where name  = ?', table)

		if  (r.size == 0)
			@db.execute('insert into xx_id values (?,?)',table,1)
			return 1
		else
			@db.execute('update xx_id set id = ? where name = ?', r[0][0] + 1, table)
			return (r[0][0] + 1)
		end
	end
	
	def addTrack(tr)
		i = getID("md_track")
		@db.execute('insert into 
				md_track(id , filename , 
						pathname ) values (?,?,?)',
			i,tr.filename,tr.pathname)
		return i
	end
	
	def updateTrack(tr)

		@db.execute('update md_track set artist = ?, composer = ?, album_artist = ?, album = ?, 
				track = ?, title = ?,  mb_recording_id = ?, md_disc_id = ?, samplerate = ?, genre = ?,
				samples = ?, discnumber = ?, comment =? , filename = ?, pathname = ? where id = ?',
				tr.artist, tr.composer, tr.albumArtist, tr.album,tr.track, tr.title, tr.recordingMbid, tr.discId, 
				tr.sampleRate, tr.genre, tr.samples, (tr.discNumber || 0), tr.comment, tr.filename,tr.pathname,tr.id)
	end
			
	def selectById(id,tr)
		rows = @db.execute('select artist,composer,album_artist,album,track,title,mb_recording_id,md_disc_id,samplerate,
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
	
	def insertDiscsFromTracks
		rows = @db.execute('select distinct pathname,discnumber from md_track')
		rows.each do |row|
			id = getID('md_disc')
			@db.execute('insert into md_disc (id, pathname, discnumber) values (?,?,?)',id,row[0],row[1])
			@db.execute('update md_track set md_disc_id = ? where pathname = ? and discnumber = ?',id,row[0],row[1])
		end
	end
	
	def selectAllDiscs
		rows = @db.execute('select id, pathname, discnumber,mb_discID, mb_release_id from md_disc')
		discs = Array.new
		rows.each do |row|
			disc = Meta::Core::Disc.new
			disc.id = row[0]
			disc.pathname = row[1]
			disc.discNumber = row[2]
			disc.mbDiscID = row[3]
			disc.mbReleaseId = row[4]
			discs << disc
		end
		return discs
	end
	
	def selectTracksForDisc(disc)
		rows = @db.execute('select id from md_track where md_disc_id = ?',disc.id)
		rows.each do |row|
			tr = self.selectById(row[0],Meta::Core::Track.new)
			disc.tracks[tr.track.split("/")[0]] = tr
		end
	end
	
	def insertTrack2Work(track,work)
		@db.execute('insert into md_track2work (track_id,work_mb_id) values (?,?)',track,work)
	end
	
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
	
	def beginLUW
		@db.transaction
	end
	
	def endLUW
		@db.commit
	end
	
	def addTag(tr,t,v)
		@db.execute("insert into md_track_tags(md_track_id, tag, value) values (?,?,?)",
		tr.id,t,v)
	end
	
	def getCachedMbQuery(r)
		rows = @db.execute("select code, body from mb_cache where request = ?",r)
		if rows.size > 0
			code = rows[0][0]
			body = rows[0][1]
			return code, body
		else
			return nil, nil
		end
	end
	
	def storeCachedMbQuery(r,c,b)
		@db.execute("insert into mb_cache (request, code, body) values (?,?,?)", r,c,b)
	end
	
end

end
	