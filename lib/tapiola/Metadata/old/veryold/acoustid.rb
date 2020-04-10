
require 'fileutils'
require 'pathname'
require 'open3'
require 'shellwords'
require 'httpclient'
require 'json'


module Meta
module AcoustID

class Service
	
	def initialize(fpcalc = 'fpcalc', client = 'I66oWRwcLj',service = 'https://api.acoustid.org' )
		@fpcalc = fpcalc
		@service = service
		@client = client
	end
	
	def acRequest(fp,dur)
		h = HTTPClient.new
		h.ssl_config.ssl_version = :SSLv23
		h.ssl_config.add_trust_ca("/etc/ssl/certs")
		h.receive_timeout = 300
		 
		tries = 0
		begin
			r = h.request('GET',"https://api.acoustid.org/v2/lookup?client=I66oWRwcLj&fingerprint=#{fp}&duration=#{dur}&meta=recordings+releases")
		rescue
			tries += 1
			if (tries > 5)
				raise
			else
				puts "Problem with http request, retrying"
				sleep 300
				retry
			end
		end
		if r.code != 200
			raise RuntimeError ,"acoustid returned #{r.code} #{r.body}"
		end
		return r.body
	end
	
	class Recording
		attr_accessor :releases
		attr_reader :mbid
		def initialize(mbid)
			@releases = Array.new
		end
	end
	
	class ResultsByRelease
		
		class Release
			def initialize
				@recordings = Hash.new
			end
			def addRecording(rec)
				@recordings[rec] = rec
			end
		end
		
		attr_accessor :releases
		def initialize
			@releases = Hash.new
		end
		
		def addRecording(rec)
			rec.releases.each do |rel|
				@releases[rel] = Release.new unless @releases[rel] 
				@releases[rel].addRecording(rec.mbid)
			end
		end
	end
	
	def getFingerprint(f)
		stdout, stderr, status = Open3.capture3('fpcalc ' + Shellwords.escape(f))
		if status != 0 then raise RuntimeError, "fpcalc failed #{stderr} on file #{f}" end
		out = stdout.split("\n")
		if (m = /^DURATION=(\d+)$/.match(stdout))
			dur = m[1].to_i
		else
			raise RuntimeError ,"can't parse duration from #{out[0]}"
		end
		if (m = /^FINGERPRINT=(.*)$/.match(stdout))
			fp = m[1]
		else
			raise RuntimeError, "can't parse fingerprint from #{out[1]}"
		end
		return fp,dur
	end
	
	def getFromFile(f)
		
		res = ResultsByRelease.new
		
		fprint, duration = getFingerprint(f)
		results = JSON.parse(acRequest(fprint,duration))["results"]
		results.each do |result| if results
			recordings = result["recordings"]
			recordings.each do |recording| if recordings
				y = Recording.new(recording["id"])
				releases = recording["releases"]
				releases.each do |release| if releases
					y.releases << release["id"]
				end
				res.addRecording(y)
			end
		end
		
		return res
		
	end
	
	class ScoredDisc
		
		class ScoredMedium
			attr_accessor :mbid, :medium, :trackCount, :trackMatches, :trackMisses
		end
		
		def initialize(d)
			@disc = d
			candidates = Hash.new
			c = 0
			d.tracks.keys.sort.each do |tr|
				c = c  + 1
				candidates[c] = getFromFile(d.pathname+'/'+d.tracks[tr].filename)
			end	
			
		end
	end
	

	
end


class AcoustID
	
	attr_accessor :fpalc, :url, :token
	
