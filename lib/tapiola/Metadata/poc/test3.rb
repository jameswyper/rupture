require_relative 'musicfiles'
require 'pry'
require 'logger'

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
	e.url_link.each do |u|
		puts u.id
		puts u.url.url
	end
	e.amazon_urls.each {|u| puts u}
end
