
require 'fileutils'
require 'pathname'
require 'open3'
require 'shellwords'
require 'httpclient'

files = Dir["/media/music/flac/classical/orchestral/Haydn/Haydn_Symphonies_Hogwood/**/*.flac"]

s = files.size
c = 0
files.each do |f|
	stdout, stderr, status = Open3.capture3('/home/james/Downloads/chromaprint-fpcalc-1.4.2-linux-x86_64/fpcalc "' + f +'"')
	if status != 0 then raise RuntimeError, "fpcalc failed #{stderr}" end
	out = stdout.split("\n")
	if (m = /DURATION=(\d+)$/.match(out[0]))
		dur = m[1].to_i
	else
		raise RuntimeError ,"can't parse duration from #{out[0]}"
	end
	if (m = /FINGERPRINT=(.*)$/.match(out[1]))
		fp = m[1]
	else
		raise RuntimeError, "can't parse fingerprint from #{out[1]}"
	end
	
	
	h = HTTPClient.new
	h.receive_timeout = 300
	 puts "https://api.acoustid.org/v2/lookup?client=I66oWRwcLj&duration=#{dur}&meta=recordings+releases&fingerprint=#{fp}"
	 
	
	r = h.request('GET',"https://api.acoustid.org/v2/lookup?client=I66oWRwcLj&fingerprint=#{fp}&duration=#{dur}&meta=recordings+releases")
	j = r.body
	if r.code != 200
		raise RuntimeError ,"acoustid returned #{r.code} #{j}"
	end
	puts j
	c = c + 1
	puts "#{c} of #{s} done"
	
	
end


