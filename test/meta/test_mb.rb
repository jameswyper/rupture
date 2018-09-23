

=begin
Tests to do


=end

require 'minitest/autorun'
require_relative '../../lib/tapiola/Metadata/metamb.rb'
#require 'nokogiri'
#require 'net/http'
#require  'rexml/document'
#require 'pry'

require 'i18n'

I18n.available_locales = [:en]


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
		assert_equal('4540b827-cce0-4f45-b3b9-f7cc09489584',q1.medium(1).track(10).recording.mbid)
		assert_equal('5f5879b4-78d5-481f-a007-b9eb34cba750',q1.medium(1).track(1).recording.mbid)
		assert_equal('6960710a-5120-420a-8e6e-acfa98db690f',q1.medium(2).track(5).recording.mbid)
		assert_equal(q1.mbid,q1.medium(1).track(1).medium.release.mbid)
		assert_equal(q1.mbid,q1.medium(2).track(2).medium.release.mbid)


		assert_equal(13,q2.medium(1).tracks.size,"Killers disc 1 has 13 tracks - db")
		assert_equal(9,q2.medium(2).tracks.size,"Killers disc 2 has 9 tracks - db")
		assert_equal('4540b827-cce0-4f45-b3b9-f7cc09489584',q2.medium(1).track(10).recording.mbid)
		assert_equal('5f5879b4-78d5-481f-a007-b9eb34cba750',q2.medium(1).track(1).recording.mbid)
		assert_equal('6960710a-5120-420a-8e6e-acfa98db690f',q2.medium(2).track(5).recording.mbid)
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
		
		d2.findReleases
		
		assert_equal(4,d2.releases.size)
		assert_equal("Blue",d2.releases[0].title)
		assert_equal("Joni Mitchell",d2.releases[0].artist(0).name)
		
		refute(d1.releases[0].cached?,"1st discid hit not cached")
		refute(d1.releases[2].cached?,"1st discid hit not cached")
		assert(d2.releases[0].cached?,"2nd discid hit cached")
		assert(d2.releases[3].cached?,"2nd discid hit cached")
		
	end
	
	
	def test_works
		w1 = Meta::MusicBrainz::Work.new("19adaa49-b0f6-4a98-9c62-dec279164ec1") # trav act 3
		
		w2 = Meta::MusicBrainz::Work.new("6b16c882-3459-44d9-b6f3-6c0020f74525") # vespers
		
		w3 = Meta::MusicBrainz::Work.new("4a622b0d-b0c0-405e-b49e-05b70c108284") #hammerklavier
		
		assert_equal("La traviata: Atto III",w1.title)
		assert_equal("La traviata",w1.parent.title)
		assert_equal(4,w1.parentSeq)
		assert_equal("Verdi",w1.artists[0][0].fileUnder)
		
		assert_equal("All-Night Vigil, op. 37: VIII. Praise the Name of the Lord",w2.alias)
		assert_equal("B-flat major",w3.key)
		assert_nil(w3.parent)
		
		assert_equal(w3,w3.performingWork)
		assert_equal("La traviata",w1.performingWork.title)
		assert_equal("All-Night Vigil, Op. 37",w2.performingWork.enTitle)
		assert_equal(8.0,w2.seq)
		assert_equal(0.0,w3.seq)
		assert_equal(4.0,w1.seq)
		
		refute(w1.cached?)
		w4 = Meta::MusicBrainz::Work.new("19adaa49-b0f6-4a98-9c62-dec279164ec1") # trav act 3
		
		assert_equal("La traviata: Atto III",w4.title)
		assert(w4.cached?)
		
		assert_equal("La traviata",w4.parent.title)
		assert_equal(4,w4.parentSeq)
		assert_equal("Verdi",w4.artists[0][0].fileUnder)


		assert(w4.parent.cached?)
		assert(w4.performingWork.cached?)
		
		assert_equal("composer",w1.performingWork.artists[0][1])
		assert_equal(w1.artists[0][0].mbid,w4.artists[0][0].mbid)
		assert_equal("composer",w4.performingWork.artists[0][1])


		#test composer
		assert_equal("Verdi",w1.composer.fileUnder)
		assert_equal("Rachmaninoff",w2.composer.fileUnder)
		assert_equal("Beethoven",w3.composer.fileUnder)
		assert_equal("Verdi",w4.composer.fileUnder)


	end
	

	def test_recordings
		rc1 = Meta::MusicBrainz::Recording.new("3cbd2e5c-bfbd-4dc0-9e40-f20ecf692cb3")
		re1 = Meta::MusicBrainz::Release.new("0c19517e-6309-4dec-92b1-2a411618941b")
		assert_equal("Cello Concerto in E minor, op. 85: I. Adagio - Moderato",rc1.title)
		assert_equal(3,rc1.artists.size)
		assert_equal("Jacqueline du Pre",I18n.transliterate(rc1.artists[0][0].name))
		assert_equal("Barbirolli",rc1.artists[2][0].fileUnder)
		assert_equal(", ",rc1.artists[0][1],"artist joinphrase")
		assert(rc1.releases[re1.mbid])
		refute(rc1.releases[re1.mbid + "asdg;anvn"])
		assert_equal(1,rc1.works.size)
		assert_equal(25,rc1.releases.size)
		refute(rc1.cached?)
		assert_equal(rc1.mbid,re1.medium(1).track(1).recording.mbid)
		
		rc2 = Meta::MusicBrainz::Recording.new("3cbd2e5c-bfbd-4dc0-9e40-f20ecf692cb3")
		assert(rc2.cached?)
		refute(rc1.artists[0][0].cached?)
		assert(rc2.artists[0][0].cached?)
		
	end

	def teardown

		File.delete(File.expand_path("~/metadbtest.db"))
		
	end

end


