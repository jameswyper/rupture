#!/usr/bin/env ruby

require 'sqlite3'
require 'fileutils'
require 'pathname'
require 'open3'
require 'shellwords'
require 'digest'
require 'base64'
require 'rexml/document'
require 'httpclient'

$stdout.sync = true

class Database
	
	def initialize(f)
		@db = SQLite3::Database.new(f)
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
	
	def addTrack(file)
		i = getID("md_track")
		p = Pathname.new(file)
		d = p.dirname.to_s
		b = p.basename.to_s
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
	
	def updateTrackFromTags(id)
		def getRow(rows,tag)
			s = rows.select{|r| (r[0].downcase == tag)}
			if s.size > 0
				return s[0][1]
			else
				return nil
			end
		end
		rows = @db.execute('select tag, value from md_track_tags where md_track_id = ?',id)
		artist = getRow(rows,"artist")
		composer = getRow(rows,"composer")
		album = getRow(rows,"album")
		genre = getRow(rows,"genre")
		track = getRow(rows,"tracknumber")
		title = getRow(rows,"title")
		discnum = getRow(rows,"discnumber")
		comment = getRow(rows,"comment")
		@db.execute('update md_track set artist = ?, album = ?, composer = ?, genre = ?, track = ?, title = ?, discnumber = ?, comment = ? where id = ?',
			artist,album,composer,genre,track,title,discnum, comment,id)
	end
	
	def beginLUW
		@db.transaction
	end
	def endLUW
		@db.commit
	end
	
	
	def getDiscs
		fs = Hash.new
		rows = @db.execute('select pathname, discnumber, sum( (samples * 75) / samplerate) , min(track), max(track) from md_track group by pathname, discnumber')
		rows.each do |r| 
			if fs[r[0]] == nil
				fs[r[0]] = [r[1..4].dup]
			else
				fs[r[0]] << r[1..4].dup
			end
		end
		#fs.each do |k,v|
			#v.each {|w| puts "#{k} disc #{w[0]} tracks #{w[2]} to #{w[3]} 75ths #{w[1]}" }
		#end
		return fs
	end
	
	
	def calcMbDiscID(path,disc,offset = 150)
		#get all tracks for path and disc
		#calculate ID
		# store on separate table
		# link to table for all tracks
		
		if (disc != nil)
			rows =  @db.execute('select id, track, ((samples * 75) / samplerate) from md_track where pathname = ? and discnumber = ? order by track',
				path, disc)
		else
			rows =  @db.execute('select id, track, ((samples * 75) / samplerate) from md_track where pathname = ? and discnumber is null order by track',
				path)
		end
		
		toc = "1"

		
		s = sprintf("%02X",1)
		s << sprintf("%02X",rows.size)
		
		toc << "+#{rows.size}"

		
		lo = offset
		rows.each do |r| 
			lo = lo + r[2]
		end
		s << sprintf("%08X",lo)
		toc << "+#{lo}"
		fo = offset
		rows.each do |r|
			s << sprintf("%08X",fo)
			toc << "+#{fo}"
			fo = fo + r[2]
		end
		if rows.size < 99 
			((rows.size + 1)..99).each  {|r| s << sprintf("%08X",0) }
		end
		#puts "#{path} #{offset} #{toc}"
		t = ::Digest::SHA1.digest(s)
		b = ::Base64.strict_encode64(t).gsub('+','.').gsub('/','_').gsub('=','-')
		return b, toc
	end
	
	def storeMbDiscID(id,path,disc)
		i = getID("md_disc")
		@db.execute('insert into md_disc (id, mb_discID) values (?, ?)',i,id)
		if disc != nil 
			@db.execute('update md_track set md_disc_id = ? where pathname = ? and discnumber = ?',i,path,disc)
		else
			@db.execute('update md_track set md_disc_id = ? where pathname = ? and discnumber is null',i,path)
		end
	end	

	def getAllMbDiscIDs
		return @db.execute('select distinct a.mb_discID, a.id, b.pathname from md_disc a, md_track b where a.id = b.md_disc_id')
	end
	
	def getCachedMbQuery(r)
		return @db.execute("select code, body from mb_cache where request = ?",r)
	end
	
	def storeCachedMbQuery(r,c,b)
		@db.execute("insert into mb_cache (request, code, body) values (?,?,?)", r,c,b)
	end

	def getTracksForDiscID(did)
		return @db.execute("select track, samples, samplerate, title, a.id from md_track a, md_disc b where b.id = a.md_disc_id and b.mb_discID = ? order by track",did)
	end

	def storeWorkForTrack(t,w)
		@db.execute("insert into md_track2work (track_id, work_mb_id) values (?,?)",t,w)
	end

	def storeRecordingForTrack(t,w)
		@db.execute("update md_track set mb_recording_id = ? where id = ?",w,t)
	end
	
	def storeNoMBdisc(path,disc,id,toc)
		@db.execute("insert into md_disc_not_on_mb (path, discnumber, discID, toc) values(?,?,?,?)",path,disc,id,toc)
	end

	def getDistinctWorks
		return @db.execute("select distinct work_mb_id from md_track2work")
	end
	
	def storeWorkParent(work,parent,sequence)
		rows = @db.execute("select work_mb_id from mb_work2work where work_mb_id = ?", work)
		if (rows == nil) || (rows.size == 0)
			@db.execute("insert into mb_work2work (work_mb_id, sequence, parent_work_mb_id) values (?,?,?)",work,sequence,parent)
		end
	end
	
	def storeWorkDetails(id,title,type,key,comp,arr)
		@db.execute("insert into mb_work (work_mb_id, title, type,key, composer, arranger) values (?,?,?,?,?,?)", id,title,type,key,comp,arr)
	end
	
	def storePerformingWork(track, work, seq)
		@db.execute("update md_track2work set performing_work_mb_id = ?, performing_work_sequence = ? where track_id = ?",work,seq,track)
	end
	
	def getAllTracksWithWorks
		return @db.execute("select a.track_id, a.work_mb_id, b.title from md_track2work a, md_track b where b.id = a.track_id")
	end
	
	def getWorkDetails(w)
		return @db.execute("select type, key,title from mb_work where work_mb_id = ?",w)[0]
	end
	
	def getParentWork(w)
		rows = @db.execute("select parent_work_mb_id, sequence from mb_work2work where work_mb_id = ?",w)
		if (rows != nil)
			if rows.size > 0
				return rows[0]
			else
				return nil
			end
		else
			return nil
		end
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
			#puts stdout
			stdout.split("\n")[2..-1].each do |line|
				if (m = /(.*)=(.*)/.match(line))
					tag = m[1]
					value = m[2]
					db.addTag(tid,tag,value)
				#else
					#puts "Odd line found at #{count} #{file} line is #{line}"
				end
			end
			db.updateTrackFromTags(tid)
			db.updateTrackSamples(tid,sr,ts)
			count = count + 1
			if ((count % 100) == 0)
				puts "#{count} files processed out of #{total}"
			end
		end
	end
