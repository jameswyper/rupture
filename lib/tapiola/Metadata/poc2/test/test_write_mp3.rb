require_relative '../tag.rb'

PATH = "./lib/tapiola/Metadata/poc2/test/data/"

FileUtils.cp(PATH + "haydn.mp3",PATH + "haydn_out.mp3")


f = GenericTag::Metadata.from_mp3(PATH+"haydn_out.mp3")

f.each_tag do |t|

    puts "#{t.name} #{t.values.each {|v| v}}"
end
puts ""
f.to_mp3(PATH+"haydn_out.mp3")
f = GenericTag::Metadata.from_mp3(PATH+"haydn_out.mp3")

f.each_tag do |t|
    puts "#{t.name} #{t.values[0]}"
end
