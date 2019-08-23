
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



class Found_file
	attr_reader :entries
	
	#file format will be tab-separated
	# y / n to select candidate
	# folder
	# disc number
	# release id
	# medium
	
	def initialize(f)
		@entries = Hash.new
		if File.exists?(f)
			File.open(f).each_line do |l|
				fields = l.chomp.split("\t")
				5.times {|x| fields << nil}
				fields[1] = Pathname.new(fields[1]).cleanpath.to_s
				if fields[0].downcase == "y"
					@entries[fields[1..2]] = fields[3..4]
				end
			end
		else
			puts "WARNING: file #{f} not found. Proceeding as if it was empty"
		end
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

class Found_disc
	attr_accessor :disc, :rel_mbid, :medium
	def initialize(d,r,m)
		@disc = d
		@rel_mbid = r
		@medium = m
	end
end

STDOUT.sync = true


Meta::MusicBrainz::MBBase.openDatabase($config.mbdb)
Meta::MusicBrainz::MBBase.setServer($config.mbServer)
Meta::Core::DBBase.openDatabase($config.metadb)
Meta::Core::DBBase.clearTables
acoustid = Meta::AcoustID::Service.new($config.fpcalc,$config.acToken,$config.acoustIDdb)


ac_found = Found_file.new($config.acoustidFileIn)
di_found = Found_file.new($config.discidFileIn)

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

dfm = File::new($config.discidFileOut,"w")
dfm.puts("Path\tDisc Number\tRelease Title\tDiscID\tRelease ID\tMedium number")

afm = File::new($config.acoustidFileOut,"w")
afm.puts("Path\tDisc Number\tRelease Title\tTracks\tHits\tMisses\tMedium number")


puts "Stage 2: #{total} discs to get MusicBrainz data for"

discs.each do |disc|
	
	Meta::Core::DBBase.beginLUW
	

	rel_mbid, med = di_found.getEntry(disc.pathname,disc.discNumber)
	unless rel_mbid
		rel_mbid, med = ac_found.getEntry(disc.pathname, disc.discNumber)
		unless rel_mbid
			puts "Seeking details for #{disc.pathname},#{disc.discNumber} #{Time.now.strftime("%b-%d %H:%M.%S")}"
			disc.fetchTracks
			anyDiscIDFound = false
			$config.offsets.each do |offset|
				d = disc.calcMbDiscID(offset)
				di_rels = Meta::MusicBrainz::DiscID.new(d).findReleases
				if di_rels.size > 0
					anyDiscIDFound = true
					if di_rels.size > 1
						# found several matches; write out candidates
						found_many += 1
						di_rels.each do |rel|
							puts "#{rel.title} is a candidate #{rel.mbid}"
							med = rel.mediumByDiscID(d)
							if med
								dfm.puts "#{disc.pathname}\t#{disc.discNumber}\t#{rel.title}\t#{rel.mbid}\t#{med.position}"
								puts "#{disc.pathname}\t#{disc.discNumber}\t#{rel.title}\t#{rel.mbid}\t#{med.position}" 
							else
								puts "no valid medium for #{rel.mbid} (probably an SACD)"
							end
						end
					else
						#found exact match
						found_exact += 1
						rel = di_rels[0]
						rel_mbid = rel.mbid
						med = rel.mediumByDiscID(d)
						if med
							puts "#{rel.title} disc #{med.position} is the only candidate #{rel.mbid}"
						else
							puts "no valid medium for #{rel.mbid} (probably an SACD)"
						end
					end

					# go back and look at caching code
					# ensure fuller details are written out e.g. release name
					break
				end
			end
			unless anyDiscIDFound
				# start looking for AcoustID
				puts "going to try AcoustID"
				candidates = acoustid.scoreDisc(disc)
				if candidates.size > 0
					if candidates.size > 1
						# found several matches, write out candidates
						candidates.each do |cand|
							afm.puts "#{disc.pathname}\t#{disc.discNumber}\t#{cand.release.title}\t#{cand.trackCount}\t#{cand.trackMatches}\t#{cand.trackMisses}\t#{cand.medium.position}"
							puts "AcoustID candidates #{disc.pathname}\t#{disc.discNumber}\t#{cand.release.title}\t#{cand.trackCount}\t#{cand.trackMatches}\t#{cand.trackMisses}\t#{cand.medium.position}"
						end
					else
						# found just one match
						cand = candidates[0]
						if (cand.trackMisses == 0) && (cand.trackMatches = cand.trackCount)
							puts "AcoustID match for #{disc.pathname} #{disc.discNumber} on #{cand.release.title} disc #{cand.medium.position}"
						else
							puts "AcoustID bad match #{disc.pathname} #{disc.discNumber} #{cand.release.title} #{cand.trackCount} #{cand.trackMatches} #{cand.trackMisses} #{cand.medium.position}"
						end
					end
				else
					puts "No AcoustID matches"
				end
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

found = found_exact + found_many
puts "Stage 2: 100% complete #{found} of #{total} discs found via discID lookup and #{foundFromFile} with manual lookup file"

