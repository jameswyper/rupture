#!/usr/bin/env ruby

require 'sqlite3'
require 'fileutils'
require 'pathname'
require 'open3'
require 'shellwords'

class Database
	
	def initialize(f)
		@db = SQLite3::Database.new(f)
	end
	
	
	def resetTables

		@db.execute_batch("
		create table if not exists md_track (id integer, filename text, pathname text, genre text, artist text, composer text, album_artist text,
			album text, track integer, title text, mb_track_id integer, md_disc_id integer, samplerate integer, samples integer);
		create table if not exists md_disc (id integer, mb_discID text, mb_release_id text);
		create table if not exists xx_id (name text, id int);
		create table if not exists md_track_tags (md_track_id integer, tag text, value text);
		delete from md_track;
		delete from md_disc;
		delete from xx_id;
		")
		
	end
	
	
	def getID( table, num = 1)

		@db.execute('create table if not exists xx_id (name text, id int)')

		r = @db.execute('select id from xx_id where name  = ?', table)

		if  (r.size == 0)
			@db.execute('insert into xx_id values (?,?)',table,num)
			return 1
		else
			@db.execute('update xx_id set id = ? where name = ?', r[0][0] + num, table)
			return (r[0][0] + 1)
		end
	end
	
	def addTrack(file)
		i = getID("md_track")
		p = Pathname.new(file)
		d = p.dirname.to_s
		b = p.basename.to_s
		puts d,b,i
		@db.execute('insert into 
				md_track(id , filename , 
						pathname ) values (?,?,?)',
			i,b,d)
		return i
	end
	
	def addTag(i,t,v)
		@db.execute("insert into md_track_tags(md_track_id, tag, value) values (?,?,?)",
		i,t,v)
	end
	
	def updateTrackSamples(id,samplerate,samples)
		@db.execute("update md_track set samplerate = ?, samples = ? where id = ?",samplerate,samples,id)
	end
	
	def updateTrackfromTags(id)
	end
	def beginLUW
		@db.transaction
	end
	def endLUW
		@db.commit
	end
end

class TopFolder
	def initialize(t)
		@top = t
	end
	def scan(db)
		count = 0
		total = 0 
		files = Dir[@top+'/**/*.flac']
		total = files.size
		files.each do |file|
			stdout,stderr,status = Open3.capture3("metaflac --show-sample-rate --show-total-samples --export-tags-to=- #{Shellwords.escape(file)}")
			if status != 0 then raise RuntimeError, "metaflac failed #{stderr}" end
			tid = db.addTrack(file)
			sr = stdout.split("\n")[0].to_i
			ts = stdout.split("\n")[1].to_i
			#puts ("#{file} #{sr} #{ts}")
			stdout.split("\n")[2..-1].each do |line|
				m = /(.*)=(.*)/.match(line)
				tag = m[1]
				value = m[2]
				db.addTag(tid,tag,value)
			end
			
		end
	end
end

d = Database.new("test.db")
d.resetTables
x = TopFolder.new("/media/sf_Music/flac")
d.beginLUW
x.scan(d)
d.endLUW