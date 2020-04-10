#!/bin/env ruby
# encoding: utf-8

require 'sqlite3'

$stdout.sync = true

#okpairs = ["Rachmaninov/Rachmaninoff","Faure/Fauré","Dvorak/Dvo?ák","Janacek/Janá?ek","Vorisek/Vo?í?ek",
#	"Saint-Saens/Saint-Saëns","Godowski/Godowsky"]

#cpairs = Hash.new
#okpairs.each |pair| do
#	cpairs[pair.split("/")[0]] = pair.split("/")[1]
#end

db = SQLite3::Database.new("/home/james/test.db")

rows = db.execute("select distinct a.pathname, a.composer, a.title, b.performing_work_sequence, c.title, c.composer, c.arranger " + 
	"from md_track a, md_track2work b, mb_work c where a.id = b.track_id and b.performing_work_mb_id = c.work_mb_id " +
	"order by a.pathname,a.album,a.track")
	
puts rows.size
	
rows.each_index do |i|
	if (i > 0)
		tpath = rows[i][0]
		tcomp = rows[i][1]
		ttitle = rows[i][2]
		mseq = rows[i][3]
		mwork = rows[i][4]
		mcomp = rows[i][5]
		marr = rows[i][6]
		lseq = rows[i-1][3]
		ltitle = rows[i-1][2]
		lwork = rows[i-1][4]
		if (i < (rows.size - 1)) 
			nwork = rows[i+1][5]
		end
		if mcomp
			mcompsur = mcomp.split(",")[0]
		else
			mcompsur = nil
		end
		if marr 
			marrsur = marr.split(",")[0]
		else
			marrsur = nil
		end
		if (mseq > 1)
			if ((mseq.to_i > (lseq.to_i + 1)) || (mseq < lseq))
				puts "" 
				puts "#{tpath}"
				puts "#{ltitle}/#{lwork}/#{lseq}"
				puts "#{ttitle}/#{mwork}/#{mseq}" 

			end
		end
		#if (mcompsur != tcomp) && (tcomp != nil) && (cpairs[tcomp] != mcompsur)
			#puts "Composer mismatch? #{tcomp}/#{mcompsur} (arr) #{marrsur} : #{tpath}/#{ttitle} "
		#end
	end
end