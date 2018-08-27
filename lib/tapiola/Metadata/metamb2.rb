require 'rexml/document'
require 'httpclient'
require 'pry'
require 'sqlite3'

module Meta

module MusicBrainz

class MBBase
	@@mbServer =  'musicbrainz.org'
	def self.setServer(s)
		@@mbServer = s
	end
	def self.openDatabase(f)
		@@db = SQLite3::Database.new(f)
		@@db.execute_batch('
			create table if not exists release (mbid text, title text);
			create table if not exists medium (release_mbid text, position integer, format text);
			create table if not exists track (release_mbid text, medium_position integer, position integer, recording_mbid text);
			create table if not exists recording (mbid text, title text, length integer);
			create table if not exists medium2discid (release_mbid text, position integer, discid text);
			create table if not exists discid (discid text);
			create unique index if not exists release_ix1 on release(mbid);
			create unique index if not exists medium_ix1 on medium(release_mbid, position);
			create unique index if not exists track_ix1 on track(release_mbid, medium_position, position);
			create unique index if not exists recording_ix1 on recording(mbid);
			create index if not exists medium2discid_ix1 on medium2discid(release_mbid, position);
			create index if not exists medium2discid_ix2 on medium2discid(discid);
			create unique index if not exists discid_ix1 on discid(discid);
			create table if not exists artist (mbid text, name text, sortname text);
			create unique index if not exists artist_idx1 on artist(mbid);
			create table if not exists release2artist (release_mbid text, seq integer, artist_mbid text, joinphrase text);
			create unique index if not exists release2artist_ix1 on release2artist(release_mbid,seq);
			create index if not exists release2artist_ix2 on release2artist(artist_mbid);
			create table if not exists recording2artist (recording_mbid text, seq integer, artist_mbid text, joinphrase text);
			create unique index if not exists recording2artist_ix1 on recording2artist(recording_mbid,seq);
			create index if not exists recording2artist_ix2 on recording2artist(artist_mbid);
			create table if not exists recording2work (recording_mbid text, work_mbid text);
			create unique index if not exists recording2work_ix1 on recording2work(recording_mbid,work_mbid);
			create index if not exists recording2work_ix1 on recording2work(work_mbid);
			create table if not exists recording2release (recording_mbid text, release_mbid text);
			create unique index if not exists recording2release_ix1 on recording2release(recording_mbid,release_mbid);
			create table if not exists work (mbid text, title text, composer text, type text, key text, performing_work_mbid text, performing_work_title text, performing_work_type text);
			create unique index if not exists work_ix1 on work(mbid);
			create index if not exists work_ix2 on work(performing_work_mbid);
			create table if not exists work2artist (work_mbid text, artist_mbid text, role text);
			create index if not exists work2artist_ix1 on work2artist(work_mbid);
			create index if not exists work2artist_ix2 on work2artist(artist_mbid);
			create table if not exists work2work (work_mbid text, parent_work_mbid text);
			create unique index if not exists work2work_ix1 on work2work(work_mbid,parent_work_mbid);
			create index if not exists work2work_ix2 on work2work(parent_work_mbid);
		')

		
	end
	def self.clearDatabase
		@@db.execute_batch('
			drop table if exists release;
			drop table if exists medium;
			drop table if exists track;
			drop table if exists recording;
		')
	end
	
	def mbRequest(req)
 
		c = HTTPClient.new
		c.receive_timeout = 300
		tries = 0
		
		if @@mbServer.include?("musicbrainz.org")  
			sleep(1.1)
		end

		begin
			r = c.request('GET',"http://#{@@mbServer}/#{req}",
			:header => {'user-agent' => 'tapiola https://github.com/jameswyper/tapiola'})
			if (r.code == 503) || (r.code == 500)
				raise
			end
		rescue
			tries += 1
			if (tries > 5)
				raise
			else
				case r.code
				when 503
					sleep 5
				when 500
					sleep 60
				else
					sleep 300
				end
				
				retry
			end
		end
			
		
		if (r.code == 200)
			return r.body
		else
			#puts r.code, r.body
			return nil
		end

	end
	
	def cached?
		@cached
	end

end



class Release < MBBase
	
	attr_reader :mbid, :media, :title, :cached, :artists
	
	def initialize(mbid,xml = nil)
		@media = Hash.new
		@artists = Array.new
		
		if (getFromDB(mbid))
			@cached = true
		else
			@cached = false
			if (getFromMB(mbid,xml))
				store
			end
		end
	end
	

	
	def getFromDB(mbid)
		r = @@db.execute('select mbid,title from release where mbid = ?',mbid)
		if r.size == 0
			return nil
		else
			@mbid = r[0][0]
			@title = r[0][1]
			Medium.getByRelease(mbid).each do |p|
				@media[p] = Medium.new(self,p)
			end
			linkArtists
		end
	end
	
	def getFromMB(mbid,xml)

		if xml
			body = xml
		else
			body = self.mbRequest("/ws/2/release/#{mbid}?inc=recordings%2Bdiscids%2Bartist-credits")
		end

		if (body)
			@mbid = mbid
			xroot = REXML::Document.new(body)
			@title = xroot.elements["metadata"].elements["release"].elements["title"].text
			xroot.elements.each("/metadata/release/medium-list/medium") do |m|
				if (!m.elements["format"]) || (m.elements["format"].text == "CD")
					pos = m.elements["position"].text.to_i
					@media[pos]  = Medium.new(self,pos,m)
				end
			end
			linkArtists(xroot)
		else
			@mbid = nil
		end
		return @mbid
	end


	def store
		if (@@db.execute('select mbid,title from release where mbid = ?',@mbid).size > 0)
			@@db.execute('update release set title = ? where mbid = ?',@title,@mbid)
		else
			@@db.execute('insert into release (mbid,title) values (?,?)',@mbid,@title)
		end


		@artists.each do |a|
			@@db.execute('delete from release2artist where release_mbid = ?',@mbid)
			@artists.each_index do |i|
				@@db.execute('insert into release2artist (release_mbid, seq, artist_mbid, joinphrase) values (?,?,?,?)',
					@mbid,i,artists[i][0].mbid,artists[i][1])
			end
		end


	end
	
	def medium(i)
		@media[i]
	end
	
	def artist(i)
		@artists[i][0]
	end
	
	def each_artist
		@artists.each { |a| yield a[0]}
	end
	

	def linkArtists(xml=nil)
		if xml
			#puts xml
			xml.elements.each("*/release/artist-credit/name-credit")  do |a| 
				#puts a
				jp= a.attributes["joinphrase"]
				@artists << [ Artist.new(a.elements["artist"].attributes["id"],a) , jp ]
			end
		else
			#puts "getting artists from database #{@mbid}"
			r = @@db.execute('select seq, artist_mbid, joinphrase from release2artist where release_mbid = ?',@mbid)
			r.each do |d|
				#puts "got artist #{d[0]}/#{d[1]}/#{d[2]}"
				@artists[d[0]] = [Artist.new(d[1]), d[2]]
			end
		end
	end
	

	
	def mediumByDiscID(did)
		@media.each_value { |m| return m if m.discIDs[did] }
		return nil		
	end

end



class Medium < MBBase
	
	attr_reader :tracks, :discIDs, :release, :position, :format
	
	def initialize(release,pos,xml=nil)
		@tracks = Hash.new
		@discIDs = Hash.new
		@release = release
		@position = pos
		#puts "new medium #{release.mbid} #{pos} #{xml}"
		if xml
			@cached = false
			xml.elements.each("track-list/track") do |txml|
				num = txml.elements["position"].text.to_i
				@tracks[num] = Track.new(self,num,txml)
			end
			f = xml.elements["format"]
			@format = f.text if f
			linkDiscIDs(xml)
			store
		else
			r = @@db.execute('select format from medium where release_mbid = ? and position = ?', @release.mbid,@position)
			@format = r[0][0]
			Track.getByMedium(@release.mbid,@position).each do |t|
				@tracks[t] = Track.new(self,t)
			end
			linkDiscIDs
			@cached = true
		end
	end
	
	def self.getByRelease(mbid)
		r = @@db.execute('select position from medium where release_mbid = ?',mbid)
		q = Array.new
		r.each {|s| q << s[0] }
		return q
	end

	def linkDiscIDs(xml=nil)
		if xml
			xml.elements.each("disc-list/disc")  do |d| 
				id = d.attributes["id"]
				@discIDs[id] = DiscID.new(id)
			end
		else
			r = @@db.execute('select discid from medium2discid where release_mbid = ? and position = ?',@release.mbid,@position)
			r.each do |d|
				@discIDs[d[0]] = DiscID.new(d[0])
			end
		end
	end
	

	def store
		if @@db.execute('select release_mbid from medium where release_mbid = ? and position = ?',@release.mbid,@position).size > 0
			@@db.execute('update medium set format = ? where release_mbid = ? and position = ?',@format, @release.mbid,@position)
		else
			@@db.execute('insert into medium (release_mbid, position, format) values (?,?,?)',@release.mbid,@position,@format)
		end
		@discIDs.each_key do |k|
			#puts "checking / storing #{@release.mbid}/#{@position}/#{k}"
			unless @@db.execute('select discid from medium2discid where release_mbid = ? and position = ? and discid = ?',@release.mbid,@position,k).size > 0
				@@db.execute('insert into medium2discid (release_mbid, position, discid) values (?,?,?)',@release.mbid,@position,k)
			end
		end
	end
	
	def track(i)
		@tracks[i]
	end
	
end


class DiscID < MBBase
	attr_reader :discid, :releases
	
	def initialize(did)
		@releases = Array.new
		@discid = did
		store
	end

	def store
		unless @@db.execute('select discid from discid where discid = ?',@discid).size > 0
			@@db.execute('insert into discid (discid) values (?)',@discid)
		end
	end
	# need to add a method to get relesases from db
	def findReleases

		body = self.mbRequest("/ws/2/discid/#{@discid}?inc=recordings%2Bartist-credits")
		if body
			xml = REXML::Document.new(body)
			xml.elements.each("metadata/disc/release-list/release") do  |r|
				@releases << Release.new(r.attributes["id"])
			end
		end

	end
end


class Track < MBBase
	attr_reader :position, :recording, :medium
	
	def initialize(medium,pos,xml = nil)
		@medium = medium
		@position = pos
		if xml
			@recording = Recording.new(xml.elements["recording"].attributes["id"])
			@cached = false
			store
		else
			@cached = true
			r = @@db.execute('select recording_mbid from track where release_mbid = ? and medium_position = ? and position = ?',
				@medium.release.mbid, @medium.position, @position)
			@recording = Recording.new(r[0][0])
		end
		
	end
	
	def self.getByMedium(mbid,pos)
		r = @@db.execute('select position from track where release_mbid = ? and medium_position = ?', mbid,pos)
		q = Array.new
		r.each {|s| q << s[0] }
		return q
	end

	def store
		if @@db.execute('select recording_mbid from track where release_mbid = ? and medium_position = ? and position = ?',@medium.release.mbid,@medium.position,@position).size > 0
			@@db.execute('update track set recording_mbid = ? where release_mbid = ? and medium_position = ? and position = ?',@recording.mbid, @medium.release.mbid,@medium.position,@position)
		else
			@@db.execute('insert into track (release_mbid, medium_position, position, recording_mbid) values (?,?,?,?)',@medium.release.mbid,@medium.position,@position,@recording.mbid)
		end
	end

end


class Recording < MBBase
	
	attr_reader :works, :artists, :mbid, :title, :length, :releases
	
	def initialize(mbid)
		@mbid = mbid
		@works = Array.new
		@artists = Array.new
		@releases = Hash.new
		if getFromDB
			@cached = true
		else
			@cached = false
			getFromMB
			store
		end
	end

	
	def getFromDB

		r = @@db.execute('select title, length from recording where mbid = ?',@mbid)
		#puts "query on #{@mbid} returned #{r.size} rows"
		if r.size == 0 
			return nil
		else
			@title = r[0][0]
			@length = r[0][1]
		end
		r = @@db.execute('select artist_mbid, joinphrase from recording2artist where recording_mbid = ? order by seq',@mbid)
		r.each do |a|
			linkArtist(a[0],a[1])
		end
		r = @@db.execute('select work_mbid from recording2work where recording_mbid = ?',@mbid)
		r.each do |w|
			linkWork(w[0])
		end
		r = @@db.execute('select release_mbid from recording2release where recording_mbid = ?',@mbid)
		r.each do |l|
			linkRelease(l[0])
		end
		return true
	end
	
	def getFromMB
		
		body = self.mbRequest("/ws/2/recording/#{mbid}?inc=work-rels%2Bartist-credits%2Breleases")


		if (body)
			xroot = REXML::Document.new(body).elements["metadata"].elements["recording"]
			@title = xroot.elements["title"].text
			@length = xroot.elements["length"].text.to_i if xroot.elements["length"]
			xroot.elements.each("release-list/release") do |r|
				linkRelease(r.attributes["id"])
			end
			xroot.elements.each("artist-credit/name-credit") do |a|
				linkArtist(a.elements["artist"].attributes['id'],a.attributes["joinphrase"])
			end
			wroot = xroot.elements["relation-list[@target-type='work']"]
			if wroot #some recordings don't have works
				wroot.elements.each("relation[@type='performance']") do |w|
					linkWork(w.elements["work"].attributes["id"])
				end
			end
		else
			return nil
		end
	end
	
	
	def linkWork(mbid)
		@works << Work.new(mbid)
	end
	
	def linkRelease(mbid)
		@releases[mbid] = true
		#@releases[mbid] = Release.new(mbid)
		# don't create a release object here - too much potential for recursion
	end
	
	def linkArtist(mbid,jp)
		@artists << [Artist.new(mbid),jp]
	end
	
	def store
		if  @@db.execute('select mbid from recording where mbid = ?',@mbid).size == 0
			@@db.execute('insert into recording(mbid,title,length) values (?,?,?)',@mbid,@title,@length)
		else
			@@db.execute('update recording set title = ?, length = ? where mbid = ?',@title,@length,@mbid)
		end
		@@db.execute('delete from recording2artist where recording_mbid = ?',@mbid)		
		@@db.execute('delete from recording2work where recording_mbid = ?',@mbid)		
		@@db.execute('delete from recording2release where recording_mbid = ?',@mbid)	
		releases.each_key do |r|
			@@db.execute('insert into recording2release(recording_mbid,release_mbid) values(?,?)',@mbid,r)
		end
		works.each do |w|
			#puts "about to insert #{@mbid}/#{w.mbid}"
			
			#occasionally it seems the same recording/work combo can appear more than once
			if @@db.execute('select recording_mbid from recording2work where recording_mbid = ? and work_mbid = ?',@mbid,w.mbid).size == 0
				@@db.execute('insert into recording2work(recording_mbid,work_mbid) values (?,?)',@mbid,w.mbid)
			end
		end
		artists.each_index do |i|
			@@db.execute('insert into recording2artist(recording_mbid,seq,artist_mbid,joinphrase) values(?,?,?,?)',@mbid,i,artists[i][0].mbid, artists[i][1])
		end
	end

end


class Artist < MBBase
	attr_reader :mbid, :name, :sortname
	
	def initialize(mbid,xml=nil)
		@mbid = mbid

		r = @@db.execute('select name, sortname from artist where mbid = ?',mbid)
		if r.size > 0
			@name = r[0][0]
			@sortname = r[0][1]
			@cached = true
		else
			if xml
				if (xml.elements["artist"].attributes["id"] != mbid)
					puts "artist mbid mismatch"
				end
				@name = xml.elements["artist"].elements["name"].text
				@sortname = xml.elements["artist"].elements["sort-name"].text
			else
				body = self.mbRequest("/ws/2/artist/#{mbid}")
				if (body)
					xroot = REXML::Document.new(body).elements["metadata"].elements["artist"]
					@name = xroot.elements["name"].text
					@sortname = xroot.elements["sort-name"].text
				end
			end
			store
		end
	end 

	
	def fileUnder
		if @name == @sortname
			return @name
		else
			return @sortname.split(",")[0]
		end
	end
	
	def store
		if @@db.execute('select mbid from artist where mbid = ?',@mbid).size > 0
			@@db.execute('update artist set name = ?, sortname = ? where mbid = ?',@name,@sortname,@mbid)
		else
			@@db.execute('insert into artist (mbid,name,sortname) values (?,?,?)',@mbid,@name,@sortname)
		end
	end
end

class Work < MBBase
	attr_reader :mbid, :title, :type, :key, :parent, :parentSeq, :seq, :alias, :artists
	
	def initialize(mbid)
		@mbid = mbid
		#puts "creating work for #{mbid}"
		@artists = Array.new
		if getFromDB
			@cached = true
		else
			@cached = false
			body = self.mbRequest("/ws/2/work/#{mbid}?inc=work-rels%2Bartist-rels%2Baliases")
			if (body)
				xroot = REXML::Document.new(body).elements["metadata"]
				
				@title = xroot.elements["work"].elements["title"].text
				@type = xroot.elements["work"].attributes["type"]
				k = xroot.elements.to_a("work/attribute-list/attribute[@type='Key']")
				@key = k[0].text if k[0]
				
				puts "title/type/key #{@title}/#{@type}/#{@key}"
				#binding.pry
				xroot.elements.each("work/alias-list/alias") do |a|
					#puts "in alias list"
					if (a.attributes["type"] =="Work name") && (a.attributes["locale"] == "en" )
							@alias = a.text
							puts "alias #{@alias} found"
					end
				end
				
				xroot.elements.each("work/relation-list[@target-type='work']/relation") do |workrel|
					#puts "found a work relation"
					if workrel.attributes["type"] == "parts"
						if workrel.elements["direction"]
							if workrel.elements["direction"].text == "backward"
								@parentSeq = workrel.elements["ordering-key"].text.to_i if workrel.elements["ordering-key"]
								@parent = Work.new(workrel.elements["target"].text)
							end
						end
					end
				end
				
				xroot.elements.each("work/relation-list[@target-type='artist']/relation") do |rel|	
					#puts "found an artist relation"
					if (rel.attributes["type"] == "composer") || (rel.attributes["type"].include?("arranger"))

						aid = rel.elements["artist"].attributes["id"]
						at = rel.attributes["type"]

						@artists << [Artist.new(aid),at]

					end
				end
			end
		end
	
	end
	
	def getFromDB
		return nil
	end
end

=begin
class Work < Primitive
	attr_reader :mbid, :title, :type, :key, :parent, :parentSeq, :alias, :artists
	
	def initialize(mbid)
		@mbid = mbid
		@alias = nil
		@type = nil
		@title = nil
		@key = nil
		@parent = nil
		@parentSeq = nil
		@artists = Hash.new
	end
	
	def getFullDetails
		code, body = @@mbWS.mbRequest("/ws/2/work/#{@mbid}?inc=aliases%20work-rels")	
		if code == 200
			xroot = REXML::Document.new(body)
			@type = xroot.elements["/metadata/work"].attributes["type"]
			@title = xroot.elements["/metadata/work/title"].text
			k = xroot.elements.to_a("/metadata/work/attribute-list/attribute[@type='Key']")
			@key = k[0].text if k[0]
			xroot.elements.each("/metadata/work/alias-list/alias") do |a|
				#binding.pry
				if (a.attributes["type"] =="Work name") && (a.attributes["locale"] == "en")
						@alias = a.text
				end
			end
			xroot.elements.each("/metadata/work/relation-list[@target-type='work']/relation") do |workrel|
				if workrel.attributes["type"] == "parts"
					if workrel.elements["direction"]
						if workrel.elements["direction"].text == "backward"
							@parentSeq = workrel.elements["ordering-key"].text.to_i if workrel.elements["ordering-key"]
							@parent = workrel.elements["target"].text
						end
					end
				end
			end
		end
		code, body = @@mbWS.mbRequest("/ws/2/work/#{@mbid}?inc=artist-rels")
		xroot = REXML::Document.new(body)
		xroot.elements.each("/metadata/work/relation-list/relation") do |rel|	
			if (rel.attributes["type"] == "composer") || (rel.attributes["type"].include?("arranger"))
				an = rel.elements["artist/name"].text
				asn = rel.elements["artist/sort-name"].text
				aid = rel.elements["artist"].attributes["id"]
				at = rel.attributes["type"]
				if @artists[at] 
					@artists[at] << Artist.new(aid,an,asn,rel.attributes["type"],at)
				else
					@artists[at] = [Artist.new(aid,an,asn,rel.attributes["type"],at)]
				end
			end
		end
		return self
	end
	
end



=end


end # MusicBrainz module


end # Meta module