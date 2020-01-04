
#require 'minitest/autorun'
require_relative '../../lib/tapiola/Metadata/acoustid.rb'
require_relative '../../lib/tapiola/Metadata/metacore.rb'


		Meta::MusicBrainz::MBBase.openDatabase(File.expand_path("~/metatest_mb.db"))
		Meta::Core::DBBase.openDatabase(File.expand_path("~/metatest_db.db"))


		
		#dummy = Meta::MusicBrainz::Release.new("2fe766bf-aebb-4f2d-b89b-3924a45063e4")
		#puts "Got release OK #{dummy.title}"
		
		tf = Meta::Core::Folder.new('/home/james/Music/flac/classical')
		Meta::Core::DBBase.beginLUW	
		tf.scan { |count,total,eta| puts "#{sprintf('%2.1f',(total == 0 ? 100.0 : (count * 100.0) / total))}% complete, ETC #{eta.strftime('%b-%d %H:%M.%S')}"}
		Meta::Core::DBBase.endLUW	
		ac = Meta::AcoustID::Service.new('fpcalc')
		
		discs = tf.fetchDiscs
		count = 0
		discs.each do |disc|
			Meta::Core::DBBase.beginLUW	
			count = count + 1
			scores = ac.scoreDisc(disc)
			puts "#{count} of #{discs.size}: #{disc.pathname}/#{disc.discNumber}"
			scores.each do |s|
				if s.trackMatches > 0
					puts "#{s.release.title}/#{s.release.mbid}/#{s.medium.position} #{s.trackCount}/#{s.trackMatches}/#{s.trackMisses}"
				end
			end
			Meta::Core::DBBase.endLUW	
		end
		
		#File.delete(File.expand_path("~/metatest_mb.db"))
		File.delete(File.expand_path("~/metatest_db.db"))
		