require 'rexml/document'
require 'httpclient'
require 'pry'

module Meta

module MusicBrainz

class Primitive
	def self.setService(s)
		@@mbWS = s
	end
end

class Release < Primitive
	
	attr_reader :mbid, :media, :title
	
	def initialize
		@media = Hash.new
		@mbid = nil
	end
	
	def getFromDiscID(discid)
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
	
end

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

class Service


=begin rdoc
Used to call the MusicBrainz web service.  Allows for results to be cached e.g. on a database; for this to happen
a cache Object needs to be sent (this is typically a database handle) with methods that will check the cache and store 
a result for caching
=end
	def initialize(server = "musicbrainz.org",cacheObject = nil, checkCacheMethod = nil,storeCacheMethod = nil)
		@server = server
		@checkCache = checkCacheMethod
		@storeCache = storeCacheMethod
		@cacheObject = cacheObject
		Primitive.setService(self)
	end
	
	def mbUncachedRequest(service)
		c = HTTPClient.new
		c.receive_timeout = 300
		if @server.include?("musicbrainz.org")  
			sleep(1.1)
		end
		r = c.request('GET',"http://#{@server}/#{service}",
			:header => {'user-agent' => 'tapiola https://github.com/jameswyper/tapiola'})
		while (r.code == 503) || (r.code == 500)
			r = c.request('GET',"http://#{@server}/#{service}",
				:header => {'user-agent' => 'tapiola https://github.com/jameswyper/tapiola'})
			if (r.code == 503) 
				sleep(5)
			else
				puts "#{r.code}: #{service}"
				sleep(60)
			end
		end
		return r
	end
	
	def mbRequest(service)
		
		code, body = @cacheObject.send(@checkCache,service) if (@cacheObject)
		if (!code)
			req = mbUncachedRequest(service)
			code = req.code
			body = req.body
			#puts "cache miss for #{service}"
			@cacheObject.send(@storeCache,service, code, body) if (@cacheObject)
		else
			#puts "cache hit for #{service}"
		end
		
		#puts body
		
		return code, body

	end



end

end # MusicBrainz module


end # Meta module