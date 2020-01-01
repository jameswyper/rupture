require 'fileutils'
require 'pathname'
require 'shellwords'
require_relative 'model'
require 'logger'

STDOUT.sync = true
if  ($log == nil)  
	$log = Logger.new(STDOUT) 
end
$log.level = Logger::INFO

# Y / path / disc / release / position / gid


class MatchedDisc
	Release = Struct.new(:gid, :position)
	Disc = Struct.new(:path,:disc)
	@@Discs = Hash.new
	def self.process_line(line)
		fields = line.split('')
	end
	def initialize
		@releases = Array.new
		@preferred = nil
	end
end	