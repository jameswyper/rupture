

=begin
Tests to do


=end

require 'minitest/autorun'
require_relative '../../lib/tapiola/Metadata/metamb2.rb'
#require 'nokogiri'
#require 'net/http'
#require  'rexml/document'
#require 'pry'





class TestRelease < Minitest::Test
	
			
	def setup

		Meta::MusicBrainz::MBBase.openDatabase(File.expand_path("~/metadbtest.db"))


	end
	

	
	
	def test_simple
		
		q1 = Meta::MusicBrainz::Release.new('64814a3d-f11a-3ad7-9f23-41c68279e0be')
		q2 = Meta::MusicBrainz::Release.new('64814a3d-f11a-3ad7-9f23-41c68279e0bf')
		q3 = Meta::MusicBrainz::Release.new('d8abad24-bcc0-4428-970f-0e226e4ef16d')
		q4 = Meta::MusicBrainz::Release.new('64814a3d-f11a-3ad7-9f23-41c68279e0be')

		refute(q1.cached?,"First hit not cached")
		assert_equal('64814a3d-f11a-3ad7-9f23-41c68279e0be',q1.mbid,"mbid created ok")
		assert_equal('A Night at the Opera',q1.title,"Title correct")

		assert_equal(nil,q2.mbid,"Non-existent mbid can't be found")
		refute(q2.cached?,"Non-existent mbid has null cached")
		
		assert_equal('d8abad24-bcc0-4428-970f-0e226e4ef16d',q3.mbid,"Sheer Heart Attack OK")
		assert_equal('Sheer Heart Attack',q3.title,"Sheer Heart Attack title OK")
		
		assert(q4.cached?,"Second hit cached")
		assert_equal('64814a3d-f11a-3ad7-9f23-41c68279e0be',q1.mbid,"Second Opera mbid created ok")
		assert_equal('A Night at the Opera',q1.title,"Second Opera Title correct")
		
		
	end	

	
	
	def teardown

		File.delete(File.expand_path("~/metadbtest.db"))
		
	end

end


