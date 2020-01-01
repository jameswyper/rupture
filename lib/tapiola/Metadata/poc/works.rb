require_relative 'musicfiles'
require 'pry'
require 'logger'

STDOUT.sync = true
if  ($log == nil)  
	$log = Logger.new(STDOUT) 
end
$log.level = Logger::INFO

#w = Model::Work.find(380002)
w = Model::Work.find(11760629)
#w = Model::Work.find(12625929)

puts w.name, w.gid


wp1s = w.parent_link
wp1s.each do |wp1|
	lt1 = wp1.link_type.name
	puts lt1, wp1.parent_work.name, wp1.parent_work.id
end

wa1s = w.artist_link
wa1s.each do |wa1|
	lt1 = wa1.link_type.name
	puts lt1, wa1.artist.name
end

w.parent_parts.each {|pp| puts pp.name}

[380002,12625929].each do |wi|
	w = Model::Work.find(wi)
	puts wi, w.has_parent_part?
end

w = Model::Work.find(12438631)

w.work_attribute.each do |wa|
	puts wa.inspect
	puts wa.work_attribute_type_allowed_value.id
	puts wa.work_attribute_type.name
end

ks = w.work_attribute.where(work_attribute_type: Model::WorkAttributeType.where(name: "Key")[0].id)
puts ks.inspect
puts ks[0].inspect
if ks.size > 0
	puts ks[0].work_attribute_type_allowed_value.value
end

puts w.has_key?
puts w.has_parent_part?
x = w.parent_parts[0]
puts x.has_key?
puts x.has_parent_part?

puts Model::LinkType.composedBy.size
puts Model::LinkType.composedBy[0].id

#w.artist_link.joins(:link_type).merge(Model::LinkType.composedBy).each {|n| puts n.artist.name}

puts w.composers[0].name
#todo - add work / artist / recording links in model and test

r = Model::Recording.where(gid: '8c9e1c98-e4cc-4f65-9325-9c399f025a3e')[0]
r.works.each {|w| puts w.name }