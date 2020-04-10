require 'sqlite3'
require 'base64'

db = SQLite3::Database.new(ARGV[0])

rows = db.execute("select id, leadout_offset, track_offset from cdtocs;")

db.transaction

#puts rows.size

rows.each do |row|
	unbracketed_offsets = row[2][1..-2]
	offsets = Array.new
	first_offsets = unbracketed_offsets.split(",")
	first_offsets.each_index do |i|
		if i > 0
			offsets << (first_offsets[i].to_i - first_offsets[i-1].to_i)
		end
	end
	offsets << (row[1].to_i - first_offsets[-1].to_i)
	x =  Base64.encode64(offsets.pack("L*"))
	db.execute("update cdtocs set discid = ? where id = ?",x,row[0])
end

db.commit