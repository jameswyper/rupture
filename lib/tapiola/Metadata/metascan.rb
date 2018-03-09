
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

STDOUT.sync = true

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
db.insertDiscsFromTracks
db.endLUW



discs = db.selectAllDiscs

count = 0
found = 0
total = discs.size
started = Time.now
puts "Stage 2: #{total} discs to get MusicBrainz data for"

discs.each do |disc|
	
	db.beginLUW
	
	rel = Meta::MusicBrainz::Release.new	
	dID = nil
	#puts "Seeking details for #{disc.pathname},#{disc.discNumber}"

	disc.fetchTracks
	[150,182,183,178,180,188,190].each do |offset|
		dID = disc.calcMbDiscID(offset)
		#puts "Attempting offset #{offset} and discID #{dID}"
		if (rel.getFromDiscID(dID))
			found += 1
			break
		end
	end
	
	unless (rel.mbid)
		#puts "No disc found for #{disc.pathname},#{disc.discNumber}"
		#find by release or discid on input
	end
	
	if (rel.mbid)
		#puts "Found #{rel.title} #{rel.mbid}"
		#med = rel.media[(disc.discNumber == 0) ? 1 : disc.discNumber] #need to replace this with search for discID
		med = rel.mediumByDiscID(dID)
		if med
			i = 1
			lasttr = 0
			disc.tracks.keys.sort.each do |track|
				if (track != (lasttr + 1)) && (lasttr != 0)
					puts "Tracks not contiguous #{disc.pathname} #{disc.discNumber} this:#{track}, last: #{lasttr}"
				end
				if med.tracks[i]
					rec = med.tracks[i].recording
					rec.works.each {|work| disc.tracks[track].addWork(work.mbid)}
				else
					puts "No track #{i} for #{rel.mbid} #{rel.title} #{disc.discNumber}"
				end
				i += 1
			end
		else
			puts "#{rel.mbid} medium #{disc.discNumber} not found?"
		end
	end

	count = count + 1
	if ((count % 10) == 0) 
		now = Time.now
		rate = (count * 1.0) / (now - started)
		eta = started + (total / rate)
		perc = (count * 100.0) / total
		puts "Stage 2: #{sprintf("%2.1f",perc)}% complete, ETC #{eta.strftime("%b-%d %H:%M.%S")} #{found} of #{total} discs found"
	end
	
	db.endLUW
end

puts "Stage 2: 100% complete #{found} of #{total} discs found"


works = db.selectDistinctWorkIDs

count = 0
found = 0
total = works.size
started = Time.now
puts "Stage 3: #{total} works to find details for"


works.each do |work|
	
	db.beginLUW

	lowestWithType = nil
	highestWithKey = nil
	
	
	mbWork = Meta::MusicBrainz::Work.new(work)
	mbWork.getFullDetails
	db.insertWork(mbWork)
	this = mbWork
	if (this.type)
		lowestWithType = this
	end
	if (this.key)
		highestWithKey = this
	end
	while (this.parent)
		par = Meta::MusicBrainz::Work.new(this.parent)
		par.getFullDetails
		db.insertWork(par)
		this = par
		if (this.type && !lowestWithType)
			lowestWithType = this
		end
		if (this.key)
			highestWithKey = this
		end
	end

	if (lowestWithType)
		perfWork = lowestWithType
	else
		if (highestWithKey)
			perfWork = highestWithKey
		else
			perfWork = this
		end
	end
	
	


	count = count + 1
	if ((count % 10) == 0) 
		now = Time.now
		rate = (count * 1.0) / (now - started)
		eta = started + (total / rate)
		perc = (count * 100.0) / total
		puts "Stage 3: #{sprintf("%2.1f",perc)}% complete, ETC #{eta.strftime("%b-%d %H:%M.%S")}"
	end

	db.endLUW

end

puts "Stage 3: 100% complete"
