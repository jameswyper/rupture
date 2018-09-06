
require 'minitest/autorun'
require_relative '../../lib/tapiola/Metadata/acoustid.rb'
require_relative '../../lib/tapiola/Metadata/metacore.rb'

class TestAC < Minitest::Test
	
			
	def setup

		Meta::MusicBrainz::MBBase.openDatabase(File.expand_path("~/metatest_mb.db"))
		Meta::Core::DBBase.openDatabase(File.expand_path("~/metatest_db.db"))


	end
	
	def test_ac
		
		#dummy = Meta::MusicBrainz::Release.new("2fe766bf-aebb-4f2d-b89b-3924a45063e4")
		#puts "Got release OK #{dummy.title}"
		
		tf = Meta::Core::Folder.new('/media/music/flac/classical/opera')
		tf.scan { |count,total,eta| puts "#{sprintf('%2.1f',(total == 0 ? 100.0 : (count * 100.0) / total))}% complete, ETC #{eta.strftime('%b-%d %H:%M.%S')}"}
		
		ac = Meta::AcoustID::Service.new('/home/james/Downloads/chromaprint-fpcalc-1.4.2-linux-x86_64/fpcalc')
		
		tf.fetchDiscs.each do |disc|
			scores = ac.scoreDisc(disc)
			puts "#{disc.pathname}/#{disc.discNumber}"
			scores.each do |s|
				if s.trackMatches > 0
					puts "#{s.release.title}/#{s.release.mbid}/#{s.medium.position} #{s.trackCount}/#{s.trackMatches}/#{s.trackMisses}"
				end
			end
		end
		
	end
	
	def teardown

		#File.delete(File.expand_path("~/metatest_mb.db"))
		File.delete(File.expand_path("~/metatest_db.db"))
		
	end	
end