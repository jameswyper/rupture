

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
	

	
	
	def test_release
		
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
		assert_equal('64814a3d-f11a-3ad7-9f23-41c68279e0be',q4.mbid,"Second Opera mbid created ok")
		assert_equal('A Night at the Opera',q4.title,"Second Opera Title correct")
		
		
	end	

	
	def test_medium
		
		q1 = Meta::MusicBrainz::Release.new('f9dffcec-f9ae-3320-a003-b87c1e995885')
		q2 = Meta::MusicBrainz::Release.new('64814a3d-f11a-3ad7-9f23-41c68279e0be')
		q3 = Meta::MusicBrainz::Release.new('f9dffcec-f9ae-3320-a003-b87c1e995885')
		
		assert_equal(2,q1.media.size,"Two media for Live Killers - xml")
		assert_equal(1,q2.media.size,"One medium for NatO")
		assert_equal(2,q3.media.size,"Two media for Live Killers - database")
		refute(q1.medium(1).cached?,"Live killers xml not cached")
		assert(q3.medium(1).cached?,"Live killers database cached")
		refute(q1.medium(2).cached?,"Live killers xml not cached")
		assert(q3.medium(2).cached?,"Live killers database cached")
		
		assert_equal(q1.mbid,q1.medium(1).release.mbid,'Killers from xml: walking backwards works medium 1')
		assert_equal(q1.mbid,q1.medium(2).release.mbid,'Killers from xml: walking backwards works medium 2')
		assert_equal(q2.mbid,q2.medium(1).release.mbid,'Opera from xml: walking backwards works medium 1')
		assert_equal(q3.mbid,q3.medium(1).release.mbid,'Killers from db: walking backwards works medium 1')
		assert_equal(q3.mbid,q3.medium(2).release.mbid,'Killers from db: walking backwards works medium 2')
		
	end
	
	
	def test_discIDs
	end
	
	def test_tracks
		
		q1 = Meta::MusicBrainz::Release.new('f9dffcec-f9ae-3320-a003-b87c1e995885')
		q2 = Meta::MusicBrainz::Release.new('f9dffcec-f9ae-3320-a003-b87c1e995885')

		assert_equal(13,q1.medium(1).tracks.size,"Killers disc 1 has 13 tracks - xml")
		assert_equal(9,q1.medium(2).tracks.size,"Killers disc 2 has 9 tracks - xml")
		assert_equal('4540b827-cce0-4f45-b3b9-f7cc09489584',q1.medium(1).track(10).recording)
		assert_equal('5f5879b4-78d5-481f-a007-b9eb34cba750',q1.medium(1).track(1).recording)
		assert_equal('6960710a-5120-420a-8e6e-acfa98db690f',q1.medium(2).track(5).recording)
		assert_equal(q1.mbid,q1.medium(1).track(1).medium.release.mbid)
		assert_equal(q1.mbid,q1.medium(2).track(2).medium.release.mbid)


		assert_equal(13,q2.medium(1).tracks.size,"Killers disc 1 has 13 tracks - db")
		assert_equal(9,q2.medium(2).tracks.size,"Killers disc 2 has 9 tracks - db")
		assert_equal('4540b827-cce0-4f45-b3b9-f7cc09489584',q2.medium(1).track(10).recording)
		assert_equal('5f5879b4-78d5-481f-a007-b9eb34cba750',q2.medium(1).track(1).recording)
		assert_equal('6960710a-5120-420a-8e6e-acfa98db690f',q2.medium(2).track(5).recording)
		assert_equal(q2.mbid,q2.medium(1).track(1).medium.release.mbid)
		assert_equal(q2.mbid,q2.medium(2).track(2).medium.release.mbid)		
	end
	
	def teardown

		File.delete(File.expand_path("~/metadbtest.db"))
		
	end

end


