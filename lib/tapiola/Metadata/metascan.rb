
require_relative 'metacore'
require_relative 'metamb'
require_relative 'acoustid'
require_relative 'metaconfig'
require 'pathname'

$config = Meta::Config.new

if $config.errors.size > 0
	$config.errors.each {|e| puts e}
	Kernel.exit(1)
end


puts "Scanning #{$config.directory}"



class Found
	attr_reader :entries
	
	#file format will be tab-separated
	# y / n to select candidate
	# folder
	# disc number
	# release id
	# medium
	
	def initialize(f)
		@entries = Hash.new
		File.open(f).each_line do |l|
			fields = l.chomp.split("\t")
			5.times {|x| fields << nil}
			fields[1] = Pathname.new(fields[1]).cleanpath.to_s
			if fields[0].downcase == "y"
				@entries[fields[1..2]] = fields[3..4]
			end
		end if f
	end
	def getEntry(path,disc)
		a = Array.new
		a << Pathname.new(path).cleanpath.to_s
		a << disc.to_s
		#e = @entries[[Pathname.new(path).cleanpath,disc.to_s]]
		e = @entries[a]
		if e
			return e[0],e[1].to_i
		else
			return nil,nil
		end
	end
end

STDOUT.sync = true


Meta::MusicBrainz::MBBase.openDatabase($config.mbdb)
Meta::MusicBrainz::MBBase.setServer($config.mbServer)
Meta::Core::DBBase.openDatabase($config.metadb)


ac_found = Found.new($config.acoustidFileIn)
di_found = Found.new($config.discidFileIn)

top = Meta::Core::Folder_flac.new($config.directory)
Meta::Core::DBBase.beginLUW
top.scan do |count,total,eta| 
	if eta
		puts "#{sprintf('%2.1f',(total == 0 ? 100.0 : (count * 100.0) / total))}% complete, ETC #{eta.strftime('%b-%d %H:%M.%S')}"
	else
		puts "0% complete"
	end
end
Meta::Core::DBBase.endLUW


#		ac = Meta::AcoustID::Service.new('/home/james/Downloads/chromaprint-fpcalc-1.4.2-linux-x86_64/fpcalc',token,server)



discs = top.fetchDiscs

count = 0
found_exact = 0
found_many = 0
foundFromFile = 0
total = discs.size
started = Time.now

nf = File::new($config.notFound,"w")
nf.puts("Path\tDisc Number\tDiscID\tRelease ID\tMedium number")

puts "Stage 2: #{total} discs to get MusicBrainz data for"

discs.each do |disc|
	
	Meta::Core::DBBase.beginLUW
	

	rel_mbid, med = di_found.getEntry(disc.pathname,disc.discNumber)
	unless rel_mbid
		rel_mbid, med = ac_found.getEntry(disc.pathname, disc.discNumber)
		unless rel_mbid
			puts "Seeking details for #{disc.pathname},#{disc.discNumber} #{Time.now.strftime("%b-%d %H:%M.%S")}"
			disc.fetchTracks
			$config.offsets.each do |offset|
				d = disc.calcMbDiscID(offset)
				di_rels = Meta::MusicBrainz::DiscID.new(d).findReleases
				if di_rels.size > 0
					if di_rels.size > 1
						#write out candidates
					else
						#found exact match
					end
					#find medium
					# go back and look at caching code
					# ensure fuller details are written out e.g. release name
					break
				end
				#CHANGEME - sort out correct method calls here
			end
		end
	end
	

=begin
OK, so you have a disc
Look in the Found files (discID first) for a match
Assign the release / medium for that if found
Look for a discID
if only one release for discID, assign release/medium for that
if more than one release, write out to discID file (all candidates)
if no release, write out to discID file AND do acoustid processing
	lookup tracks on acoustID
	count matches
	if one perfect match, assign it
	otherwise write out to acoustID file (all candidates)
end

if we've found a single match, update database (track to track and any other fields that should be done)

	
	
	#rel = Meta::MusicBrainz::Release.new	
	dID = nil
	med  = nil
	#puts "Seeking details for #{disc.pathname},#{disc.discNumber} #{Time.now.strftime("%b-%d %H:%M.%S")}"

	disc.fetchTracks
	[150,182,183,178,180,188,190].each do |offset|
		dID = disc.calcMbDiscID(offset)
		#puts "Attempting offset #{offset} and discID #{dID}"
		if (rel.getFromDiscID(dID))
			found += 1
			med = rel.mediumByDiscID(dID)
			break
		end
	end
	
	unless (rel.mbid)
		mDid, mRel, mMed = manual.getEntry(disc.pathname,disc.discNumber)
		#binding.pry
		if (mDid && mDid != "")
			if (rel.getFromDiscID(mDid))
				med = rel.mediumByDiscID(mDid)
				foundFromFile += 1
			else
				puts "Hmm couldn't find discID in lookup file for #{disc.pathname}/#{disc.discNumber}"
			end
		else
			if (mRel)
				med = rel.getFromMbid(mRel).medium(mMed)
				foundFromFile += 1
			else
				nf.puts "#{disc.pathname}\t#{disc.discNumber}\t\t\t"
			end
		end
	end
	

	
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
		if (rel.mbid)
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
=end	
	Meta::Core::DBBase.endLUW

end

nf.close


puts "Stage 2: 100% complete #{found} of #{total} discs found via discID lookup and #{foundFromFile} with manual lookup file"

