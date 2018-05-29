

require 'sqlite3'

$stdout.sync = true



db = SQLite3::Database.new("/home/james/metascan.db")

rows = db.execute("select distinct a.pathname " + 
	"from md_track a, md_track2work b, mb_work c where a.id = b.track_id and b.performing_work_mb_id = c.work_mb_id ")

f= File.open("/home/james/paths.txt","w")

rows.each do |row|
	f.puts row[0]
end 

rows = db.execute("select distinct a.pathname " + 
	"from md_track a left outer join md_track2work b on a.id = b.track_id where b.track_id is null")

f= File.open("/home/james/paths_no_metadata.txt","w")

rows.each do |row|
	f.puts row[0]
end