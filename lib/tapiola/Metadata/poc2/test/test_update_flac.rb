require 'minitest/autorun'
require_relative '../tag.rb'

DATA = Dir.pwd+"/lib/tapiola/Metadata/poc2/test/"

class TestUpdateFlac < MiniTest::Test

    def setup
    end

    def test_basic_reading
        GenericTag::Metadata.update_tags("#{DATA}data/album1_track2.flac",{:musicbrainz_recordingid => "alb1_track_2"})
        @flac1 = GenericTag::Metadata.from_flac("#{DATA}data/album1_track2.flac")
        assert_equal ['alb1_track_2'], @flac1.musicbrainz_recordingid 
        assert_equal ['alb1_track_2'], @flac1.tags[:MUSICBRAINZ_TRACKID].values

        GenericTag::Metadata.update_tags("#{DATA}data/album1_track2.flac",{:MUSICBRAINZ_TRACKID => "alb1_track_1"})
        @flac2 = GenericTag::Metadata.from_flac("#{DATA}data/album1_track2.flac")
        assert_equal ['alb1_track_1'], @flac2.tags[:MUSICBRAINZ_TRACKID].values
        assert_equal ['alb1_track_1'], @flac2.musicbrainz_recordingid 
        
    end

    def teardown
    end

end
