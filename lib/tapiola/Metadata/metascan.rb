
require_relative 'metacore'
require_relative 'metamb'
require_relative 'metadb'
require 'optparse'



class TopFolder
	def initialize(t)
		@top = t
	end
	def scan
		count = 0
		total = 0 
		puts "Counting files"
		files = Dir[@top+'/**/*.flac']
		total = files.size
		puts "Stage 1: #{total} files to scan"
		started = Time.now
		
		files.each do |file|
			stdout,stderr,status = Open3.capture3("metaflac --show-sample-rate --show-total-samples --export-tags-to=- #{Shellwords.escape(file)}")
			if status != 0 then raise RuntimeError, "metaflac failed #{stderr}" end
			
			
			tr = Meta::Core::Track.new
			tr.createFromFilename(file)
			
			tr.sampleRate = stdout.split("\n")[0].to_i
			tr.samples = stdout.split("\n")[1].to_i

			stdout.split("\n")[2..-1].each do |line|
				if (m = /(.*)=(.*)/.match(line))
					tag = m[1]
					value = m[2]
					Meta::Core::Tag.new(tr,tag,value)
					tr.updateFromTag(tag,value)
				end
			end
			tr.store
			count = count + 1
			if ((count % 100) == 0)
				now = Time.now
				rate = (count * 1.0) / (now - started)
				eta = started + (total / rate)
				perc = (count * 100.0) / total
				puts "Stage 1: #{sprintf("%2.1f",perc)}% complete, ETC #{eta.strftime("%b-%d %H:%M.%S")}"
			end
		end
		puts "Stage 1: 100% complete"
	end
end

$stdout.sync

topfolder = '/media/music/flac/classical/c20/'
ws = 'musicbrainz.org'

OptionParser.new { |opts|
	opts.banner = "Usage: #{File.basename($0)} -d directory -w web service url"
	opts.on('-d', '--dir DIRNAME', 'Directory to scan for flac files') do |arg|
		topfolder = arg
	end
	opts.on('-w','--web-service host:port','host and (optional) port of MusicBrainz server') do |arg|
		ws = arg
	end
}.parse!

db = Meta::Database.new('/home/james/metascan.db')
db.resetTables
Meta::Core::Primitive.setDatabase(db)
w = Meta::MusicBrainz::Service.new(ws,db,:getCachedMbQuery,:storeCachedMbQuery)
Meta::MusicBrainz::Primitive.setService(w)


top = TopFolder.new(topfolder)
db.beginLUW
top.scan
db.endLUW