def getAcoustDataFromFile(f)
	
	res = Array.new
	
	h = HTTPClient.new
	h.ssl_config.ssl_version = :SSLv23
	h.ssl_config.add_trust_ca("/etc/ssl/certs")
	h.receive_timeout = 300
	 #puts "https://api.acoustid.org/v2/lookup?client=I66oWRwcLj&duration=#{dur}&meta=recordings+releases&fingerprint=#{fp}"
	 
	 tries = 0
	begin
		r = h.request('GET',"https://api.acoustid.org/v2/lookup?client=I66oWRwcLj&fingerprint=#{fp}&duration=#{dur}&meta=recordings+releases")
	rescue
		tries += 1
		if (tries > 5)
			raise
		else
			puts "Problem with http request, retrying"
			sleep 300
			retry
		end
	end
	j = r.body
	if r.code != 200
		raise RuntimeError ,"acoustid returned #{r.code} #{j}"
	end
	puts j
	h = JSON.parse(j)
	r =  h["results"]
	if r.size > 0
		if r[0]["recordings"]
			r.each do |s| 
				#puts "acoustid #{s['id']}"
				t = s["recordings"]
				if (t)
					t.each do |u|
						#puts "recording #{u['id']}"
						if u['releases']
							u['releases'].each do |v|
								tit = v['title']
								arts = v['artists']
								art  = ""
								if (arts)
									arts.each do |a|
										art << "#{a['name']}/"
									end
								end
								art.chop!
								res << [u["id"],v["id"],tit,art]
								#puts "release #{v['id']}"
							end
						end
					end
				end
			end
		#else
			#r.each {|i| puts i["id"]}
		end
	end
	return res
end





	def getRecordingsFromFile(f)
	end
	def getReleasesForDisc(d)

		rels = Hash.new
		c = 0
		d.tracks.keys.sort.each do |tr|
			c = c  + 1
			ad = getAcoustDataFromFile(d.pathname+'/'+d.tracks[tr].filename)
			ad.each do |a|
				rels[a.release_id] = Hash.new unless (rels[a.release_id]) 
				rels[a.release_id][c] = a

			end
		end
	
		return rels
	
	end

end
class Recording
	attr_reader :id, :release_id, :release_title, :release_artists
	def initialise(id,relid,title)
		@id = id
		@release_id = relid
		@release_title = title
		@release_artists = Array.new
	end
	def add_artist(art)
		@release_artists << art
	end
	def all_artists
		a = String.new
		@release_artist.each{ |r| a << "#{r}/" }
		a.chop!
	end
end

class Release
	attr_reader :artist, :title
	attr_accessor :recordings
	def initialize(art,tit)
		@artist = art
		@title = tit
		@recordings = Array.new
	end
end

end
end



ws = 'musicbrainz.org'
db = Meta::Database.new('/home/james/metascan.db')
Meta::Core::Primitive.setDatabase(db)
w = Meta::MusicBrainz::Service.new(ws,db,:getCachedMbQuery,:storeCachedMbQuery)
Meta::MusicBrainz::Primitive.setService(w)

discs = db.selectAllDiscs
puts discs.size
discs.each do |d|
#d = discs[1]
	puts d.id
	puts "#{d.pathname}/#{d.discNumber}"
	d.fetchTracks
	rels = getAcoustDataForDisc(d)
	
	scored = Array.new
	rels.each_key do |cand|
		candrel = Meta::MusicBrainz::Release.new	
		candrel.getFromMbid(cand)
		candrel.media.each do |mk,mv| 
			trackCount = mv.tracks.size
			trackYes = 0
			trackNo = 0
			mv.tracks.each_key do |tk|
				if (rels[cand][tk])
					if (rels[cand][tk] == mv.tracks[tk].recording.mbid)
						trackYes += 1
					else
						trackNo += 1
					end
				end
			end
#			puts "score for #{cand} medium #{mk} is #{trackYes}/#{trackNo}/#{trackCount}"
			scored << [cand, mk,(100.0 * (trackYes - (3 *trackNo)) / trackCount), d.tracks.size == mv.tracks.size]
			#binding.pry
		end
		scored.sort! {|x,y| if (y[2] == x[2]) then x[1] <=> y[1] else y[2] <=> x[2] end}
	end
	scored.each_index do |s|
		if (s>9)
			break
		else
			puts "release #{scored[s][0]}/#{scored[s][1]} scored #{scored[s][2]}% match #{scored[s][3]}" unless scored[s][2] <= 0
		end
	end
end