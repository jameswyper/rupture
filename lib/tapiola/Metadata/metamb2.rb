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
			create unique index if not exists release_ix1 on release(mbid);
			create unique index if not exists medium_ix1 on medium(release_mbid, position);
			create unique index if not exists track_ix1 on track(release_mbid, medium_position, position);
			create unique index if not exists recording_ix1 on recording(mbid);
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

end



class Release < MBBase
	
	attr_reader :mbid, :media, :title, :cached
	
	def initialize(mbid)
		@media = Hash.new
		
		if (getFromDB(mbid))
			@cached = true
		else
			@cached = false
			if (getFromMB(mbid))
				store
			end
		end
	end
	
	def cached?
		@cached
	end
	
	def getFromDB(mbid)
		r = @@db.execute('select mbid,title from release where mbid = ?',mbid)
		if r.size == 0
			return nil
		else
			@mbid = r[0][0]
			@title = r[0][1]
		end
	end
	
	def getFromMB(mbid)

		body = self.mbRequest("/ws/2/release/#{mbid}?inc=recordings")

		if (body)
			@mbid = mbid
			xroot = REXML::Document.new(body)
			@title = xroot.elements["metadata"].elements["release"].elements["title"].text
			#xroot.elements.each("metadata/release") do |r| 
			#	getFromXML(r)
			#end
		else
			@mbid = nil
		end
		return @mbid
	end

	def getFromXML(xml)
		xml.elements.each("medium-list/medium") do |m|
			if (!m.elements["format"]) || (m.elements["format"].text == "CD")
				pos = m.elements["position"].text.to_i
				@media[pos]  = Medium.new(m)
			end
		end
		return self
	end

	def store
		if (@@db.execute('select mbid,title from release where mbid = ?',@mbid).size > 0)
			@@db.execute('update release set title = ? where mbid = ?',@title,@mbid)
		else
			@@db.execute('insert into release (mbid,title) values (?,?)',@mbid,@title)
		end
	end
	
=begin
	def self.getFromDiscID(discid)
		code,body = @@mbWS.mbRequest("/ws/2/discid/#{discid}?inc=recordings")
		if code == 200
			xroot = REXML::Document.new(body)
			xroot.elements.each("metadata/disc/release-list/release") do |r| 
				if (!r.elements["medium-list"].elements["medium"].elements["format"]) ||
				   (r.elements["medium-list"].elements["medium"].elements["format"].text == "CD")
					@title = r.elements["title"].text
					@mbid = r.attributes["id"]
					getFromXML(r)
				end
			end
			return self
		else
			return nil
		end
	end
	def getFromMbid(mbid)
		@mbid = mbid
		code,body = @@mbWS.mbRequest("/ws/2/release/#{mbid}?inc=recordings")
		if code == 200
			xroot = REXML::Document.new(body)
			@title = xroot.elements["metadata"].elements["release"].elements["title"].text
			xroot.elements.each("metadata/release") do |r| 
				getFromXML(r)
			end
		end
		return self
	end
	
	def getFromXML(xml)
		xml.elements.each("medium-list/medium") do |m|
			if (!m.elements["format"]) || (m.elements["format"].text == "CD")
				pos = m.elements["position"].text.to_i
				@media[pos]  = Medium.new(m)
			end
		end
		return self
	end
	
	def medium(i)
		@media[i]
	end
	
	def mediumByDiscID(did)
		@media.each_value { |m| return m if m.discIDs[did] }
		return nil		
	end
=end	
end

=begin

class Medium < Primitive
	
	attr_reader :tracks, :discIDs
	
	def initialize(xml)
		@tracks = Hash.new
		@discIDs = Hash.new
		xml.elements.each("disc-list/disc") { |d| @discIDs[d.attributes["id"]] = d.attributes["id"] }
		xml.elements.each("track-list/track") do |t|
			num = t.elements["position"].text.to_i
			recid = t.elements["recording"].attributes["id"]
			rec = Recording.new.getFromMbid(recid)
			@tracks[num] = Track.new(num,rec)
		end
	end
	
	def track(i)
		@tracks[i]
	end
	
end

class Track < Primitive
	attr_reader :number, :recording
	def initialize(num,rec)
		@number = num
		@recording = rec
	end
end


class Recording < Primitive
	
	attr_reader :works, :artists, :mbid, :title, :length
	
	def initialize
		@mbid = nil
		@title = nil
		@length = nil
		@works = Array.new
		@artists = Array.new
	end
	def getFromMbid(mbid)
		code,body = @@mbWS.mbRequest("/ws/2/recording/#{mbid}?inc=work-rels%20artist-rels")
		if code == 200
			xroot = REXML::Document.new(body)
			#binding.pry
			xroot.elements.each("metadata/recording") do |r| 
				getFromXML(r)
			end
		end
		return self
	end
	def getFromXML(xml)
	
		@mbid = xml.attributes["id"]
		@title = xml.elements["title"].text
		@length = xml.elements["length"].text.to_i if xml.elements["length"]
		
		xml.elements.each("//relation-list[@target-type='artist']/relation") do |artrel|
			relation = artrel.attributes["type"]
			artdets = artrel.elements["artist"]
			artid = artdets.attributes["id"]
			artname = artdets.elements["name"].text
			artsortname = artdets.elements["sort-name"].text
			if (artrel.elements["attribute-list"] && artrel.elements["attribute-list"].elements["attribute"] )
				type = artrel.elements["attribute-list"].elements["attribute"].text 
			else
				type = nil
			end
			@artists << Artist.new(artid, artname, artsortname, relation,type)
		end
		
		xml.elements.each("//relation-list[@target-type='work']/relation") do |workrel|
			type = workrel.attributes["type"]
			if type == "performance"
				workid = workrel.elements["work"].attributes["id"]
				@works << Work.new(workid)
			end
		end
		return self
	end
end

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

class Artist < Primitive
	attr_reader :mbid, :name, :sortName, :relation, :type
	def initialize(mbid, name, sortName, relation, type)
		@mbid = mbid
		@name = name
		@sortName = sortName
		@relation = relation
		@type = type
	end
end

=end


end # MusicBrainz module


end # Meta module