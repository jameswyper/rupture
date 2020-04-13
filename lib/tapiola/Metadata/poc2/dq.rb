require_relative 'tag'
require 'fileutils'
require 'pathname'
require 'writeexcel'

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
    def directory
        File.dirname(@name)
    end
    def base
        File.basename(@name)
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


puts "Scanning done and #{dir.files.length} files found"

xls = WriteExcel.new('dq.xls')

puts "Check 1: Every Track has a Release and a Recording"
ws1 = xls.add_worksheet("1 - Rel - rec")
root = Hash.new
dir.files.each do |f|
#    puts "#{f.name} has release #{f.release} and recording #{f.recording}"
    root[f.release] = Release.new unless root[f.release]
    root[f.release].add_track(f)
end

ws1.write(0,0,"Files with no release")
ws1.write_row(1,0,["Directory","File","Release?","Recording"])

wout = Array.new
root.each do |rel,rec| 
    rec.tracks.each_key do |k|
        rec.tracks[k].files.each do |f|
            unless (rel && k)
                wout << [f.directory,f.base,rel ? "Y" : "",k ? "Y" : ""]
            end
        end
    end
end

ws1.write_col(2,0,wout.sort_by {|r| [r[0],r[1]] })


root[nil] ? nn = root[nil].tracks[nil].files.length : nn = 0

puts "#{nn} files with no Release and Recording"

wout = Array.new
ws2 = xls.add_worksheet("2 - Dup RlRc")
ws2.write(0,0,"Duplicate Release/Recording combinations")
ws2.write_row(1,0,["Directory","File","Recording","Release"])

puts "Check 2: No duplicate release/recording combinations"

root.each_value do |rel|
    rel.tracks.each_value do |tr|
        if tr.files.length > 1
#            puts "Group of duplicates for #{tr.files[0].release}/#{tr.files[0].recording}"
            tr.files.each do |f|
                wout << [f.directory,f.base,f.release,f.recording]
#                puts "#{f.name} #{f.release}/#{f.recording}"
            end
        end unless tr.files[0].release.nil?
    end
end

ws2.write_col(2,0,wout.sort_by {|r| [r[2],r[3],r[0],r[1]] })

puts "Check 3: Track number format and contiguity"

wout = Array.new
ws3 = xls.add_worksheet("3 - Tracks")
ws3.write(0,0,"Track numbering issues")
ws3.write_row(1,0,["Directory","File","This Track","Previous Track"])

root.each_value do |rel|
    alb = Array.new
    rel.tracks.each_value do |tr|
        alb << tr.files[0]
    end
    alb.sort! {|a,b| a.track.to_i <=> b.track.to_i }
    last = 0
    alb.each do |f|
        issue_this = ""
        issue_last = ""
        unless f.track =~ /^\d+$/
            issue_this = f.track
        end
        this = f.track.to_i
        unless this == last + 1
            unless this % 100 == 1
                issue_this = f.track
                issue_last = last
#                puts "#{f.name} track jump this:#{this} last:#{last}"
            end
        end
        last = this
        unless ((issue_this == "")  && (issue_last == ""))
            wout << [f.directory,f.base,issue_this,issue_last]
        end
    end
end

ws3.write_col(2,0,wout.sort_by {|r| [r[0],r[1]] })

puts "Check 4: Artist / Album Artist"

wout = Array.new
ws4 = xls.add_worksheet("4 - Artists")
ws4.write(0,0,"Artist / Album Artist consistency")
ws4.write_row(1,0,["Directory","File","Artist","Other Artist","Album Artist"])

root.each_value do |rel|
    thisart = nil
    rel.tracks.each_value do |tr|
      
        tr.files.each do |f|
            issue_artist = ""
            issue_other_artist = ""
            issue_album_artist = ""
            thisart = f.artist unless thisart
            albart = f.albumartist
            if (thisart != f.artist) && (albart != "Various Artists")
                #puts "#{f.name} artist inconsistency (#{f.artist}/#{thisart})"
                issue_other_artist = thisart
                issue_artist = f.artist
            end
            if (f.artist != albart) && (albart != "Various Artists")
                issue_artist = f.artist
                issue_album_artist = albart
                #puts "#{f.name} album artist #{albart} but artist #{f.artist}"
            end
            unless ((issue_album_artist == "") && (issue_artist == "") && (issue_other_artist == ""))
                wout << [f.directory,f.base,issue_artist,issue_other_artist,issue_album_artist]
            end
        end
        
    end 
end

ws4.write_col(2,0,wout.sort_by {|r| [r[0],r[1]] })


=begin
To do:
    
Classical tracks have works
Only Classical tracks have composers
Count of albums split by composer count
one directory per album
one album per directory
moving scheme - create mock-up and check no clashes
suggest similar artists (low edit distance)
track has exactly one front cover
same cover for all tracks in album

=end


xls.close
