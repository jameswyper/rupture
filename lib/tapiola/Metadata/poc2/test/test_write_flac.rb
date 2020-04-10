require 'minitest/autorun'
require 'fileutils'
require_relative '../tag.rb'

DATA = Dir.pwd+"/lib/tapiola/Metadata/poc2/test/"

class TestReadFlac < MiniTest::Test

    def setup
        Fileutils.cp("#{DATA}data/empty.flac","#{DATA}data/flacwrite1.flac")
        @flac1 = GenericTag::Metadata.from_flac("#{DATA}data/flacwrite1.flac")

        Fileutils.cp("#{DATA}data/empty.flac","#{DATA}data/flacwrite2.flac")
        @flac1 = GenericTag::Metadata.from_flac("#{DATA}data/flacwrite2.flac")

    end

    def test_write
 
    end

    def teardown
        #Fileutils.rm("#{DATA}data/flacwrite1.flac")
        #Fileutils.rm("#{DATA}data/flacwrite2.flac")
    end

end

