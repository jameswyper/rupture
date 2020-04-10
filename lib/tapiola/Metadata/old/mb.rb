
require 'sqlite3'
require 'rexml/document'
require 'httpclient'

class MusicBrainz
	
	def initialize(server,db)
		@server = server
	end
	
	def getDiscByID(discID)
		sleep(1)
		c = HTTPClient.new
		r = c.request('GET',"http://#{@server}/ws/2/discid/#{discID}?inc=recordings",
			:header => {'user-agent' => 'jrwyper@yahoo.co.uk'})
		x = REXML::Document.new(r.body)
		x.elements.each("//metadata/disc/release-list") do |rl|
			s = rl.attributes["count"]
			x.elements.each("/metadata/disc/release-list/release") do |rel|
				#puts "release #{rel.attributes["id"]}"
				rel.elements.each("medium-list/medium") do |med|
					#puts "position #{med.elements["position"].text}"
					med.elements.each("disc-list/disc") do |di|
						#puts "discID #{di.attributes["id"]}"
					end
					med.elements.each("track-list/track") do |tr|
						pos = tr.elements["position"].text
						num = tr.elements["number"].text
						#puts "track #{num} #{pos}"
						tr.elements.each("recording") do |rec|
							#puts "recording #{rec.attributes["id"]}"
							sleep(1)
							getWorkForRecording(rec.attributes["id"]).each {|i| sleep(1); getWorkForWork(i)}
						end
					end
				end
			end
		end
	end
	
	def getWorkForRecording(id)
		aw = Array.new
		c = HTTPClient.new
		r = c.request('GET',"http://#{@server}/ws/2/recording/#{id}?inc=work-rels",
			:header => {'user-agent' => 'jrwyper@yahoo.co.uk'})
		x = REXML::Document.new(r.body)
		x.elements.each("/metadata/recording/relation-list/relation/work") do |w|
			wid = w.attributes["id"]
			puts "\n#{w.elements["title"].text} id=#{wid}"
			aw << wid
		end
		return aw
	end
	
	def getWorkForWork(id)
		c = HTTPClient.new
		r = c.request('GET',"http://#{@server}/ws/2/work/#{id}?inc=work-rels",
			:header => {'user-agent' => 'jrwyper@yahoo.co.uk'})
		x = REXML::Document.new(r.body)
		t = x.elements["/metadata/work"].attributes["type"]
		#puts id
		rid = x.elements["/metadata/work"].attributes["id"]
		rtit = x.elements["/metadata/work/title"].text
		if t != nil
		puts "Found #{rtit} which is of type #{t}"
			return rid, t, rtit
		end
		x.elements.each("/metadata/work/relation-list/relation") do |rel|
			if rel.attributes["type"] == "parts" && rel.elements["direction"]
				d = rel.elements["direction"].text
				if d == "backward"
					up = rel.elements["work"].attributes["id"]
					if (up != nil)
						return getWorkForWork(up)
					end
				end
			end
		end
		puts "Found #{rtit} (no type)"
		return rid, nil, rtit
	end
end

a = MusicBrainz.new('192.168.0.5:5000',nil)

require 'sqlite3'
d = SQLite3::Database.new("/home/james/test.db")
r = d.execute("select distinct a.mb_discID, a.id, b.pathname from md_disc a, md_track b where a.id = b.md_disc_id")
c = 0
z = r.size
r.each do |s|
	c = c + 1
	puts "#{c} of #{z} #{s[2]} (#{s[0]})"
	a.getDiscByID(s[0])
	$stdout.flush()
end



# things to do
# cache mb result if code = 200
# try offset 182, 183 if 150 doesn't return a discid
# add in acoustID - try and get best match for a release
# acoustID -> recordings -> releases -> media
# count distinct track/release combos
# take release with most tracks 
# check total tracks = total tracks on release (or disc of release if poss)
# maybe cross-check track times too