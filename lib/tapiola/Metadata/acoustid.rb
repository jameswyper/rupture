
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
		 
		 puts "Fingerprint:#{fp}"
		 
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
	
	def getFromFile(f)
		
		x = Array.new

		fprint, duration = getFingerprint(f)
		puts "#{f} - duration #{duration}"
		results = JSON.parse(acRequest(fprint,duration))["results"]
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
		def intialize(release,medium)
			@release = release
			@medium = medium
		end
	end
		
	def scoreDisc(d)

		scores = Array.new
		
		recordings = Array.new
		
		# call AcoustID for each track on the disc, storing the recording/release combos

		candidateReleases = Hash.new

		d.tracks.keys.sort.each do |tr|
			puts "getting from File.."
			recordings[tr] = getFromFile(d.pathname+'/'+d.tracks[tr].filename)
			recordings[tr].each do |rec|
				rec.releases.each { |rel| candidateReleases[rel] = rel } 
			end
		end	
		

		

		
		candidateReleases.each do |candidate_mbid|
			puts "candidate release #{candidate_mbid}"
			candidate = Meta::MusicBrainz::Release.new(candidate_mbid)
			candidate.media.each do |mpos,medium|
				scm = ScoredMedium.new(candidate,medium)
				medium.tracks.each do |tpos, track| 
					match_found = false
					mb_rec_mbid = track.recording.mbid
					if recordings[tpos]
						recordings[tpos].each do |ac_recordings|
							ac_recordings.each do |ac_recording|
								if ac_recording == mb_rec_mbid
									match_found = true
								end
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
			xmatch = (x.trackMatches * 1.0 / x.TrackCount) 
			ymatch = (y.trackMatches * 1.0 / y.TrackCount)
			if (xmatch == ymatch)
				return (x.release.media.size <=> y.release.media.size)  # favour smaller releases over box sets
			else
				return (xmatch <=> ymatch)
			end
		end
		
		return scores
	end
		
		
	end
	

	
end #AcoustID
end #Meta


