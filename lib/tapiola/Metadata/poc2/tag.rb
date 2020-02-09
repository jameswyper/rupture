require 'taglib'

module GenericTag

    MAPPINGS =  {
                 flac: {album: "ALBUM", albumsort: "ALBUMSORT",
                        title: "TITLE", titlesort: "TITLESORT",
                        work: "WORK", artist: "ARTIST", artistsort: "ARTISTSORT",
                        albumartist: "ALBUMARTIST", albumartistsort: "ALBUMARTISTSORT",
                        artists: "ARTISTS", date: "DATE"
                    
                       },
                 id3v2: {} 
                }

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
        def multivalued?
            return (@values.length > 1)
        end
    end

    class TagSet
        @@int2flac = MAPPINGS(:flac)
        @@flac2int = MAPPINGS(:flac).invert
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
            @tags[t.name]
        end
        def self.from_flac(file)
            ts = TagSet.new
            TagLib::FLAC:File.open(file) do |f|
                f.xiph_comment.field_list_map.each do |tag,value|
                    ts.add(@@flac2int[tag],value)
                end
            end
            return ts
        end
    end
end

z = GenericTag::TagSet.from_flac("/home/james/Music/flac/heather/KT_Tunstall-Eye_to_the_Telescope/09.Suddenly_I_See.flac")

puts z.get(:album).value