require 'csv'
require_relative '../tag.rb'

CSV.foreach("/media/james/karelia/Code/titlefix.txt",{:col_sep => "\t", :encoding => "ISO8859-1"}) do |row|
    file = row[0] + "/" + row[1]
    newtit = row[3]
    #file.gsub!('/home/james','/media/james/karelia')
    m = GenericTag::Metadata.from_flac(file)
    puts "#{file}|#{newtit}|#{m.album}" 
end