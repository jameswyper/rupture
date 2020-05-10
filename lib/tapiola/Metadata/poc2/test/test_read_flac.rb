require 'minitest/autorun'
require_relative '../tag.rb'

DATA = Dir.pwd+"/lib/tapiola/Metadata/poc2/test/"

class TestReadFlac < MiniTest::Test

    def setup
        @flac = GenericTag::Metadata.from_flac("#{DATA}data/album1_track1.flac")
    end

    def test_basic_reading
        assert_equal ['alb1_track_1'], @flac.musicbrainz_recordingid 
        assert_equal ['alb1_track_1'], @flac.tags[:MUSICBRAINZ_TRACKID].values
        assert_equal [], @flac.artist
        assert_nil @flac.tags[:ARTIST]
    end

    def teardown
    end

end

class TestReadFlacPicture < MiniTest::Test
    def setup
        @flac1 = GenericTag::Metadata.from_flac("#{DATA}data/pic1.flac")
        @flac2 = GenericTag::Metadata.from_flac("#{DATA}data/pic2.flac")
        @flac3 = GenericTag::Metadata.from_flac("#{DATA}data/pic3.flac")
    end

    def test_basic_reading
        assert_equal ['alb1_track_1'], @flac1.musicbrainz_recordingid 
        assert_equal ['alb1_track_1'], @flac1.tags[:MUSICBRAINZ_TRACKID].values
        assert_equal [], @flac1.artist
        assert_nil @flac1.tags[:ARTIST]

        assert_equal 2, @flac3.pics[:front_cover].size
        assert_equal 1, @flac1.pics[:front_cover].size
        assert_equal 1, @flac2.pics[:front_cover].size
        assert_equal 1, @flac2.pics[:back_cover].size
        assert_equal 'image/jpeg', @flac1.pics[:front_cover][0].mimetype
        assert_equal 1, @flac1.pics.size
        assert_equal 2, @flac2.pics.size
        assert_equal 2, @flac3.pics.size
        assert_nil @flac1.pics[:artist] 
        assert_equal 'ecb1d0aa528309d4c5eefd0d05e27c8e', @flac2.pics[:front_cover][0].md5sum
        assert_equal 'b05088ab5b8c5a1a8d585132652760cf', @flac2.pics[:back_cover][0].md5sum

        assert_equal 46993,@flac2.pics[:front_cover][0].size

    end

    def teardown
    end
end

class TestDummy < MiniTest::Test
    def setup
    end

    def test_something
    end

    def teardown
    end
end