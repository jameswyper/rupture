
require 'minitest/autorun'
require_relative '../../lib/tapiola/Metadata/acoustid.rb'
require_relative '../../lib/tapiola/Metadata/metacore.rb'

class TestAC < Minitest::Test
	
			
	def setup

		Meta::MusicBrainz::MBBase.openDatabase(File.expand_path("~/metatest_mb.db"))
		Meta::Core::DBBase.openDatabase(File.expand_path("~/metatest_db.db"))


	end
	
	def test_ac
		
		tf = Meta::Core::Folder.new('/media/music/flac/classical/opera/Parsifal')
		tf.scan { |count,total,eta| puts "#{sprintf('%2.1f',(total == 0 ? 100.0 : (count * 100.0) / total))}% complete, ETC #{eta.strftime('%b-%d %H:%M.%S')}"}
		
		ac = Meta::AcoustID::Service.new('/home/james/Downloads/chromaprint-fpcalc-1.4.2-linux-x86_64/fpcalc')
		
		tf.fetchDiscs.each do |disc|
			scores = ac.scoreDisc(disc)
			puts "#{disc.pathname}/#{disc.discNumber}"
			scores.each do |s|
				puts "#{s.release.title}/#{s.release.mbid}/#{s.medium.position} #{s.trackCount}/#{s.trackMatches}/#{s.trackMisses}"
			end
		end
		
	end
	
	def teardown

		File.delete(File.expand_path("~/metatest_mb.db"))
		File.delete(File.expand_path("~/metatest_db.db"))
		
	end	
end