
require 'minitest/autorun'
require_relative '../../lib/tapiola/Metadata/acoustid.rb'
require_relative '../../lib/tapiola/Metadata/metacore.rb'

class TestAC < Minitest::Test
	
			
	def setup

		Meta::MusicBrainz::MBBase.openDatabase(File.expand_path("~/metatest_mb.db"))
		Meta::MusicBrainz::MBBase.setServer('192.168.0.10:5000')
		Meta::Core::DBBase.openDatabase(File.expand_path("~/metatest_db.db"))


	end
	
	def test_ac
		
		#dummy = Meta::MusicBrainz::Release.new("2fe766bf-aebb-4f2d-b89b-3924a45063e4")
		#puts "Got release OK #{dummy.title}"
		
		tf = Meta::Core::Folder.new('/media/music/flac/classical/baroque')
		Meta::Core::DBBase.beginLUW
		tf.scan { |count,total,eta| puts "#{sprintf('%2.1f',(total == 0 ? 100.0 : (count * 100.0) / total))}% complete, ETC #{eta.strftime('%b-%d %H:%M.%S')}"}
		Meta::Core::DBBase.endLUW
		
		ac = Meta::AcoustID::Service.new('/home/james/Downloads/chromaprint-fpcalc-1.4.2-linux-x86_64/fpcalc')
		
		tf.fetchDiscs.each do |disc|
			Meta::Core::DBBase.beginLUW			
			scores = ac.scoreDisc(disc)
			Meta::Core::DBBase.endLUW				
			puts "#{disc.pathname}/#{disc.discNumber}"
			scores.each do |s|
				if s.trackMatches > 0
					puts "#{s.trackCount}/#{disc.tracks.size}-#{s.trackMatches}/#{s.trackMisses} \t#{s.release.title}/#{s.medium.position}/#{s.release.mbid}"
				end
			end
		end
		
	end
	
	def teardown

		#File.delete(File.expand_path("~/metatest_mb.db"))
		File.delete(File.expand_path("~/metatest_db.db"))
		
	end	
end