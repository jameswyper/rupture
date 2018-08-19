

=begin
Tests to do


=end

require 'minitest/autorun'
require_relative '../../lib/tapiola/Metadata/metamb2.rb'
#require 'nokogiri'
#require 'net/http'
#require  'rexml/document'
#require 'pry'





class Testmb < Minitest::Test
	
			
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
		q1 = Meta::MusicBrainz::Release.new('f9dffcec-f9ae-3320-a003-b87c1e995885')
		q2 = Meta::MusicBrainz::Release.new('f9dffcec-f9ae-3320-a003-b87c1e995885')
		
		assert_equal(8,q1.medium(1).discIDs.size,'Killers 1 has 8 discids - xml')
		assert_equal(9,q1.medium(2).discIDs.size,'Killers 2 has 9 discids - xml')
		assert_equal(8,q2.medium(1).discIDs.size,'Killers 1 has 8 discids - db')
		assert_equal(9,q2.medium(2).discIDs.size,'Killers 2 has 9 discids - db')

		assert_equal("GEODiAH9glH00PEByHsRze9gifs-",q1.medium(1).discIDs["GEODiAH9glH00PEByHsRze9gifs-"].discid)
		assert_equal("GEODiAH9glH00PEByHsRze9gifs-",q2.medium(1).discIDs["GEODiAH9glH00PEByHsRze9gifs-"].discid)
		assert_equal("5oQBp7zOGQTqL9m_liQz1Yb8Dxo-",q1.medium(2).discIDs["5oQBp7zOGQTqL9m_liQz1Yb8Dxo-"].discid)
		assert_equal("5oQBp7zOGQTqL9m_liQz1Yb8Dxo-",q2.medium(2).discIDs["5oQBp7zOGQTqL9m_liQz1Yb8Dxo-"].discid)


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
	

	
	def test_artists
		q1 = Meta::MusicBrainz::Release.new('f9dffcec-f9ae-3320-a003-b87c1e995885')
		q2 = Meta::MusicBrainz::Release.new('f9dffcec-f9ae-3320-a003-b87c1e995885')
		r1 = Meta::MusicBrainz::Release.new('a135b237-db5c-3769-a38a-ffdd929a37c3')
		r2 = Meta::MusicBrainz::Release.new('a135b237-db5c-3769-a38a-ffdd929a37c3')
		n1 = Meta::MusicBrainz::Release.new('07971e8a-9b1a-31a0-a111-f69955974138')
		
		assert_equal("Queen",q1.artist(0).name,"Killers artist xml")
		assert_equal("Queen",q2.artist(0).name,"Killers artist db")
		assert_equal(1,q1.artists.size)
		assert_equal(1,q2.artists.size)
		assert_equal(2,r1.artists.size)
		assert_equal(2,r2.artists.size)
		assert_equal(1,n1.artists.size)
		assert_equal("Various Artists",n1.artist(0).name)
		 
		x = ""
		r1.each_artist {|a| x << a.sortname}
		assert_equal("Plant, RobertKrauss, Alison",x)
		
		assert_equal(" & ",r1.artists[0][1])
		assert_nil(q1.artists[0][1])

	end
	
	def test_discid_search
		d1 = Meta::MusicBrainz::DiscID.new("HnFqD3.p6hwybQz9HFT_g84Ko4g-")
		d2 = Meta::MusicBrainz::DiscID.new("3lfQrHqZFJwduQjNIEZFUBCEocM-")
		
		d1.findReleases
		
		assert_equal(4,d1.releases.size)
		assert_equal("Blue",d1.releases[0].title)
		assert_equal("Joni Mitchell",d1.releases[0].artist(0).name)
		
		# need to test getting 2nd from cache

	end
	
	def test_works
	end
	
	def test_recordings
	end
	
	def teardown

		File.delete(File.expand_path("~/metadbtest.db"))
		
	end

end


