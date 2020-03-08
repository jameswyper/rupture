require 'taglib'

def trigger(file)
    TagLib::FLAC::File.open(file) do |f|
        f.picture_list.each do |p|
            #p.data
        end
        f.xiph_comment.field_list_map.each do |tag,value|
            tag
            value
        end
    end
end

100000.times do |i|
    trigger("/home/james/sunshine.flac")
    if (i % 100 == 0) then puts "iteration #{i}" end
end