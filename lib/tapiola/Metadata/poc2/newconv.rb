
require 'rubygems'
require 'fileutils'
require 'shellwords'




genres = Hash.new

#IO.popen("id3v2 -L").each_line do |g|
 # genres[g[5..-1].chomp] = g[0..2].dup
#end



list = Dir["/home/james/Music/flac/**/*.flac"]

puts list.size.to_s + " files to convert"

n = 0

list.each do |flacname|

   n = n + 1
   blurb = "Converting " + n.to_s + " of " + list.size.to_s

   #puts flacname
   mp3name = (flacname[0..-5] + "mp3").sub("/home/james/Music/flac","/home/james/Music/mp3/converted")
   
   blurb += " : " + mp3name
   
   if File.exist?(mp3name)
	   if File.mtime(mp3name) < File.mtime(flacname)
		   puts " mp3:" + mp3name +" "+ File.mtime(mp3name).to_s + " source:" + flacname + " " + File.mtime(flacname).to_s
		   process = true
		   File.delete(mp3name)
	   else
		   process = false
	   end
  else
	  process = true
  end
  
   if process
	   
     #puts blurb
   
     shflacname = Shellwords.escape(flacname)
     shmp3name = Shellwords.escape(mp3name)
   
   

     #puts "from " + shflacname
   
     i = IO.popen("metaflac --list " + shflacname)
     tags = i.readlines
     i.close
   
        
     x = tags.join.match(/.*TRACKNUMBER=(.*)/i)
     if x != nil then track = x[1] else track = "" end
     x = tags.join.match(/.*ARTIST=(.*)/i)
     if x != nil then artist = x[1] else artist = "" end
     x = tags.join.match(/.*ALBUM=(.*)/i)
     if x != nil then album = x[1] else album = "" end
     x = tags.join.match(/.*TITLE=(.*)/i)
     if x != nil then title = x[1] else title = "" end
     x = tags.join.match(/.*GENRE=(.*)/i)
     if x != nil then genre = x[1] else genre = "" end
     x =  tags.join.match(/.*COMPOSER=(.*)/i)
     if x != nil then composer = x[1] else composer = "" end
  
     #puts ":" + genre + ":"
     #genreno = genres[genre]
     #if (genreno == nil) then genreno = "13" end
   
   
   
     cmd_decode = "flac  -d -F " + shflacname + " -o temp.wav"
     cmd_encode = "lame  -S --preset standard temp.wav " + shmp3name
     cmd_id3 = "id3v2  --TCOM " + Shellwords.escape(composer) + " -a " + Shellwords.escape(artist) 
     cmd_id3 += " -A "  +Shellwords.escape(album) + " --TCON " + Shellwords.escape(genre)  + " -t " + Shellwords.escape(title) 
     cmd_id3 += " -T " + track + " " + shmp3name
   
     dir = mp3name[0...(mp3name.rindex('/') )]
      
     FileUtils.makedirs(dir)
     if File.exist?("temp.wav") then File.delete("temp.wav") end
   
     puts ":" + cmd_decode + ":"
     puts ":" + cmd_encode + ":"
     puts ":" + cmd_id3  + ":"
     
     
     system(cmd_decode)
     system(cmd_encode)
     system(cmd_id3)



   
   end
      
end