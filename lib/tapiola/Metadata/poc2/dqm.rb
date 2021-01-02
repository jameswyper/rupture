require_relative 'tag'
require 'fileutils'

require 'writeexcel'
require 'damerau-levenshtein'
require 'shellwords'
require 'pathname'

String.class_eval do

def sanitise
    return self.gsub(" ","_").gsub('/','-').gsub(":","_").gsub('-',"_")
end

end

class Directory
	def initialize(d)
		@pathname = d
		@files = Array.new
	end
	attr_reader :files, :pathname
    def scan
        c = 0
        d = Dir.glob(@pathname + '/**//*.mp3')
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
        @metadata = GenericTag::Metadata.from_mp3(f)
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
    def albumartist=(x)
        @metadata.albumartist[0] = x
    end
    def album
        @metadata.album[0]
    end
    def album=(x)
        @metadata.album[0] = x
    end
    def title
        @metadata.title[0]
    end
    def title=(x)
        @metadata.title[0] = x
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
    def genre
        @metadata.genre[0]
    end
    def base
        File.basename(@name)
    end
    def covers
        @metadata.pics[:front_cover]
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

save = false
restore = false
move = false
movepath = ""


case ARGV.length
when 1
    sourcepath = ARGV[0]
when 2,4
    unless ARGV[0] == "-r" then abort "Should specify -r (filename)" end
    savepath = ARGV[1]
    restore = true
    if ARGV[2] == "-m"
        move = true
        movepath = ARGV[3]
    end
when 3,5
    unless ARGV[0] == "-d" then abort "Should specify -d (filename) (path)" end
    savepath = ARGV[1]
    sourcepath = ARGV[2]
    save = true
    if ARGV[3] == "-m"
        move = true
        movepath = ARGV[4]
    end
else
    abort "Should have max 1-5 arguments"        
end

if (!restore)

    dir = Directory.new(sourcepath)
    puts "Scanning"
    dir.scan do |file,count,total|
        #puts "#{count}/#{total} #{file}"
        if (count % 20 == 0) then puts "#{count}/#{total}" end
    end
    puts "Scanning done and #{dir.files.length} files found"
end

if (save)
    File.open(savepath,"w").write(Marshal.dump(dir))
end

if (restore)
    puts "Restoring"
    dir = Marshal.load(File.open(savepath).read)
end

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
ws3.write_row(1,0,["Directory","File","This Track","Previous Track","Previous Directory","Previous File"])

root.each_value do |rel|
    alb = Array.new
    rel.tracks.each_value do |tr|
        alb << tr.files[0]
    end
    alb.sort! {|a,b| a.track.to_i <=> b.track.to_i }
    last = 0
    last_f = nil
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
            wout << [f.directory,f.base,issue_this,issue_last,last_f ? last_f.directory : "",last_f ? last_f.base : ""]
        end
        last_f = f
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
  k = "#{f.album}#{f.directory}"
    if albs[k]
        albs[k] << f
    else
        albs[k] = [f]
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
    k = (f.album ? f.album : "") + (f.albumartist ? f.albumartist : "")
    if albs[k]
        albs[k] << f
    else
        albs[k] = [f]
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

=begin

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

=end

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

puts "Check 12: Covers"

wout = Array.new
ws12 = xls.add_worksheet("12 - Covers")
ws12.write(0,0,"Files with 0 or 2+ front covers, or large covers")
ws12.write_row(1,0,["Directory", "File","Covers?","Size?","Different?"])

cmd5 = nil
dir.files.each do |f|
    ok = true
    cc = 1
    cs = 0
    md = ""
    cl = f.covers ? f.covers.length : 0
    if cl != 1
        ok = false
        cc = cl
    end
    if f.covers
        f.covers.each do |cv|
            if cmd5
                if cv.md5sum != cmd5
                    md = "Y"
                end
            else
                cmd5 = cv.md5sum.dup
            end
            if cv.size > 102400
                ok = false
                if (cv.size > cs)
                    cs = cv.size
                end
            end
        end
    end
    wout << [f.directory,f.base,cc,cs,md]  unless ok
end

ws12.write_col(2,0,wout.sort_by {|r| [r[0],r[1]] })

puts "Check 13: Multi-composers"

