require 'csv'
require_relative '../tag.rb'

CSV.foreach("/home/james/Code/titlefix2.txt",{:col_sep => "\t", :external_encoding => "Windows-1252", :internal_encoding => "UTF-8"}) do |row|
    file = row[0] + "/" + row[1]
    newtit = row[3]
    #file.gsub!('/home/james','/media/james/karelia')
    begin
    m = GenericTag::Metadata.from_flac(file)
    #puts "#{file}|#{newtit}|#{m.album}" 
    rescue
    puts "#{file}"
    end
end
