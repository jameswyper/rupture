require 'minitest/autorun'
require 'fileutils'
require_relative '../tag.rb'

DATA = Dir.pwd+"/lib/tapiola/Metadata/poc2/test/"

class TestReadFlac < MiniTest::Test

    def setup
        FileUtils.cp("#{DATA}data/empty.flac","#{DATA}data/flacwrite1.flac")
        @flac1 = GenericTag::Metadata.from_flac("#{DATA}data/pic1.flac",false)

        FileUtils.cp("#{DATA}data/empty.flac","#{DATA}data/flacwrite2.flac")
        @flac2 = GenericTag::Metadata.from_flac("#{DATA}data/pic1.flac",false)
        @flac3 = GenericTag::Metadata.from_flac("#{DATA}data/pic2.flac",false)
        @flac2.add_pic(@flac3.pics[:back_cover][0])
        @flac1.artist = "artist1"
        @flac2.artist = "artist2"
        
        @flac1.to_flac("#{DATA}data/flacwrite1.flac",true)
        @flac2.to_flac("#{DATA}data/flacwrite2.flac",true)

    end

    def metaflac_tags(f)
        `metaflac --list #{f} | grep  '^    comment' | awk '{print $2}' | sort`
    end

    def metaflac_pic(f,b,g)
        `metaflac --block-number=#{b} --export-picture-to=- #{f} | diff #{g} -`
    end

    def test_write
        l = metaflac_tags("#{DATA}data/flacwrite1.flac").split("\n")
        assert_equal 'ARTIST=artist1',l[0]
        assert_equal 'MUSICBRAINZ_ALBUMID=alb1',l[1]
        assert_equal 'MUSICBRAINZ_TRACKID=alb1_track_1',l[2]
        
        p = metaflac_pic("#{DATA}data/flacwrite1.flac",2,"#{DATA}data/bbs1.jpg")
        assert_empty p

        l = metaflac_tags("#{DATA}data/flacwrite2.flac").split("\n")
        assert_equal 'ARTIST=artist2',l[0]
        assert_equal 'MUSICBRAINZ_ALBUMID=alb1',l[1]
        assert_equal 'MUSICBRAINZ_TRACKID=alb1_track_1',l[2]
        
        p = metaflac_pic("#{DATA}data/flacwrite2.flac",2,"#{DATA}data/bbs1.jpg")
        assert_empty p

        p = metaflac_pic("#{DATA}data/flacwrite2.flac",3,"#{DATA}data/bbs2.jpg")
        assert_empty p


    end

    def teardown
        FileUtils.rm("#{DATA}data/flacwrite1.flac")
        FileUtils.rm("#{DATA}data/flacwrite2.flac")
    end

end

