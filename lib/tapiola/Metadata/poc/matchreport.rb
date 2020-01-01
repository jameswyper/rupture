
require_relative 'musicfiles'
require 'pry'
require 'logger'

STDOUT.sync = true
if  ($log == nil)  
	$log = Logger.new(STDOUT) 
end
$log.level = Logger::INFO

f = File.new('/tmp/out.csv','w')
		
	Model::Disc.where('1=1').order(:pathname,:number).each do |di|
		med_count = 99999
		chosen_med = nil
		di.mediumOffsetCandidate.each do |mo|
			rel = mo.medium.release
			mc = rel.medium.size
			if mc < med_count
				chosen_med = mo.medium
				med_count = mc
			end
		end
		di.mediumAcoustCandidate.each do |mo|
			rel = mo.medium.release
			mc = rel.medium.size
			if mc < med_count
				chosen_med = mo.medium
				med_count = mc
			end
		end
		# Y / path / disc / release / position / gid
		if (chosen_med)
			f.puts "Y\t#{di.pathname}\t#{di.number}\t#{chosen_med.release.name}\t#{chosen_med.position}\t#{chosen_med.release.gid}\thttps://musicbrainz.org/release/#{chosen_med.release.gid}"
			di.mediumOffsetCandidate.each do |mo|
				if  chosen_med != mo.medium
					f.puts "\t\t\t#{mo.medium.release.name}\t#{mo.medium.position}\t#{mo.medium.release.gid}\thttps://musicbrainz.org/release/#{mo.medium.release.gid}"

				end
			end
			di.mediumAcoustCandidate.each do |mo|
				if  chosen_med != mo.medium
					f.puts "\t\t\t#{mo.medium.release.name}\t#{mo.medium.position}\t#{mo.medium.release.gid}\thttps://musicbrainz.org/release/#{mo.medium.release.gid}"
				end
			end
		else
			f.puts "\t#{di.pathname}\t#{di.number}\t\t\t\t"
		end
	end


f.close

