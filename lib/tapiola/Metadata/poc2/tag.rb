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
            if value.is_a? Array
                @values.concat(value)
            else
                @values << value
            end
        end
        def to_s
            self.value
        end
        def multivalued?
            return (@values.length > 1)
        end
    end


    class Picture
        attr_accessor :type, :description, :mimetype, :data, :colordepth, :width, :height, :numcolors, :size
        attr_reader :md5sum
        def initialize(t,d,m,data = nil, c = nil, w = nil, h = nil, n = nil, md5only = true)
            @type = t
            @description = d
            @mimetype = m
            @data = data unless md5only
            @colordepth = c 
            @width = w 
            @height = h 
            @numcolors = n
            @size = data.to_s.size
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
        date,TDRC,DATE
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
        discnumber,TPOS,DISCNUMBER
        compilation,TCMP,COMPILATION
        comment,COMM:description,COMMENT
        genre,TCON,GENRE
        releasestatus,TXXX:MusicBrainz Album Status,RELEASESTATUS
        releasetype,TXXX:MusicBrainz Album Type,RELEASETYPE
        releasecountry,TXXX:MusicBrainz Album Release Country,RELEASECOUNTRY
        barcode,TXXX:BARCODE,BARCODE
        isrc,TSRC,ISRC
        asin,TXXX:ASIN,ASIN
        musicbrainz_recordingid,UFID:http://musicbrainz.org,MUSICBRAINZ_TRACKID
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
        
#       removed the following because they mess up the id3 tag
#       totaldiscs,TPOS,DISCTOTAL
#       totaltracks,TRCK,TRACKTOTAL

        @@mappings = { :flac => Hash.new, :id3v24 => Hash.new}

        @@mappingsall.split("\n").each do |line|
            fields = line.split(",")
            @@mappings[:flac][fields[0].to_sym] = fields[2].to_sym
            @@mappings[:id3v24][fields[0].to_sym] = fields[1].to_sym
        end
        
        @@mappings_2int = Hash.new
        @@mappings.each do |type, mapping|
            @@mappings_2int[type] = @@mappings[type].invert
        end

        @@int2flac = @@mappings[:flac]
        
      
        #@@flac2int = @@mappings[:flac].invert

        @@int2flac.each_key do |k| 
            define_method "#{k}".to_sym do
                v = @tags[@@mappings[@type][k]]
                v ? v.values : []
            end
#            self.instance_variable_set("@#{k}".to_sym,"")
#            define_method "set_#{k}".to_sym do |t| 
#                self.set(@@mappings[@type][k],t)
#            end
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
        attr_reader :type

        def initialize(type)
            @tags = Hash.new
            @type = type.to_sym
            @pics = Hash.new
            raise "incorrect type #{@type}" unless [:flac,:id3v24].include? @type
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
        
        def add_pic(p)
            if @pics[@@picnum2name[p.type]]
                @pics[@@picnum2name[p.type]] << p
            else
                @pics[@@picnum2name[p.type]] = [p]
            end
        end


        def self.convert(type,old_ts)
            t = type.to_sym
            new_ts = Metadata.new(t)
            new_ts.pics = old_ts.pics.dup
            old_ts.tags.each do |name,tag|
                old_int_name = @@mappings_2int[old_ts.type][name]
                if old_int_name
                    new_name = @@mappings[new_ts.type][old_int_name]
                    new_ts.append(new_name,tag.values)
                end
            end
            return new_ts
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
                    ts.add_pic(px)
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
                    f.remove_pictures
                    @pics.each_value do |pa|
                        pa.each do |p|
                            if p.data
                                pic = TagLib::FLAC::Picture.new
                                pic.data = p.data
                                pic.description = p.description    
                                pic.mime_type = p.mimetype
                                pic.width = p.width
                                pic.height = p.height
                                pic.type = p.type    
                                f.add_picture(pic)
                            end
                        end
                    end
                end
                f.save
            end
        end

        def self.from_mp3(file,md5only = true)
            ts = Metadata.new(:id3v24)
            TagLib::MPEG::File.open(file) do |f|
                f.id3v2_tag.frame_list.each do |frame|
                    case 
                    when (frame.is_a? TagLib::ID3v2::TextIdentificationFrame) && !(frame.is_a? TagLib::ID3v2::UserTextIdentificationFrame)
                        frame.field_list.each do |field|
                            ts.append(frame.frame_id.to_sym,field.dup)
                        end
                    when (frame.is_a? TagLib::ID3v2::AttachedPictureFrame) 
                        px = Picture.new(frame.type,frame.description,frame.mime_type,frame.picture,nil,nil,nil,nil,md5only)
                        px.create_md5sum(frame.picture)
                        ts.add_pic(px)
                    when (frame.is_a? TagLib::ID3v2::UniqueFileIdentifierFrame)
                        ts.append("UFID:#{frame.owner}".to_sym,frame.identifier.dup)
                    when (frame.is_a? TagLib::ID3v2::UserTextIdentificationFrame) 
                        frame.field_list[1..-1].each do |field|
                            ts.append("TXXX:#{frame.field_list[0]}".to_sym, field.dup)
                        end
                    end
                end
            end
            return ts
        end

        def to_mp3(file,art = false)
           f = TagLib::MPEG::File.open(file) do |f| 
                f.strip
                filetag = f.id3v2_tag(true)
                self.each_tag do |tag|
                    id3_name = tag.name.to_s
                    if id3_name
                        if id3_name.start_with?("TXXX")
                            frame = TagLib::ID3v2::UserTextIdentificationFrame.new(TagLib::String::UTF8)
                            frame.description = id3_name[5..-1]
                            if tag.values.length > 0 
                                frame.text = tag.values[0]
                            else
                                frame.text = ""
                            end 
                        else
                            if id3_name.start_with?("UFID")
                                frame = TagLib::ID3v2::UniqueFileIdentifierFrame.new(id3_name[5..-1],tag.values[0])
                            else
                                frame = TagLib::ID3v2::TextIdentificationFrame.new(id3_name, TagLib::String::UTF8)
                                if tag.values.length > 0 
                                    frame.text = tag.values[0]
                                else
                                    frame.text = ""
                                end 
                            end
                        end
                        

                        filetag.add_frame(frame)
                    end
                end
                if (art)
                    filetag.remove_frames("APIC")
                    @pics.each_value do |pa|
                        pa.each do |p|
                            if p.data
                                pic = TagLib::ID3v2::AttachedPictureFrame.new
                                pic.picture = p.data
                                pic.description = p.description    
                                pic.mime_type = p.mimetype
                                pic.type = p.type    
                                filetag.add_frame(pic)
                            end
                        end
                    end
                end
                f.save
            end            
        end

        def self.update_tags(file,tags,type = nil)

            unless type
                type = File.extname(file)
            end
            
            case type
            when :mp3, "mp3", ".mp3"
                m = self.from_mp3(file)
            when :flac, "flac", ".flac"
                m = self.from_flac(file)
            else raise "unsupported type (flac/mp3 only) ", type
            end

            tags.each_key do |k|
                i = @@mappings[m.type][k]
                if i
                    j  = i
                else    
                    j = k
                end
                m.set(j,tags[k])
            end

            case type
            when :mp3, "mp3", ".mp3"
                m.to_mp3(file)
            when :flac, "flac", ".flac"
                m.to_flac(file)
            else raise "unsupported type (flac/mp3 only) #{type}"
            end

        end

    end
end



