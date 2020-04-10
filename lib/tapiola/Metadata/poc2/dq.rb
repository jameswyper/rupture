require_relative 'tag'
require 'fileutils'
require 'pathname'

class Directory
	def initialize(d)
		@pathname = d
		@files = Array.new
	end
	attr_reader :files, :pathname
    def scan
        c = 0
        d = Dir.glob(@pathname + '/**//*.flac')
        ds = d.size
        d.each do |f|
            yield f, c, ds if block_given?
            @files << MusicFile.new(f)
            c = c + 1
		end
	end
end

class MusicFile

    attr_reader :metadata, :name
    def initialize(f)
        @name = f
        @metadata = GenericTag::Metadata.from_flac(f)
    end
    def release 
        @metadata.musicbrainz_albumid[0] 
    end
    def recording
        @metadata.musicbrainz_recordingid[0] 
    end 
    def track
        @metadata.tracknumber[0]
    end
    def artist
        @metadata.artist[0]
    end
    def albumartist
        @metadata.albumartist[0]
    end
end

class Track
    attr_reader :files
    def initialize
        @files = Array.new
    end
    def add_file(f)
        @files << f 
    end
end

class Release
    attr_reader :tracks
    def initialize
        @tracks = Hash.new
    end
    def add_track(f)
        t = @tracks[f.recording]
        if t
            t.add_file(f)
        else 
            t = Track.new
            @tracks[f.recording] = t 
            t.add_file(f)
        end 
    end
end

dir = Directory.new(ARGV[0])
puts "Scanning"
dir.scan do |file,count,total|
    #puts "#{count}/#{total} #{file}"
    if (count % 20 == 0) then puts "#{count}/#{total}" end
end
=begin
dir.scan do |file,count,total|
    #puts "#{count}/#{total} #{file}"
    if (count % 20 == 0) then puts "#{count}/#{total}" end
end
=end

puts "Scanning done and #{dir.files.length} files found"

puts "Check 1: Every Track has a Release and a Recording"

root = Hash.new
dir.files.each do |f|
#    puts "#{f.name} has release #{f.release} and recording #{f.recording}"
    root[f.release] = Release.new unless root[f.release]
    root[f.release].add_track(f)
end

root[nil] ? nn = root[nil].tracks[nil].files.length : nn = 0

puts "#{nn} files with no Release and Recording"

puts "Check 2: No duplicate release/recording combinations"

root.each_value do |rel|
    rel.tracks.each_value do |tr|
        if tr.files.length > 1

            puts "Group of duplicates for #{tr.files[0].release}/#{tr.files[0].recording}"
            tr.files.each do |f|
                puts "#{f.name} #{f.release}/#{f.recording}"
            end
        end unless tr.files[0].release.nil?
    end
end

puts "Check 3/4: Track number format and contiguity"

root.each_value do |rel|
    alb = Array.new
    rel.tracks.each_value do |tr|
        alb << tr.files[0]
    end
    alb.sort! {|a,b| a.track.to_i <=> b.track.to_i }
    last = 0
    alb.each do |f|
        unless f.track =~ /^\d+$/
            puts "#{f.name} has track |#{f.track}|"
        end
        this = f.track.to_i
        unless this == last + 1
            unless this % 100 == 1
                puts "#{f.name} track jump this:#{this} last:#{last}"
            end
        end
        last = this
    end
end

puts "Check 5: Artist / Album Artist"

root.each_value do |rel|
    thisart = nil
    rel.tracks.each_value do |tr|
      
        tr.files.each do |f|
            thisart = f.artist unless thisart
            albart = f.albumartist
            if (thisart != f.artist) && (albart != "Various Artists")
                puts "#{f.name} artist inconsistency (#{f.artist}/#{thisart})"
            end
            if (f.artist != albart) && (albart != "Various Artists")
                puts "#{f.name} album artist #{albart} but artist #{f.artist}"
            end
        end
        
    end 
end