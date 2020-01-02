require 'fileutils'
require 'pathname'
require 'shellwords'
require_relative 'model'
require_relative 'coverart'
require 'logger'

STDOUT.sync = true
if  ($log == nil)  
	$log = Logger.new(STDOUT) 
end
$log.level = Logger::INFO

# Y / path / disc / release / position / gid


class MatchCandidate
	attr_accessor :preferred
	attr_reader :title, :position, :gid

	def initialize(title,position,gid, preferred = false)
		@title = title
		@position = position
		@gid = gid
		@preferred = preferred
	end

	def preferred?
		@preferred
	end

	def self.read(line)
		fields = line.split("\t")
		c = MatchCandidate.new(fields[3],fields[4],fields[5],(fields[0].strip.downcase == "y"))
		return c
	end
	
	def write
#		"#{if preferred then "Y" end}\t#{@path}\t#{@disc}\t#{@title}\t#{@position}\t#{@gid}"
	end
end	

class MatchDisc
	attr_accessor :candidates, :path, :disc

	def initialize
		@candidates = Array.new
		@disc = nil
		@path = nil
	end
	def read(lines)
		puts "#{lines.size} lines for this disc"
		@path = lines[0].split("\t")[1]
		@disc = lines[0].split("\t")[2]
		lines.each do |l|
			mc = MatchCandidate.read(l)
			if (mc.gid.strip != "")
				@candidates << mc
			end
		end
	end
	def preferred
		s = @candidates.select{|c| c.preferred?}
		if s.size == 0
			return nil
		else
			return s[0]
		end
	end
end

class MatchReport

	def initialize
		@discs = Array.new
	end

	def read(f)
		lprev = nil
		ds = Array.new
		File.readlines(f).each do |l|
			ls = l.split("\t")
			if (ls[1] != "") && (ds.size > 0)
				md = MatchDisc.new
				md.read(ds)
				@discs << md.dup
				ds.clear
			end
			ds << l.dup
		end
		md = MatchDisc.new
		md.read(ds)
		@discs << md
	end

	def write(f)
	end
end

m = MatchReport.new
m.read("/home/james/matchreport.txt")

puts ""