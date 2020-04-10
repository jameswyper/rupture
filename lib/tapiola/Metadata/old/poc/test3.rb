require_relative 'musicfiles'
require 'pry'
require 'logger'
require_relative 'amazon'

STDOUT.sync = true
if  ($log == nil)  
	$log = Logger.new(STDOUT) 
end
$log.level = Logger::INFO

Model::DB::
openDB('/media/data/tapiola/data/mb.db')

r = Model::Recording.where(gid: '8c9e1c98-e4cc-4f65-9325-9c399f025a3e')[0]

r.works.each {|w| puts w.name }

rels = Array.new
r.track.each  {|t| rels << t.medium.release }

rels.each do |e| 
	puts e.name
	#e.amazon_urls.each {|u| puts u}
	ca = CoverArt.new(e)
end
