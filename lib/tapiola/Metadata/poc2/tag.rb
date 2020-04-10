require 'taglib'
require 'digest'



module GenericTag



    class SingleTag
        attr_reader :name, :values
        def initialize(name,values)
            if values.is_a? Array
                @values = values
            else
                @values = [values]   
            end
            @name = name
        end
        def value
            if @values
                @values[0]
            else
                return nil
            end
        end
        def set(values)
            if values.is_a? Array
                @values = values
            else
                @values = [values]   
            end
        end
        def append(value)
            @values << value
        end
        def to_s
            self.value
        end
        def multivalued?
            return (@values.length > 1)
        end
    end


    class Picture
        attr_reader :type, :description, :mimetype, :data, :colordepth, :width, :height, :numcolors, :md5sum
        def initialize(t,d,m,data = nil, c = nil, w = nil, h = nil, n = nil, md5only = true)
            @type = t
            @description = d
            @mimetype = m
            @data = data unless md5only
            @colordepth = c 
            @width = w 
            @height = h 
            @numcolors = n
            #self.create_md5sum(data) 
        end
        def create_md5sum(data)
            @md5sum = Digest::MD5.hexdigest(data)
        end
    end


    class Metadata

               
        @@mappingsall = <<~IMDONE
        album,TALB,ALBUM
        albumsort,TSOA,ALBUMSORT
        title,TIT2,TITLE
        titlesort,TSOT,TITLESORT
        work,TXXX:WORK,WORK
        artist,TPE1,ARTIST
        artistsort,TSOP,ARTISTSORT
        albumartist,TPE2,ALBUMARTIST
        albumartistsort,TSO2,ALBUMARTISTSORT
        artists,TXXX:Artists,ARTISTS
        date,TDRC id3v24,DATE
        composer,TCOM,COMPOSER
        composersort,TSOC,COMPOSERSORT
        lyricist,TEXT,LYRICIST
        writer,TXXX:Writer,WRITER
        conductor,TPE3,CONDUCTOR
        label,TPUB,LABEL
        movement,MVNM,MOVEMENTNAME
        movementnumber,MVIN,MOVEMENT
        movementtotal,MVIN,MOVEMENTTOTAL
        showmovement,TXXX:SHOWMOVEMENT,SHOWMOVEMENT
        grouping,TIT1,GROUPING
        subtitle,TIT3,SUBTITLE
        discsubtitle,TSST,DISCSUBTITLE
        tracknumber,TRCK,TRACKNUMBER
        totaltracks,TRCK,TRACKTOTAL
        discnumber,TPOS,DISCNUMBER
        totaldiscs,TPOS,DISCTOTAL
        compilation,TCMP,COMPILATION
        comment:description,COMM:description,COMMENT
        genre,TCON,GENRE
        releasestatus,TXXX:MusicBrainz Album Status,RELEASESTATUS
        releasetype,TXXX:MusicBrainz Album Type,RELEASETYPE
        releasecountry,TXXX:MusicBrainz Album Release Country,RELEASECOUNTRY
        barcode,TXXX:BARCODE,BARCODE
        isrc,TSRC,ISRC
        asin,TXXX:ASIN,ASIN
        musicbrainz_recordingid,UFID://musicbrainz.org,MUSICBRAINZ_TRACKID
        musicbrainz_trackid,TXXX:MusicBrainz Release Track Id,MUSICBRAINZ_RELEASETRACKID
        musicbrainz_albumid,TXXX:MusicBrainz Album Id,MUSICBRAINZ_ALBUMID
        musicbrainz_originalalbumid,TXXX:MusicBrainz Original Album Id,MUSICBRAINZ_ORIGINALALBUMID
        musicbrainz_artistid,TXXX:MusicBrainz Artist Id,MUSICBRAINZ_ARTISTID
        musicbrainz_originalartistid,TXXX:MusicBrainz Original Artist Id,MUSICBRAINZ_ORIGINALARTISTID
        musicbrainz_albumartistid,TXXX:MusicBrainz Album Artist Id,MUSICBRAINZ_ALBUMARTISTID
        musicbrainz_releasegroupid,TXXX:MusicBrainz Release Group Id,MUSICBRAINZ_RELEASEGROUPID
        musicbrainz_workid,TXXX:MusicBrainz Work Id,MUSICBRAINZ_WORKID
        musicbrainz_trmid,TXXX:MusicBrainz TRM Id,MUSICBRAINZ_TRMID
        musicbrainz_discid,TXXX:MusicBrainz Disc Id,MUSICBRAINZ_DISCID
        acoustid_id,TXXX:Acoustid Id,ACOUSTID_ID
        acoustid_fingerprint,TXXX:Acoustid Fingerprint,ACOUSTID_FINGERPRINT
        website,WOAR,WEBSITE
        key,TKEY,KEY
        replaygain_album_gain,TXXX:REPLAYGAIN_ALBUM_GAIN,REPLAYGAIN_ALBUM_GAIN
        replaygain_album_peak,TXXX:REPLAYGAIN_ALBUM_PEAK,REPLAYGAIN_ALBUM_PEAK
        replaygain_album_range,TXXX:REPLAYGAIN_ALBUM_RANGE,REPLAYGAIN_ALBUM_RANGE
        replaygain_track_gain,TXXX:REPLAYGAIN_TRACK_GAIN,REPLAYGAIN_TRACK_GAIN
        replaygain_track_peak,TXXX:REPLAYGAIN_TRACK_PEAK,REPLAYGAIN_TRACK_PEAK
        replaygain_track_range,TXXX:REPLAYGAIN_TRACK_RANGE,REPLAYGAIN_TRACK_RANGE
        replaygain_reference_loudness,TXXX:REPLAYGAIN_REFERENCE_LOUDNESS,REPLAYGAIN_REFERENCE_LOUDNESS
        IMDONE
        
        @@mappings = { :flac => Hash.new, :id3v24 => Hash.new}

        @@mappingsall.split("\n").each do |line|
            fields = line.split(",")
            @@mappings[:flac][fields[0].to_sym] = fields[2].to_sym
            @@mappings[:id3v24][fields[0].to_sym] = fields[1].to_sym
        end
    

        @@int2flac = @@mappings[:flac]
        
      
        #@@flac2int = @@mappings[:flac].invert

        @@int2flac.each_key do |k| 
            define_method "#{k}".to_sym do
                v = @tags[@@mappings[@type][k]]
                v ? v.values : []
            end
            define_method "#{k}=".to_sym do |t| 
                self.set(@@mappings[@type][k],t)
            end
        end

        @@picnum2name = {
            0 => :other,1 => :file_icon,2 => :other_file_icon,3 => :front_cover,
            4 => :back_cover,5 => :leaflet,6 => :media,7 => :lead_artist,8 => :artist,
            9 => :conductor,10 => :band,11 => :composer,12 => :lyricist,
            13 => :recording_location,14 => :during_recording,15 => :during_performance,
            16 => :screen_capture,17 => :bright_fish,18 => :illustration,
            19 => :artist_logotype,20 => :publisher_studio_logotype
        }

        @@picname2num = @@picnum2name.invert

        attr_accessor :pics, :tags

        def initialize(type)
            @tags = Hash.new
            @type = type.to_sym
            @pics = Hash.new
        end
        def set(n,v)
            @tags[n] = SingleTag.new(n,v)
        end
        def append(n,v)
            if @tags[n]
                @tags[n].append(v)
            else
                @tags[n] = SingleTag.new(n,v)
            end
        end
        def get(t)
            @tags[t]
        end
        def each
            @tags.each {|k,v| yield(k,v)}
        end
        def each_tag
            @tags.each_value {|v| yield(v)}
        end
        def self.from_flac(file, md5only = true)
            ts = Metadata.new(:flac)
            TagLib::FLAC::File.open(file) do |f|
                f.xiph_comment.field_list_map.each do |tag,value|
                    ts.append(tag.to_sym,value.dup)
                end
                f.picture_list.each do |p|
                    px = Picture.new(p.type,p.description,p.mime_type,p.data,p.color_depth,p.width,p.height,p.num_colors,md5only)
                    px.create_md5sum(p.data)
                    if ts.pics[@@picnum2name[p.type]]
                        ts.pics[@@picnum2name[p.type]] << px
                    else
                        ts.pics[@@picnum2name[p.type]] = [px]
                    end
                end
            end
            return ts
        end
        def to_flac(file, art=false)
            f = TagLib::FLAC::File.open(file) do |f| 
                self.each_tag do |tag|
                    flac_name = tag.name.to_s
                    if flac_name 
                        f.xiph_comment.remove_fields(flac_name)
                        tag.values.each do |value|
                           f.xiph_comment.add_field(flac_name,value,false)
                        end
                    end
                end
                if (art)
                #TODO add picture saving code
                #only save if data isn't nil
                end
                f.save
            end
        end
        def self.from_mp3(file,md5only = true)
        end
        def to_mp3(file,art = false)
        end
    end
end



