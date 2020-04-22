require_relative 'tag'
require 'fileutils'
require 'pathname'
require 'writeexcel'
require 'damerau-levenshtein'

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
    def album
        @metadata.album[0]
    end
    def title
        @metadata.title[0]
    end    
    def directory
        File.dirname(@name)
    end
    def composer
        @metadata.composer[0]
    end
    def work
        @metadata.musicbrainz_workid[0]
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

albs = Hash.new
dir.files.each do |f|
    if albs[f.album + f.directory]
        albs[f.album + f.directory] << f
    else
        albs[f.album + f.directory] = [f]
    end
end

albs.each_value do |a|
    thisart = nil
    a.each do |f|
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

ws4.write_col(2,0,wout.sort_by {|r| [r[0],r[1]] })

puts "Check 5: Multi-directories for album"

wout = Array.new
ws5 = xls.add_worksheet("5 - Album Dir")
ws5.write(0,0,"Each Album has only one directory")
ws5.write_row(1,0,["Directory", "File","First Directory","Album"])


albs = Hash.new
dir.files.each do |f|
    if albs[f.album + f.albumartist]
        albs[f.album + f.albumartist] << f
    else
        albs[f.album + f.albumartist] = [f]
    end
end

albs.each_value do |a|
    firstdir = nil
    a.each do |f|
        firstdir = f.directory unless firstdir
        if (firstdir != f.directory)
            wout << [f.directory,f.base,firstdir,f.album ? f.album : ""]
        end
    end
end

=begin
root.each_value do |rel|
    if rel
        firstdir = nil
        rel.tracks.each_value do |tr|
            tr.files.each do |f|
                firstdir = f.directory unless firstdir
                if (f.directory != firstdir)
                    wout << [f.album ? f.album : "",f.release ? f.release : "",firstdir,f.directory,f.base]
                end
            end
        end
    end
end
=end


ws5.write_col(2,0,wout.sort_by {|r| [r[0],r[1],r[2],r[3]] })

puts "Check 6: Multi-albums for Directory"

wout = Array.new
ws6 = xls.add_worksheet("6 - Dir Album")
ws6.write(0,0,"Each Directory has only one Album")
ws6.write_row(1,0,["Directory","File","First Album","Other Album"])

dirs = Hash.new
dir.files.each do |f|
    if dirs[f.directory]
        dirs[f.directory] << f
    else
        dirs[f.directory] = [f]
    end
end

dirs.each_value do |fl|
    firstalb = nil
    fl.each do |f|
        firstalb = f.album unless firstalb
        if (firstalb != f.album)
            wout << [f.directory,f.base,firstalb,f.album]
        end
    end
end

ws6.write_col(2,0,wout.sort_by {|r| [r[0],r[1],r[2],r[3]] })

puts "Check 7: Classical tracks have works"

wout = Array.new
ws7 = xls.add_worksheet("7 - Works")
ws7.write(0,0,"Classical Tracks have Works")
ws7.write_row(1,0,["Directory","File"])
dir.files.each do |f|
    if f.directory.include?("/classical/")
        if (f.work == "") || (f.work.nil?)
            wout << [f.directory,f.base]
        end
    end 
end
ws7.write_col(2,0,wout.sort_by {|r| [r[0],r[1]] })

puts "Check 8: Non-classical tracks don't have composer"

wout = Array.new
ws8 = xls.add_worksheet("8 - Composers")
ws8.write(0,0,"Non-Classical don't have composers")
ws8.write_row(1,0,["Directory","File","Composer"])
dir.files.each do |f|
    unless f.directory.include?("/classical/")
        if (f.composer && f.composer != "")
            wout << [f.directory,f.base,f.composer]
        end
    end 
end
ws8.write_col(2,0,wout.sort_by {|r| [r[0],r[1]] })

puts "Check 9: Similar artists"

dl = DamerauLevenshtein
wout = Array.new
ws9 = xls.add_worksheet("9 - Similar artists")
ws9.write(0,0,"Artist pairs with low edit distance")
ws9.write_row(1,0,["Artist 1", "Artist 2","Directory","File","Distance"])
arts = Hash.new
dir.files.each do |f|
    if arts[f.artist]
        arts[f.artist] << f
    else
        arts[f.artist] = [f]
    end
end
as = arts.size
ac = 0
arts.each_key do |a1|
    arts.each_key do |a2|
        ac = ac + 1
        if ((ac % 100) == 0)
            puts "#{ac} of approximately #{as*as} done; written #{wout.size}"
        end
        if (a1 != a2) && a1 && a2
            c1 = a1.start_with?("The ") ? a1[4..-1].downcase : a1.downcase
            c2 = a2.start_with?("The ") ? a2[4..-1].downcase : a2.downcase
            l1 = c1.length
            l2 = c2.length
            l = 1.0 * (l1 > l2 ? l2 : l1)
            d = dl.distance(c1,c2,2) 
            ds = d / l
            if (ds < 0.1) || (d < 2)
                arts[a1].each do |f|
                    wout << [a1,a2,f.directory,f.name,ds]
                end
            end
        end
    end
end
ws9.write_col(2,0,wout.sort_by {|r| [r[4],r[0],r[1],r[2],r[3]] })

puts "Check 10: Similar composers"

wout = Array.new
ws10 = xls.add_worksheet("10 - Similar Composers")
ws10.write(0,0,"Composer pairs with low edit distance")
ws10.write_row(1,0,["Composer 1", "Composer 2","Directory","File","Distance"])
arts = Hash.new
dir.files.each do |f|
    if arts[f.composer]
        arts[f.composer] << f
    else
        arts[f.composer] = [f]
    end
end
as = arts.size
ac = 0
arts.each_key do |a1|
    arts.each_key do |a2|
        ac = ac + 1
        if ((ac % 100) == 0)
            puts "#{ac} of approximately #{as*as} done; written #{wout.size}"
        end
        if (a1 != a2)  && a1 && a2
            d = dl.distance(a1.downcase,a2.downcase,2)
            if d < 3
                arts[a1].each do |f|
                    wout << [a1,a2,f.directory,f.name,d]
                end
            end
        end
    end
end

ws10.write_col(2,0,wout.sort_by {|r| [r[4],r[0],r[1],r[2],r[3]] })

puts "Check 11: Leading / trailing spaces"

wout = Array.new
ws11 = xls.add_worksheet("11 - Spaces")
ws11.write(0,0,"Tags with leading or trailing spaces")
ws11.write_row(1,0,["Directory", "File","Artist","Album","Composer","Title"])

dir.files.each do |f|
    if (f.artist && f.artist.start_with?(" ")) ||
        (f.artist && f.artist.end_with?(" ")) || 
        (f.album && f.album.start_with?(" ")) ||
        (f.album && f.album.end_with?(" ")) || 
        (f.title && f.title.start_with?(" ")) ||
        (f.title && f.title.end_with?(" ")) || 
        (f.composer && f.composer.start_with?(" ")) ||
        (f.composer && f.composer.end_with?(" "))
            wout << [f.directory,f.base,"|#{f.artist}|","|#{f.album}|","|#{f.composer}|","|#{f.title}|"]
    end
end

ws11.write_col(2,0,wout.sort_by {|r| [r[0],r[1]] })



=begin
To do:

Remove The prefix when checking artist similarities
Score based on distance / overall length

include artist in check 5

**testing to here**

genre check

track has exactly one front cover
same cover for all tracks in album
cover size less than 100k

Count of albums split by composer count
moving scheme - create mock-up and check no clashes

Multi-valued tags
=end


xls.close
