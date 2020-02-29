require 'taglib'




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
        def to_s
            self.value
        end
        def multivalued?
            return (@values.length > 1)
        end
    end

    class TagSet
        
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
        @@flac2int = @@mappings[:flac].invert

        @@int2flac.each_key do |k| 
            define_method "#{k}".to_sym do 
                @tags[k] 
            end
            define_method "set_#{k}".to_sym do |t| 
                @tags[k] = t 
            end
        end

        def initialize
            @tags = Hash.new
        end
        def set(t)
            @tags[t.name] = t
        end
        def add(n,v)
            @tags[n] = SingleTag.new(n,v)
        end
        def get(t)
            @tags[t]
        end
        def each
            @tags.each {|k,v| yield(k,v)}
        end
        def self.from_flac(file)
            ts = TagSet.new
            TagLib::FLAC::File.open(file) do |f|
                f.xiph_comment.field_list_map.each do |tag,value|
                    ts.add(@@flac2int[tag.to_sym],value)
                end
            end
            return ts
        end
    end
end

z = GenericTag::TagSet.from_flac("/media/james/karelia/Music/flac/heather/KT_Tunstall-Eye_to_the_Telescope/09.Suddenly_I_See.flac")
z.each do |k,v|
    puts k.to_s, v.to_s
end

puts z.get(:album)
