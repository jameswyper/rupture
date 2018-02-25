

require_relative 'metamb'


$stdout.sync = true


s = Meta::MusicBrainz::Service.new

puts "Testing Recording"

r = Meta::MusicBrainz::Recording.new
r.getFromMbid("c617ea6d-8e6f-4420-a2b4-87e864968d93")

r.works.each{ |w| puts " work id #{w.mbid}"}
r.artists.each{ |a| puts " artist sort name #{a.sortName}"}

puts "recording title #{r.title}"
puts "recording length #{r.length}"

puts "Testing Work"

w = Meta::MusicBrainz::Work.new("ad4586c3-f06c-3cb2-b50d-91c43d6356dd")
w.getFullDetails

w1 = Meta::MusicBrainz::Work.new(w.parent)
w1.getFullDetails

puts "Work #{w.title} in #{w.key} of type #{w.type} alias #{w.alias}"
puts "Parent Work #{w1.title} in #{w1.key} of type #{w1.type} alias #{w1.alias}"

puts "Testing Releases"

r1 = Meta::MusicBrainz::Release.new
r2 = Meta::MusicBrainz::Release.new

r1.getFromDiscID("pz1cE_OnEFu6s1_IVkZ6KN_sFRc-")
r2.getFromMbid("354f8672-da64-31ea-94c7-057e902f3533")

puts "From DiscID"
puts "mbid is #{r1.mbid}"
r1.media.each do |k,v| 
	puts "medium #{k}"
	v.tracks.each do |tn,tr|
		puts "track #{tn} is #{tr.recording.mbid} or #{tr.recording.title}"
	end
end



puts "From mbid"
puts "mbid is #{r2.mbid}"
r2.media.each do |k,v| 
	puts "medium #{k}"
	v.tracks.each do |tn,tr|
		puts "track #{tn} is #{tr.recording.mbid} or #{tr.recording.title}"
	end
end
