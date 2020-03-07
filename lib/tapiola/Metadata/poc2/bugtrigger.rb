require 'taglib'

def trigger(file)
    TagLib::FLAC::File.open(file) do |f|
        f.picture_list.each do |p|
            x = p.data
        end
    end
end

10000.times do |i|
    trigger("/home/james/test.orig.flac")
    if (i % 100 == 0) then puts "iteration #{i}" end
end