wout = Array.new
ws13 = xls.add_worksheet("13 Composers")
ws13.write(0,0,"Composer combinations")
ws13.write_row(1,0,["Directory", "Combo","Artist","Album"])



albs.each_value do |a|
    comps = Hash.new(0)
    alb = nil
    art = nil
    dirx = nil
    a.each do |f|
        comps[f.composer] += 1
        dirx = f.directory
        alb = f.album unless alb
        art = f.albumartist unless art
    end
    cs = ""
    comps.invert.sort.reverse.map do |t,c|
        cs = cs + "_" + (c ? c : "")
    end
    cs = cs[1..-1]  
    #out[cs] += 1
    wout << [dirx,cs,alb,art]  
end

ws13.write_col(2,0,wout.sort_by{|r| [r[0]]})

puts "Check 14: Genres"

wout = Array.new
ws14 = xls.add_worksheet("14 - Genres")
ws14.write(0,0,"Files with unwanted genres")
ws14.write_row(1,0,["Directory", "File","Genre"])

dir.files.each do |f|
    unless ["Childrens","Classical","Folk","Humour","Jazz","Rock","Spoken","Xmas","Blues","Soundtrack"].include? f.genre 
        wout << [f.directory,f.base,f.genre]
    end

end

ws14.write_col(2,0,wout.sort_by {|r| [r[0],r[1]] })

puts "Check 15: Titles"

wout = Array.new
ws15 = xls.add_worksheet("15 - Titles")
ws15.write(0,0,"Files that Picard has previously messed up titles for")
ws15.write_row(1,0,["Directory", "File","Album"])



albs.each_value do |a|
    comps = Hash.new
    a.each do |f|
        comps[f.composer] = true
    end
    a.each do |f|
        chg = ""
        if f.album=~/^\w*: .*/
            if (comps.size == 1)
                comp = comps.keys[0]
                if f.album=~/#{comp}: .*/
                    chg = f.album.sub(/^\w*: /,'')
                end
            end
            wout << [f.directory,f.base,f.album,chg]
        end
    end
end


ws15.write_col(2,0,wout.sort_by {|r| [r[0],r[1]] })



puts "Check 16: Multi-valued Tags"


wout = Array.new
ws16 = xls.add_worksheet("16 - Multivalued tags")
ws16.write(0,0,"Files with tags with more than one value")
ws16.write_row(1,0,["Directory", "File","Tag"])

dir.files.each do |f|
    
    f.metadata.tags.each_value do |tag|
        if tag.values.length > 1
            wout << [f.directory,f.base,tag.name]
        end
    end
end

ws16.write_col(2,0,wout.sort_by {|r| [r[0],r[1]] })


puts "Check 17: Collisions on new path"

wout = Array.new
filecount = Hash.new
ws17 = xls.add_worksheet("17 - Collisions")
ws17.write(0,0,"Files which will get moved to the same location")
ws17.write_row(1,0,["Directory", "File","New Location"])

dbgct = 0

albs = Hash.new
dir.files.each do |f|
    k = (f.release ? f.release : "") + (f.album ? f.album : "")
    if albs[k]
        albs[k] << f
    else
        albs[k] = [f]
    end
end

puts "We have #{albs.size} albums"

albs.each_value do |a|
    
    dbgct = dbgct + 1
    
    comps = Hash.new(0)
    a.each do |f|
        comps[f.composer] += 1
    end
    cs = ""
    compsa = comps.to_a
    compsa.sort_by{|e| "#{e[0]}"}.sort_by{|e| -e[1]}.each do |f|
        c = f[0]
        cs = cs + "_" + (c ? c : "")
    end
    if comps.length > 4
        cs = "Various"
    else
        cs = cs[1..-1]
        cs = "" unless cs
        if cs[0] == "_" then cs = cs[1..-1]  end
        if cs[-1] == "_" then cs = cs[0..-2] end
    end

    a.each do |g|
        f = g
        newdest = ""
        topm = f.directory.match("flac\/+(.+?)\/")
        if topm then topdir = topm[1] else topdir = "" end
        nextm = f.directory.match("flac\/+(.+?)\/+(.+?)\/")
        if nextm && nextm.length > 2 then nextdir = nextm[2] else nextdir = "" end

        unless f.genre 
            puts ("#{f.directory}/#{f.base} genre missing")
