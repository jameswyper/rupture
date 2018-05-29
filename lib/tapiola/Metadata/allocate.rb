
require 'sqlite3'
require 'shellwords'

db = SQLite3::Database.new("/home/james/metascan.db")

db.execute("create table if not exists md_chosen (pathname text)")
db.execute("delete from md_chosen")

f = File.open("/home/james/paths_tab.txt")

f.readlines.each do |l|
	m = l.split("\t")
	if (m[0] != "") 

		m = m[1].chomp
		if m[0] == '"'
			m = m[1..-2]
		end
		db.execute("insert into md_chosen  values (?)", m)
	end
end

#get all tracks that have works and that we want to use

rows = db.execute ("select distinct a.pathname, a.filename, a.artist, a.album,a.track, a.title, (a.samples / a.samplerate), 
c.title as perfwork, c.composer,
d.title as work
from
md_track a,
md_track2work b,
mb_work c,
mb_work d,
md_chosen e
where
e.pathname = a.pathname
and b.track_id = a.id
and b.work_mb_id = d.work_mb_id
and b.performing_work_mb_id = c.work_mb_id
order by perfwork, a.pathname, a.track")

puts rows.size

class CandTrack
	attr_reader :time, :filename, :track, :title, :work
	def initialize(r)
		@filename = r[1]
		@track = r[4].to_i
		@title = r[5]
		@time = r[6]
		@work = r[9]
	end
end

class Candidate
	attr_reader :pathname, :perfwork, :composer, :artist, :album, :time
	def initialize(r)
		@pathname = r[0]
		@perfwork = r[7]
		@composer = r[8]
		@artist = r[2]
		@album = r[3]
		@tracks = Array.new
		@taken = false
	end
	def take
		@taken = true
	end
	def taken?
		@taken
	end
	def totalTimes
		@time = 0
		@tracks.each {|t| @time = @time + t.time} 
	end
	def addTrack(t)
		@tracks << t
	end
end

candidates = Array.new
last = [nil,nil,nil]
rows.each do |row|
	this = [row[7],row[0],row[3]]
	#puts "This: #{this.join(":")} Last #{last.join(":")}"
	if (this != last)
		#puts "new candidate"
		candidates << Candidate.new(row)
	end
	candidates[-1].addTrack(CandTrack.new(row))
	last = this
end

puts candidates.size
candidates.each {|c| c.totalTimes}
#candidates.each {|c| puts "#{c.perfwork} / #{c.time}"}
candidates.sort! {|a,b| b.time <=> a.time}

#candidates.each {|c| puts "#{c.perfwork} / #{c.artist} / #{c.time}" }

class Container
	attr_reader :time, :inittime
	def initialize(time)
		@time = time
		@inittime = time
		@works = Array.new
	end
	def add(c)
		@works << c
		c.take
		@time = @time - c.time
	end
	def orderWorks
		@works.sort! {|a,b| b.time <=> a.time}
		@works[1..-1].shuffle if @works[1..-1]
	end
	def printContents
		@works.each {|w| puts "#{w.perfwork} / #{w.artist} / #{w.time}"}
	end
end

containers = Array.new
10.times {containers << Container.new(4200)}
30.times {containers << Container.new(3600)}
30.times {containers << Container.new(3000)}
30.times {containers << Container.new(2700)}




containers.each do |co|
	candidates.each do |ca|
		if (co.time >= ca.time) && (!ca.taken?)
			co.add(ca)
		end
	end
end

containers.each do |c|
	c.orderWorks
	puts ""
	puts "Container, #{c.time}/#{c.inittime} remaining"
	c.printContents
end

t = 0
nt = 0
candidates.each do |c|
	if (!c.taken?)
		puts "#{c.perfwork} (#{c.composer}) was not used"
		t = t + c.time
		nt = nt + 1
	end
end

puts "#{nt} candidate works unused totalling #{t}"

dest = "/media/whatever"
l1s = Hash.new
commands = ""

containers.each do |c|
	level1 = c.inittime.to_s.sprintf("%3d")
	if (!l1s[c.inittime])
		l1s[c.inittime] = 0
		commands << "mkdir #{shellwords.escape(dest + level1)} \n"
	else
		l1s[c.inittime] += 1
	end
	level2 = l1s[c.inittime].to_s.sprintf("%2d")
end

