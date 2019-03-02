
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
	# release title
	# release id
	# medium
	# discID
	# Tracks
	# Hits
	# Misses
	
	def initialize(f)
		@entries = Hash.new
		if File.exists?(f)
			File.open(f).each_line do |l|
				fields = l.chomp.split("\t")
				5.times {|x| fields << nil}
				fields[1] = Pathname.new(fields[1]).cleanpath.to_s
				if fields[0].downcase == "y"
					@entries[fields[1..2]] = fields[4..6]
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
			return e[0],e[1].to_i,e[2]
		else
			return nil,nil,nil
		end
	end
end

STDOUT.sync = true


Meta::MusicBrainz::MBBase.openDatabase($config.mbdb)
Meta::MusicBrainz::MBBase.setServer($config.mbServer)
Meta::Core::DBBase.openDatabase($config.metadb)
Meta::Core::DBBase.clearTables
acoustid = Meta::AcoustID::Service.new($config.fpcalc,$config.acToken,$config.acoustIDdb)


found = Found.new($config.candidates)

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


discs = top.fetchDiscs

count = 0
found_exact = 0
found_many = 0
foundFromFile = 0
total = discs.size
started = Time.now

nf = File::new($config.notFound,"w")
nf.puts("Use?\tPath\tDisc Number\tRelease Title\tRelease ID\tMedium number\tDiscID\tTracks\tHits\tMisses")




puts "Stage 2: #{total} discs to get MusicBrainz data for"

discs.each do |disc|
	
	Meta::Core::DBBase.beginLUW
	

	rel_mbid, med = found.getEntry(disc.pathname,disc.discNumber)
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
							nf.puts "\t#{disc.pathname}\t#{disc.discNumber}\t#{rel.title}\t#{rel.mbid}\t#{med.position}\t#{d}"
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
						nf.puts "Y\t#{disc.pathname}\t#{disc.discNumber}\t#{rel.title}\t#{rel.mbid}\t#{med.position}\t#{d}"
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
						nf.puts "\t#{disc.pathname}\t#{disc.discNumber}\t#{cand.release.title}\t#{cand.release.mbid}\t#{cand.medium.position}\t\t#{cand.trackCount}\t#{cand.trackMatches}\t#{cand.trackMisses}"
#							puts "AcoustID candidates #{disc.pathname}\t#{disc.discNumber}\t#{cand.release.title}\t#{cand.trackCount}\t#{cand.trackMatches}\t#{cand.trackMisses}\t#{cand.medium.position}"
					end
				else
					# found just one match
					cand = candidates[0]
					if (cand.trackMisses == 0) && (cand.trackMatches == cand.trackCount)
#							puts "AcoustID match for #{disc.pathname} #{disc.discNumber} on #{cand.release.title} disc #{cand.medium.position}"
						nf.puts "Y\t#{disc.pathname}\t#{disc.discNumber}\t#{cand.release.title}\t#{cand.release.mbid}\t#{cand.medium.position}\t\t#{cand.trackCount}\t#{cand.trackMatches}\t#{cand.trackMisses}"
					else
						puts "AcoustID bad match #{disc.pathname} #{disc.discNumber} #{cand.release.title} #{cand.trackCount} #{cand.trackMatches} #{cand.trackMisses} #{cand.medium.position}"
					end
				end
			else
				puts "No AcoustID matches"
			end
		end
	end
	


	Meta::Core::DBBase.endLUW

end

nf.close

found = found_exact + found_many
puts "Stage 2: 100% complete #{found} of #{total} discs found via discID lookup and #{foundFromFile} with manual lookup file"