#            f.set_genre ""
        end
    
        unless f.album 
            puts ("#{f.directory}/#{f.base} album missing") 
#          f.set_album "" 
        end
        unless f.title 
            puts ("#{f.directory}/#{f.base} title missing") 
 #           f.set_title  "" 
        end
        unless f.albumartist 
            puts ("#{f.directory}/#{f.base} albumartist missing") 
 #           f.set_albumartist  "" 
        end
        unless f.track 
            puts ("#{f.directory}/#{f.base} track missing")
#            f.set_track  "" 
        end

        sanalbum = (f.album ? f.album : "").sanitise
        sanalbumartist = (f.albumartist ? f.albumartist : "").sanitise
        santrack = (f.track ? f.track : "").sanitise
        sanartist = (f.artist ? f.artist : "").sanitise
        santitle = (f.title ? f.title : "").sanitise

        if topdir == "classical"
            if nextdir == "boxsets"
                newdest = "#{topdir}/#{nextdir}/#{sanalbum}/#{santrack}_#{santitle}"
            else
                newdest = "#{topdir}/#{cs.sanitise}/#{sanalbumartist}/#{sanalbum}/#{santrack}_#{f.santitle}"
            end
        else
            unless f.albumartist && f.album && f.track && f.title && topdir
                puts "oops"
            end
            
            newdest = "#{topdir}/#{sanalbumartist}/#{sanalbum}/#{santrack}_#{santitle}"
        end 
        if filecount[newdest] 
            filecount[newdest.dup] = filecount[newdest.dup] << f.dup
        else
            filecount[newdest.dup] = [f.dup]
        end 
    end

    #if (dbgct % 100 == 0) then puts "#{dbgct}/#{albs.size} albums processed" end
end

puts "#{filecount.size} combinations to process"
dbgct = 0

filecount.each do |dest, fs|
    dbgct = dbgct + 1
    if fs.length > 1
        fs.each do |f|
            wout << [f.directory,f.base,dest]
        end
    end
    #if (dbgct % 100 == 0) then puts "#{dbgct}/#{filecount.size} files processed and #{wout.size} duplicates" end

end

puts "#{wout.size} duplicates"

ws17.write_col(2,0,wout.sort_by {|r| [r[2],r[0],r[1]] })



puts "Check 18: New paths"

wout = Array.new
ws18 = xls.add_worksheet("18 - New")

newdirs = Hash.new
filecount.each_key do |k|
    d = File.dirname(k)
    newdirs[d] = d
end

newdirs.each_key { |d| wout << [d] }

ws18.write_col(0,0,wout.sort_by {|r| [r[0]] })

if (move)
    mf = File.open(movepath,"w")
    filecount.each do |dest, fs|
        f = fs[0]
        source = f.name
        if (dir.pathname + dest).length > 248
            mdest = (dir.pathname + "/" + dest)[0..247] + ".flac"
        else
            mdest = dir.pathname + "/" + dest + ".flac"
        end
        mdir = Pathname.new(mdest).dirname
        if (source != mdest)
            mf.write("mkdir -p #{Shellwords.escape(mdir)}\n")
            mf.write("mv #{Shellwords.escape(source)} #{Shellwords.escape(mdest)}\n")
        end
    end
end

puts "Check 19: Long names"

wout = Array.new
ws19 = xls.add_worksheet("19 - Long")

longalb = Hash.new
longtit = Hash.new

dir.files.each do |f|
    if f.album && f.album.length > 120
        longalb[f.album] = f
    end
    if f.title && f.title.length > 120
        longtit[f.title] = f
    end
end

longalb.each {|a,f| wout << [Pathname.new(f.name).dirname.to_s, a, ""]}
longtit.each {|t,f| wout << [f.name,"",t]}

#newdirs.each_key { |d| wout << [d] }

ws19.write_col(0,0,wout.sort_by {|r| [r[0]] })



=begin
To do:
track has exactly one front cover
same cover for all tracks in album
cover size less than 100k
Count of albums split by composer count
genre check
title has form "composer:"
Multi-valued tags

**testing to here**





moving scheme - create mock-up and check no clashes

=end


xls.close

puts "All done"
