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
		create table if not exists md_disc (id integer, mb_discID text, mb_release_id text);
		create table if not exists xx_id (name text, id int);
		create table if not exists md_track_tags (md_track_id integer, tag text, value text);
		create table if not exists md_track2work (track_id integer, work_mb_id text, performing_work_mb_id text, performing_work_sequence real);
		create table if not exists mb_work (work_mb_id text, title text, type text, key text, composer text, arranger text);
		create table if not exists mb_work2work (work_mb_id text, sequence integer, parent_work_mb_id text);
		create table if not exists md_disc_not_on_mb(path text, discnumber integer, discID text, toc text);
		delete from md_track;
		delete from md_disc;
		delete from md_track_tags;
		delete from xx_id;
		delete from md_track2work;
		delete from mb_work;
		delete from mb_work2work;
		delete from md_disc_not_on_mb;
		create table if not exists mb_cache (request text, code text, body text);
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
				samples = ?, discnumber = ?, comment =? where id = ?',tr.artist, tr.composer, tr.albumArtist, tr.album,
				tr.track, tr.title, tr.recordingMbid, tr.discId, tr.sampleRate, tr.genre, tr.samples, (tr.discNumber || 0), tr.comment, tr.id)
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
		if rows
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
	