end


class MusicBrainz
	
	def initialize(server,db)
		@server = server
		@db = db
	end
	
	def mbRequest(service)
		c = HTTPClient.new
		c.receive_timeout = 300
		return  c.request('GET',"http://#{@server}/#{service}",
			:header => {'user-agent' => 'jrwyper@yahoo.co.uk'})
	end
	
	def mbCachedRequest(service)
		if @db
			r = @db.getCachedMbQuery(service)
			if r.size > 0
				return r[0][0], r[0][1]
			else
				r = mbRequest(service)
				@db.storeCachedMbQuery(service,r.code,r.body)
				return r.code.to_s, r.body
			end
		else
			r = mbRequest(service)
			return r.code.to_s, r.body
		end
	end
	
	def checkDiscID(discID)
		c, r = mbCachedRequest("/ws/2/discid/#{discID}?inc=recordings")
		return c
	end
	
	def getDiscByID(discID)
		c, r = mbCachedRequest("/ws/2/discid/#{discID}?inc=recordings")
		if c == "200"
			x = REXML::Document.new(r)
			x.elements.each("//metadata/disc/release-list") do |rl|
				s = rl.attributes["count"]
				x.elements.each("/metadata/disc/release-list/release") do |rel|
					#puts "release #{rel.attributes["id"]}"
					rel.elements.each("medium-list/medium") do |med|
						#puts "position #{med.elements["position"].text}"
						match = false
						med.elements.each("disc-list/disc") do |di|
							if di.attributes["id"] == discID
								match = true
							end
						end
						if (match)
							mbtr = Array.new
							#puts "medium #{med}"
