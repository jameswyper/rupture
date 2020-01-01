
require 'fileutils'
require 'pathname'
require 'open3'
require 'shellwords'
require 'httpclient'
require 'json'


module Meta
module AcoustID

class Service
	
	def initialize(fpcalc,client,service = 'https://api.acoustid.org' )
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
			r = h.request('GET',"#{@service}/v2/lookup?client=#{@client}&fingerprint=#{fp}&duration=#{dur}&meta=recordingids")
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
	
	def getAcoustIDRecordings(f)
		
		x = Array.new

		fprint, duration = getFingerprint(f)
		response = acRequest(fprint,duration)
		#puts response
		results = JSON.parse(response)["results"]

		results.each do |result| 
			recordings = result["recordings"]
			recordings.each do |recording|
				x << recording["id"]
			end if recordings
		end if results
		
		return x.uniq  # not sure why acoustId returns the same recording twice sometimes but it does
		
	end
	
	
end
	
end #AcoustID
end #Meta


