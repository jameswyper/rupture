require 'minitest/autorun'
require 'fileutils'
require_relative '../tag.rb'

DATA = Dir.pwd+"/lib/tapiola/Metadata/poc2/test/"

class TestReadFlac < MiniTest::Test

    def setup
        FileUtils.cp("#{DATA}data/empty.flac","#{DATA}data/flacwrite1.flac")
        @flac1 = GenericTag::Metadata.from_flac("#{DATA}data/pic1.flac",false)

        FileUtils.cp("#{DATA}data/empty.flac","#{DATA}data/flacwrite2.flac")
        @flac2 = GenericTag::Metadata.from_flac("#{DATA}data/pic2.flac",false)

        @flac1.artist = "artist1"
        @flac2.artist = "artist2"
        
        @flac1.to_flac("#{DATA}data/flacwrite1.flac",true)
        @flac2.to_flac("#{DATA}data/flacwrite2.flac",true)

    end

    def test_write

    end

    def teardown
        #FileUtils.rm("#{DATA}data/flacwrite1.flac")
        #FileUtils.rm("#{DATA}data/flacwrite2.flac")
    end

end

