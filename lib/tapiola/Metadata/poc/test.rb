require_relative 'model'

b = Model::Artist.find(64981)
puts "Artist #{b.id } #{b.name}"

c = Model::ArtistCredit.find(1314268)
puts c.name

b.artist_credit_name.where(artist_credit_id: 1314268).each do |n| 
	puts "#{n.name }/#{n.artist_id}/#{n.artist_credit_id}"
	puts n.artist.name
end

c = Model::ArtistCreditName.where(artist_credit_id: 1314268)
puts c.to_sql
c.each do |ac|
	puts ac.artist.name
end

c = Model::ArtistCredit.where(name: 'Johann Sebastian Bach; Murray Perahia')[0]
c.release.where(name: 'The French Suites').each do |r|
  puts r.id
  r.medium.each do |m|
    m.cdtoc.each {|t| puts t.id, t.discid, t.track_offset}
  end
end

f = 'rD0AAJkhAAAOMwAAbzUAADs0AAATMgAAdR4AAN82AADGFwAAzjYAAC0kAAC5' + "\n" + 'NwAASiMAANwxAAAyFwAACzcAAPAnAAA=' + "\n"

Model::Cdtoc.where(discid: f).each do |cd|
puts "CDTOC id #{cd.id}"
m = cd.medium
m.each {|mm| puts mm.release.name}
end

c = Model::Cdtoc.find(692448)
puts c.discid

puts f

fr = c.discid

fr.split("").each_index do |x|
	if fr.split("")[x] != f.split("")[x] 
		puts "diff at #{x}: #{fr.split("")[x]} #{f.split("")[x]}"
	end
end
		
puts Model::Cdtoc.find(692433).medium.size