require_relative 'musicfiles'
require 'pry'
require 'json'
require 'logger'

STDOUT.sync = true
if  ($log == nil)  
	$log = Logger.new(STDOUT) 
end
$log.level = Logger::INFO

t = MusicFiles::Tree.new("/home/james/Music/flac/")

=begin
puts t.top
t.directories.each do |d|
	puts d.pathname
	d.discs.each do |di|
		puts di.number.to_s
		di.tracks.keys.sort.each {|k| puts k.to_s + ":" + di.tracks[k].tags["artist"][0]  + di.tracks[k].samples.to_s}
		di.offsets.each {|o| puts o.to_s}
		puts di.base64Offsets
	end if d.discs
	d.files.each do |f|
		puts f.disc.to_s + "/" + f.track.to_s + "/" +  f.basename
	end if d.files
end
=end

t.findByOffsets
t.findByAcoustID

#t.foundDiscsViaOffsets.each {|d| puts "Found (offset) #{d.pathname}/#{d.number}"}
#t.foundDiscsViaAcoustID.each {|d| puts "Found (acoustid) #{d.pathname}/#{d.number}"}

#t.notFoundDiscs.each do |d| 
#	puts "Not found #{d.pathname}/#{d.number}"
#	#d.offsets.each {|o| puts o }
#end

$log.info "Removing old data"
Model::Disc.delete_all
Model::MediumOffsetCandidate.delete_all
Model::File.delete_all
Model::MediumAcoustCandidate.delete_all
Model::Tag.delete_all


$log.info "Saving unfound"

ActiveRecord::Base.transaction do
	t.notFoundDiscs.each do |d| 
		md = Model::Disc.create(pathname: d.pathname, number: d.number)
		d.tracks.each_value do |f|
			mf = md.file.create(pathname: f.pathname, basename: f.basename, track: f.track)
			f.tags.each do |name, value|
				mf.tag.create(name: name, value: value)
			end
		end
	end
end

$log.info "Saving foundViaOffsets"

ActiveRecord::Base.transaction do
	t.foundDiscsViaOffsets.each do |d|
		md = Model::Disc.create(pathname: d.pathname, number: d.number)
		d.tracks.each_value do |f|
			mf = md.file.create(pathname: f.pathname, basename: f.basename, track: f.track)
			f.tags.each do |name, value|
				mf.tag.create(name: name, value: value)
			end
		end
		d.mediumCandidatesOffsets.each do |mc|
			md.mediumOffsetCandidate.create(medium_id: mc.id)
		end
	end
end

$log.info "Saving foundViaAcoustID"

ActiveRecord::Base.transaction do
	t.foundDiscsViaAcoustID.each do |d|
		md = Model::Disc.create(pathname: d.pathname, number: d.number)
		d.tracks.each_value do |f|
			mf = md.file.create(pathname: f.pathname, basename: f.basename, track: f.track)
			f.tags.each do |name, value|
				mf.tag.create(name: name, value: value)
			end
		end
		d.mediumCandidatesAcoustID.each do |mc|
			md.mediumAcoustCandidate.create(medium_id: mc.id)
		end
	end
end

$log.info "done"

