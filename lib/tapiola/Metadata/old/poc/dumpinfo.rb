require_relative 'musicfiles'
require 'pry'
require 'logger'

STDOUT.sync = true
if  ($log == nil)  
	$log = Logger.new(STDOUT) 
end
$log.level = Logger::INFO

Model::Disc.where("id < ?",100).each do |disc|
	files = disc.file.order(:track)
	files.each do |f|
		artists =f.tag.where(name: "artist")
		if artists.size > 0 then artist = artists[0].value else artist = "" end
		albums =f.tag.where(name: "album")
		if albums.size > 0 then album = albums[0] .value else album = "" end
		titles =f.tag.where(name: "title")
		if titles.size > 0 then title = titles[0].value else title = "" end
		#puts "#{disc.pathname}/#{disc.number} #{f.track}/#{title}/#{artist}/#{album}"
	end
	
	disc.mediumOffsetCandidate.each do |c|
		
	end
end