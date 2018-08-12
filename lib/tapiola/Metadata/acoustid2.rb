
require 'fileutils'
require 'pathname'
require 'open3'
require 'shellwords'
require 'httpclient'
require 'json'
require_relative 'metacore'
require_relative 'metamb'
require_relative 'metadb'
require 'optparse'

module Meta

module AcoustID

class Handler

def initialize(fpcalc = 'fpcalc', client = 'I66oWRwcLj',service = 'https://api.acoustid.org' )
	@fpcalc = fpcalc
	@service = service
	@client = client
end

def getAcoustDataFromFile(f)
	
	res = Array.new
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
	
	
	h = HTTPClient.new
	h.ssl_config.ssl_version = :SSLv23
	h.ssl_config.add_trust_ca("/etc/ssl/certs")
	h.receive_timeout = 300
	#puts f,fp
	
	r = h.request('GET',"#{@service}/v2/lookup?client=#{@client}&fingerprint=#{fp}&duration=#{dur}&meta=recordings+releases")
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
						u['releases'].each do |v|
							res << [u["id"],v["id"]]
							#puts "release #{v['id']}"
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


def getAcoustDataForDisc(d)
	rels = Hash.new

	
	#store all the releases
	#create a combo of all permutations of recordings
	d.fetchTracks
	
	c = 0
	d.tracks.keys.sort.each do |tr|
		c = c  + 1
		ad = getAcoustDataFromFile(d.pathname+'/'+d.tracks[tr].filename)
#		recs[tr.track] = Hash.new
		ad.each do |a|
			rels[a[1]] = Hash.new unless (rels[a[1]]) 
			rels[a[1]][c] = a[0]
#			recs[tr.track][a[0]] = a[1]
		end
#		s ="track #{tr.track} recordings "
#		recs[tr.track].each_key {|k| s << (k + " ") }
#		puts s
	end
	
	#puts "releases #{rels.to_s}"
	return rels
	
end

end # class
end #module
end #module

ws = 'musicbrainz.org'
db = Meta::Database.new('/home/james/metascan.db')
Meta::Core::Primitive.setDatabase(db)
w = Meta::MusicBrainz::Service.new(ws,db,:getCachedMbQuery,:storeCachedMbQuery)
Meta::MusicBrainz::Primitive.setService(w)

h = Meta::AcoustID::Handler.new('/home/james/Downloads/chromaprint-fpcalc-1.4.2-linux-x86_64/fpcalc')

discs = db.selectAllDiscs
puts discs.size
discs.each do |d|
	puts d.id
	puts "#{d.pathname}/#{d.discNumber}"

	rels = h.getAcoustDataForDisc(d)
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
			puts "score for #{cand} medium #{mk} is #{trackYes}/#{trackNo}/#{trackCount}"
		end
	end
end