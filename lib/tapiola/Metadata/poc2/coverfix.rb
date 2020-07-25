require_relative 'tag'
require 'fileutils'
require 'pathname'
require 'rmagick'
include Magick

MAXSIZE = 102400
MAXDIM = 500

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
    def initialize(f, md5only = true)
        @name = f
        @metadata = GenericTag::Metadata.from_flac(f, md5only)
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


dir = Directory.new(ARGV[0])
puts "Scanning"
dir.scan do |file,count,total|
    if (count % 20 == 0) then puts "#{count}/#{total}" end
end


puts "Scanning done and #{dir.files.length} files found"

dir.files.each do |f|
    wf = nil
    if f.covers
        f.covers.each do |cv|
            if (cv.size > MAXSIZE) || (cv.width > MAXDIM) || (cv.height > MAXDIM)
                puts "#{f.name} needs attention"
                wf = MusicFile.new(f.name,false)
                wf.covers.each do |wcv|
                    if (wcv.size > MAXSIZE) || (wcv.width > MAXDIM) || (wcv.height > MAXDIM)
                        #wcv.mimetype
                        im = Image.from_blob(wcv.data)[0]
                        l = wcv.height > wcv.width ? wcv.height : wcv.width
                        scale = 1
                        if (l > MAXDIM) 
                            scale = (MAXDIM * 1.0 / l)
                            ims = im.resize(scale)   
                        else
                            ims = im
                        end
                        q = 101
                        s = wcv.size
                        while (s > MAXSIZE) do
                            q = q - 1
                            d = ims.to_blob do
                                 self.format = "jpg" 
                                 self.quality = q 
                            end
                            s = d.to_s.size
                            #puts "q:#{q} s:#{s}"
                        end
                        nh = (wcv.height * scale).to_i
                        nw = (wcv.width * scale).to_i
                        nm = "image/jpeg"
                        puts "Width      old: #{wcv.width} new: #{nw}"
                        puts "Height     old: #{wcv.height} new: #{nh}"
                        puts "Mimetype   old: #{wcv.mimetype} new: #{nm}"
                        puts "Size       old: #{wcv.size} new: #{s}"
                        puts "Quality    #{q}"
                        wcv.height = nh
                        wcv.width = nw
                        wcv.mimetype = nm
                        wcv.size = s
                        wcv.data = d
                    end
                end
            end
        end
    end
    if wf
        wf.metadata.to_flac(f.name,true)
    end
end