#							putsh "medels #{med.elements.to_a("track-list/track").to_s}"
							med.elements.each("track-list/track") do |tr|
								#puts "in tr loop"
								pos = tr.elements["position"].text.to_i
								num = tr.elements["number"].text.to_i
								if tr.elements["length"]
									len = tr.elements["length"].text.to_i 
								else
									len = 0
								end
								mbtr << [num,pos,len]
								#puts "track #{num} #{pos}"
								tr.elements.each("recording") do |rec|
									#puts "recording #{rec.attributes["id"]}"
									rt = rec.elements["title"].text
									mbtr[-1][3] = rt
									w = 	getWorkForRecording(rec.attributes["id"])
									if (w.size > 1)
										#puts "Hmmm, #{rec.attributes["id"]} has more than one work"
									end
									mbtr[-1][4] = w
									mbtr[-1][5] = rec.attributes["id"]
									#w.each {|i| getWorkForWork(i)}
								end
								
							end							
							mbtr.sort! {|a,b|  a[0] <=> b[0] }
							dbtr = @db.getTracksForDiscID(discID)
							if mbtr.size != dbtr.size
								puts "OOPS: number of tracks doesn't match #{discID}"
							end
							mbtr.each_index do |i|
								dlen = (1000 * dbtr[i][1] ) / dbtr[i][2]
								#puts "dbtrack #{dbtr[i][0]} | num #{mbtr[i][0]} pos #{mbtr[i][1]} | db #{dbtr[i][3]} mb #{mbtr[i][3]} *** db #{dlen} vs mb #{mbtr[i][2]}"
								ch = (mbtr[i][2] * 1.0 )/ dlen
								if (ch > 1.04) || (ch < 0.96)
									puts "Length mismatch (mb:db) on #{mbtr[i][1]} #{dbtr[i][3]} #{mbtr[i][2]}/#{dlen}"
								end
								@db.storeRecordingForTrack(dbtr[i][4],mbtr[i][5])
								mbtr[i][4].each { |wk| @db.storeWorkForTrack(dbtr[i][4], wk) }
							end
						else
							#puts "Found non-matching medium (probably not a worry)"
						end
					end
				end
			end
		end
	end
	
	def getWorkForRecording(id)
		aw = Array.new
		c, r = mbCachedRequest("/ws/2/recording/#{id}?inc=work-rels")
		x = REXML::Document.new(r)
		x.elements.each("/metadata/recording/relation-list/relation/work") do |w|
			wid = w.attributes["id"]
			#puts "#{w.elements["title"].text} id=#{wid}"
			aw << wid
		end
		return aw
	end
	
	def getWorkAttributes(id)
		c, r = mbCachedRequest("/ws/2/work/#{id}?inc=aliases")
		x = REXML::Document.new(r)
		#puts r
		type = x.elements["/metadata/work"].attributes["type"]
		title = x.elements["/metadata/work/title"].text
		y = x.elements["/metadata/work/attribute-list/"] 
		#puts "y=#{y}"
		key = nil
		if (y)
			y.each do |a|
				if a.attributes["type"] == "Key"
					key = a.text
				end
			end
		end
		y = x.elements["/metadata/work/alias-list/alias"]
		if (y)
			y.each do |a|
				if (y.attributes["type"] =="Work name") && (y.attributes["locale"] == "en")
					puts "Alias: #{y.text}"
				end
			end
		end
		return title, type, key
	end
	
	def getParentWork(id)
		c , r = mbCachedRequest("/ws/2/work/#{id}?inc=work-rels")
		x = REXML::Document.new(r)
		x.elements.each("/metadata/work/relation-list/relation") do |rel|
			if rel.attributes["type"] == "parts" && rel.elements["direction"]
				d = rel.elements["direction"].text
				if d == "backward"
					st = rel.elements["ordering-key"]
					if (st != nil)
						s = st.text.to_i
					else
						s = nil
					end
					up = rel.elements["work"].attributes["id"]
					if (up != nil)
						return (up), s
					end
				end
			end
		end
		return nil, nil
	end
	
	
	def getWorkArtists(id)
		c, r = mbCachedRequest("/ws/2/work/#{id}?inc=artist-rels")
		x = REXML::Document.new(r)
		#puts r
		arts = Array.new
		x.elements.each("/metadata/work/relation-list/relation") do |rel|	
			if (rel.attributes["type"] == "composer") || (rel.attributes["type"].include?("arranger"))
				an = rel.elements["artist/name"].text
				asn = rel.elements["artist/sort-name"].text
				aid = rel.elements["artist"].attributes["id"]
				at = rel.attributes["type"]
				arts << [an,asn,aid,at]
			end
		end
		return arts
	end

	


end


