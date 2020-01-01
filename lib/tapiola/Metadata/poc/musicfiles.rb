require 'fileutils'
require 'pathname'
require 'open3'
require 'shellwords'
require 'base64'
require_relative 'model'
require_relative  'acoustid'
require 'logger'

if  ($log == nil)  
	$log = Logger.new(STDOUT) 
	$log.level = Logger::INFO
end


module MusicFiles

class File
	
	attr_reader :basename, :pathname, :tags, :track, :disc, :sampleRate, :samples
	
	def initialize(f)
		p = Pathname.new(f)
		@basename = p.basename.to_s
		@pathname = p.dirname.to_s
		@tags = Hash.new
		@track = 0
		@disc = 0
	end
	
	def filename
		@pathname + "/" + @basename
	end
	
	def metaflac
		stdout,stderr,status = Open3.capture3("metaflac --show-sample-rate --show-total-samples --export-tags-to=- #{Shellwords.escape(self.filename)}")
		if status != 0 then raise RuntimeError, "metaflac failed #{stderr}" end
		@sampleRate = stdout.split("\n")[0].to_i
		@samples = stdout.split("\n")[1].to_i
		stdout.split("\n")[2..-1].each do |line|
			if (m = /(.*)=(.*)/.match(line))
				tag = m[1].downcase
				value = m[2]
				if !@tags[tag]
					@tags[tag] = [value]
				else
					@tags[tag] << value
				end
			end
		end
		if @tags["tracknumber"]
			@track = @tags["tracknumber"][0].split("/")[0].to_i
		else
			if @tags["track"]
				@track = @tags["track"][0].split("/")[0].to_i
			end
		end
		if @tags["discnumber"]
			@disc = @tags["discnumber"][0].to_i
		else
			if @tags["disc"]
				@disc = @tags["disc"][0].to_i
			end
		end

	end
	
	def getMetadata
		self.metaflac
		self
	end
	
end

class Directory
	def initialize(d)
		@pathname = d
		@files = Array.new
		@discs = Array.new
	end
	attr_reader :files, :discs, :pathname
	def scan
		Dir.glob(@pathname + '/*.flac').each do |f| 
			@files << File.new(f).getMetadata
		end
		@discs = Disc::discsFromDirectory(self)
		self
	end
end

class Disc
	attr_reader :pathname, :number, :tracks, :offsets, :base64Offsets, :mediumCandidatesOffsets, :mediumCandidatesAcoustID
	def self.discsFromDirectory(d)
		ds = Array.new
		d.files.each do |f|
			found = false
			ds.each do |di|
				if di.number == f.disc
					di.tracks[f.track] = f.dup
					found = true
				end
			end
			if (!found)
				ds << Disc.new(f.disc,d.pathname)
				ds[-1].tracks[f.track] = f.dup
			end
		end
		ds.each {|x| x.calculateOffsets}
		return ds
	end
	def initialize(n,p)
		@number = n
		@tracks = Hash.new
		@offsets = Array.new
		@pathname = p
	end
	def trackTotal
		@tracks.size
	end
	def calculateOffsets
		@tracks.keys.sort.each do |t|
			f = @tracks[t]
			o = ((f.samples * 75) / (f.sampleRate)).to_i
			@offsets << o
		end
		@base64Offsets =  Base64.encode64(@offsets.pack("L*"))		
	end
	def findMediumCandidatesByOffsets
		@mediumCandidatesOffsets = Array.new
#		puts "Looking for #{@pathname}/#{@number}"
		Model::Cdtoc.where(discid: @base64Offsets).each do |cdt| 
