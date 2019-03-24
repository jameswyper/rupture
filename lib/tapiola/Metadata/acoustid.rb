
require 'fileutils'
require 'pathname'
require 'open3'
require 'shellwords'
require 'httpclient'
require 'json'

require_relative 'metamb'

module Meta
module AcoustID

class Service
	
	def initialize(fpcalc,client,db, service = 'https://api.acoustid.org' )
		@fpcalc = fpcalc
		@service = service
		@client = client
		@db = SQLite3::Database.new(db)
		@db.execute('create table if not exists acoustid_cache (fprint text, response_json text);')
		@db.execute('create unique index if not exists fprint_ix1 on acoustid_cache(fprint);')
	end
	
	def acRequest(fp,dur)
		h = HTTPClient.new
		h.ssl_config.ssl_version = :SSLv23
		h.ssl_config.add_trust_ca("/etc/ssl/certs")
		h.receive_timeout = 300
		 
		 #puts "Fingerprint:#{fp}"
		 
		tries = 0
		begin
			r = h.request('GET',"#{@service}/v2/lookup?client=#{@client}&fingerprint=#{fp}&duration=#{dur}&meta=recordings+releases")
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
	
	
	class RecordingResult
		attr_reader :releases, :mbid
		def initialize(mbid)
			@mbid = mbid
			@releases = Array.new
		end
		def addRelease(rel)
			@releases << rel
		end
	end
	
	def getFingerprint(f)
		stdout, stderr, status = Open3.capture3(@fpcalc + ' -length 120 ' + Shellwords.escape(f))
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
	
	def getAcoustIDResults(f)
		
		x = Array.new

		fprint, duration = getFingerprint(f)
		puts "#{f} - duration #{duration}"
		r = @db.execute('select response_json from acoustid_cache where fprint = ?',fprint)
		if r.size > 0
			results = JSON.parse(r[0][0])["results"]
			puts "AcoustID cache hit"		
		else
			puts "AcoustID cache miss"
			response = acRequest(fprint,duration)
			results = JSON.parse(response)["results"]
			@db.execute('insert into acoustid_cache (fprint,response_json) values (?,?)',fprint,response)
		end

		results.each do |result| 
			recordings = result["recordings"]
			recordings.each do |recording|
				y = RecordingResult.new(recording["id"])
				releases = recording["releases"]
				releases.each do |release| 
					y.addRelease release["id"]
				end  if releases
				x << y
			end if recordings
		end if results
		
		return x
		
	end
	

		
	class ScoredMedium
		attr_accessor :release, :medium, :trackCount, :trackMatches, :trackMisses
		def initialize(release,medium)
			@release = release
			@medium = medium
			@trackMisses = 0
			@trackMatches = 0
		end
	end
		
	def scoreDisc(d)

		scores = Array.new
		
		recordings = Array.new
		
		# call AcoustID for each track on the disc, storing the recording/release combos

		candidateReleases = Hash.new
		
		discTrack = 0
		d.tracks.keys.sort.each do |tr|
			puts "AcoustID call (or cache) for Track #{tr}"
			discTrack = discTrack + 1
			recordings[discTrack] = getAcoustIDResults(d.pathname+'/'+d.tracks[tr].filename)
			recordings[discTrack].each do |rec|
				rec.releases.each do |rel| 
					if candidateReleases[rel]
						candidateReleases[rel] = candidateReleases[rel]  + 1
					else
						candidateReleases[rel] = 0
					end
				end
			end
		end	
		
		# popular hits can turn up on innumerable compilations.  Drop any releases where we didn't match a substantial fraction of tracks

		puts "#{candidateReleases.size} releases to juggle"
		candidateReleases.each do |rel,rec_count|
			if rec_count < (d.tracks.size * 0.5)
				candidateReleases.delete(rel)
			end
		end
		
		puts "#{candidateReleases.size} releases to juggle after trimming"
		
		
		candidateReleases.each_key do |candidate_mbid|
			puts "candidate release #{candidate_mbid}"
			candidate = Meta::MusicBrainz::Release.new(candidate_mbid)
			puts "got release from MB"
			puts "Candidate release is #{candidate.mbid} #{candidate.title}"
			candidate.media.each do |mpos,medium|
				#puts "Candidate medium #{medium.position}"
				scm = ScoredMedium.new(candidate,medium)
				medium.tracks.each do |tpos, track|
					#puts "Candidate track #{track.position} #{track.recording.mbid} #{track.recording.title}"
					match_found = false
					mb_rec_mbid = track.recording.mbid
					if recordings[tpos]
						#puts "There are acoustID hits for track #{tpos}"
						recordings[tpos].each do |ac_recording|
							#puts "checking #{ac_recording.mbid}"
							if ac_recording.mbid == mb_rec_mbid
								#puts "we have a match" 
								match_found = true
							end
						end
						if match_found
							scm.trackMatches += 1
						else 
							scm.trackMisses += 1
						end
					end
				end
				scm.trackCount = medium.tracks.size
				scores << scm
			end
		end
		
		scores.sort! do |x,y| 
			xmatch = (x.trackMatches * 1.0 / x.trackCount) 
			ymatch = (y.trackMatches * 1.0 / y.trackCount)
			if (xmatch == ymatch)
				(x.release.media.size <=> y.release.media.size)  # favour smaller releases over box sets
			else
				(ymatch <=> xmatch)
			end
		end
		
		return scores
	end
		
		
	end
	

	
end #AcoustID
end #Meta