# things to do
# -- done  cache mb result if code = 200
# -done  try offset 182, 183 if 150 doesn't return a discid
# add in acoustID - try and get best match for a release
# acoustID -> recordings -> releases -> media
# count distinct track/release combos
# take release with most tracks 
# check total tracks = total tracks on release (or disc of release if poss)
# maybe cross-check track times too

#File.delete("/home/james/test.db")
d = Database.new("/home/james/testv.db")
#d = Database.new(argv[1])
a = MusicBrainz.new('192.168.0.99:5000',d)




x = TopFolder.new("/media/music/flac/classical/vocal")
#x = TopFolder.new("/home/james/Music/flac/classical")
#x = TopFolder.new(argv[0])


#=begin
d.resetTables
d.beginLUW
x.scan(d)
d.endLUW
#=end

dinfo = d.getDiscs
dinfo.each do |k,v| 	
	v.each do |w|
		if w[1] > (60 * 75 * 80)
			puts "Possible problem with #{k}, time = #{w[1]/(75*60.0)} minutes, tracks #{w[2]} to #{w[3]}"
		end
	end
end
d.beginLUW
dinfo.each do |k,v|
	v.each do |w|
		
		gotit = false
		[150,182,183,178,180,188,190].each do |o|
		
			id, toc = d.calcMbDiscID(k,w[0],o)
			#puts "#{k} #{w[0]} trying #{id} (#{o})"
			if a.checkDiscID(id) == "200"
				d.storeMbDiscID(id,k,w[0])
				#puts "Got discID for #{k} #{w[0]} with offset #{o} (#{id})"
				gotit = true
				break
			end
			
		end
		if (!gotit)
			id, toc = d.calcMbDiscID(k,w[0],150)
			puts "No discID for #{k} #{w[0]} with offsets tried"
			d.storeNoMBdisc(k,w[0],id,toc)
			puts "https://musicbrainz.org/cdtoc/attach?id=#{id}&tracks=#{toc}"
		end
	end
end

d.endLUW

10.times {|n| puts }

r = d.getAllMbDiscIDs
c = 0
z = r.size
r.each do |s|
	d.beginLUW
	c = c + 1
	puts "\n#{c} of #{z} #{s[2]} (#{s[0]})\n"
	a.getDiscByID(s[0])
	d.endLUW
end

10.times {|n| puts }

r = d.getDistinctWorks
s = r.size
ct = 0
r.each do |w|
	title, type, key = a.getWorkAttributes(w[0])
	puts "Track work: #{w[0]} #{title} #{type} #{key}"
	arts = a.getWorkArtists(w[0])
	arr = nil
	comp = nil
	arts.each do |art| 
		if art[3] == "composer"
			comp = art[1]
		else
			if art[3] == "arranger"
				arr = art[1]
			else
				if (art[3].include?("arranger")) && (arr == nil)
					arr = art[1]
				end
			end
		end
	end
	d.storeWorkDetails(w[0],title,type,key,comp,arr)
	c = w[0]
	p,s = a.getParentWork(c)
	while (p != nil)
		d.storeWorkParent(c,p,s)
		title, type, key = a.getWorkAttributes(p)
		puts "Parent work(#{s}): #{p} #{title} #{type} #{key}"
		arts = a.getWorkArtists(p)
		arr = nil
		comp = nil
		arts.each do |art| 
			if art[3] == "composer"
				comp = art[1]
			else
				if art[3] == "arranger"
					arr = art[1]
				else
					if (art[3].include?("arranger")) && (arr == nil)
						arr = art[1]
					end
				end
			end
		end
		d.storeWorkDetails(p,title,type,key,comp,arr)
		c = p
		p,s = a.getParentWork(c)
	end
	
	ct = ct + 1
	puts "#{ct} of #{s} works processed"
end

10.times {|n| puts }

r = d.getAllTracksWithWorks
r.each do |t|
	w = d.getParentWork(t[1])
	pwfound = false
	s = 0.0
	pwt = ""
	while (w != nil) && (!pwfound)
		pw = w[0]
		if w[1]
			s = w[1] + (s/100)
		end
		wd = d.getWorkDetails(w[0])
		pwt = wd[2]
		if ((wd[0] != nil) || (wd[1] != nil))
			pwfound = true
		end
		w = d.getParentWork(w[0])
	end
	puts "#{t[2]} is part #{s} of #{pwt}"
	d.storePerformingWork(t[0],pw,s)
end



# upsert work details