#			puts "Found cdtoc entry"
			cdt.medium.each { |cm| @mediumCandidatesOffsets << cm}
		end
	end
	def findMediumCandidatesByAcoustID
		@mediumCandidatesAcoustID = Array.new
		as = Meta::AcoustID::Service.new('/home/james/Downloads/fpcalc','I66oWRwcLj')
		candidates = Hash.new(0)
		firstTrack = @tracks[@tracks.keys.sort[0]].track
		@tracks.keys.sort.each do |ts|
			f = @tracks[ts]
			#puts "Processing #{f.filename}"
			foundRecordings = as.getAcoustIDRecordings(f.filename)
			foundRecordings.each do |fr|
				#puts "Found candidate recording #{fr}"
				rs = Model::Recording.where(gid: fr)
				if (rs.size != 1) 
					$log.warn "Recording #{fr} has #{rs.size} entries in database - #{f.pathname}/#{f.filename}" 
				end
				if (rs.size > 0)
					r = rs[0]
					#find tracks that have recording and check track number
					ts = r.track
					ts.each do |t|
						tracknum = (f.track + 1) - firstTrack
						#puts "We have track #{f.track} (#{tracknum})and mb has it in #{t.position} of #{t.medium.release.gid}/#{t.medium.position}"
						if (tracknum == t.position) # it's a good match
							candidates[t.medium] += 1
							#puts "#{t.medium.release.gid}/#{t.medium.position} now has #{candidates[t.medium]}"
						end
					end
				end
			end
		end
		candidates.each do |cm,cc|
			#puts "checking #{cm.release.gid}"
			score = (cc * 100.0) / cm.track.size
			#puts "#{cm.release.name}/#{cm.position} scored #{score}% our track count #{trackTotal} mb's #{cm.track.size}"
			if (score >= 80) && (trackTotal == cm.track.size)
				@mediumCandidatesAcoustID << cm
			end
		end
	end
end

class Tree
	attr_reader :top, :directories, :notFoundDiscs, :foundDiscsViaOffsets, :foundDiscsViaAcoustID, :foundDiscsViaInput
	def initialize(t)
		@top = t
		$log.info "Starting directory search at #{t}"
		d = Dir.glob(@top+'/**//')
		$log.info "#{d.size} directories to process"
		@directories = Array.new
		@notFoundDiscs = Array.new
		@foundDiscsViaOffsets = Array.new
		@foundDiscsViaInput = Array.new
		@foundDiscsViaAcoustID = Array.new
		
		c = 1
		d.each do |dir| 
			$log.info "Scanning #{c}/#{d.size}" if (c%50 == 0) 
			nd = Directory.new(dir)
			@directories << nd.scan
			nd.discs.each do |ndd| 
#				puts "adding #{ndd.pathname}/#{ndd.number} to list"
				@notFoundDiscs << ndd.dup
			end
			c = c + 1
		end
		$log.info "Scanning complete"
	end
	def findByOffsets
		$log.info "Starting Track Offset matching for #{@notFoundDiscs.size} discs"
		c = 1
		@notFoundDiscs.each do |nf|
#			puts "Processing #{nf.pathname}/#{nf.number}"
			$log.info "Processing #{c}/#{@notFoundDiscs.size}" if (c%100 == 0)
			nf.findMediumCandidatesByOffsets
			if nf.mediumCandidatesOffsets.size > 0
				@foundDiscsViaOffsets << nf
			end
			c = c + 1
		end
		$log.info "Track Offset matching complete"
		@notFoundDiscs = @notFoundDiscs - @foundDiscsViaOffsets
	end
	def findByAcoustID
		$log.info "Starting AcoustID matching for #{@notFoundDiscs.size} discs"
		c = 1
		@notFoundDiscs.each do |nf|
			#puts "AcoustID Processing #{nf.pathname}/#{nf.number}"
			$log.info "Processing #{c}/#{@notFoundDiscs.size}" if (c%10 == 0)
			nf.findMediumCandidatesByAcoustID
			if nf.mediumCandidatesAcoustID.size > 0
				@foundDiscsViaAcoustID << nf
			end
			c = c + 1
		end
		$log.info "AcoustID matching complete"
		@notFoundDiscs = @notFoundDiscs - @foundDiscsViaAcoustID
	end
end

end