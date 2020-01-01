
require_relative 'musicfiles'
require 'pry'
require 'logger'

STDOUT.sync = true
if  ($log == nil)  
	$log = Logger.new(STDOUT) 
end
$log.level = Logger::INFO

#=begin
Model::Disc.where('1=1').each do |di|
	med_count = 99999
	chosen_med = nil
	di.mediumOffsetCandidate.each do |mo|
		rel = mo.medium.release
		mc = rel.medium.size
		if mc < med_count
			chosen_med = mo.medium
			med_count = mc
		end
	end
	di.mediumAcoustCandidate.each do |mo|
		rel = mo.medium.release
		mc = rel.medium.size
		if mc < med_count
			chosen_med = mo.medium
			med_count = mc
		end
	end
	if (chosen_med)
		puts
		puts "#{di.pathname}/#{di.number} <==> #{chosen_med.release.name}/#{chosen_med.position}"
		#puts
		i = 0
		comps = Hash.new(0.0)
		di.file.order(:track).each do |f|
			i = i + 1
			tr = chosen_med.track.where(position: i)[0]
			rec = tr.recording
			if rec.works.size > 0
				rec.works.each do |w|
					w.composers.each do |c|
						comps[c.id] += 1 + (tr.position / 1000.0) + (c.id / 1000000000.0)
					end
					pw = w
					while (pw.has_parent_part?) && (!pw.has_key?) do
						pw = pw.parent_parts[0]
					end
					#puts "#{f.basename} <==> #{pw ? pw.name : ""} <==> #{w ? w.name : ""} <==> #{tr.position}/#{tr.name}"
				end
			else
				#puts "#{f.basename} <==> \t\t <==> \t\t <==> #{tr.position}/#{tr.name}"

			end
		end
		cpr = ""
		tc = 0
		comps.each_value {|v| tc += v}
		compsi = comps.invert
		compsr = compsi.keys.sort.reverse
		#binding.pry
		case comps.size
		when 0
		when 1
			cpr = Model::Artist.find(compsi[compsr[0]]).sort_name.split(',')[0]
		when 2
			cpr = Model::Artist.find(compsi[compsr[0]]).sort_name.split(',')[0] + "_" + Model::Artist.find(compsi[compsr[1]]).sort_name.split(',')[0]
		when 3
			cpr = Model::Artist.find(compsi[compsr[0]]).sort_name.split(',')[0] + "_" + Model::Artist.find(compsi[compsr[1]]).sort_name.split(',')[0] + "_" + Model::Artist.find(compsi[compsr[2]]).sort_name.split(',')[0]
		else
			compsr.slice(0..2) do |r|
				if (r* 1.0 / tc) > 0.3
					cpr << Model::Artist.find(compsi[r]).sort_name.split(',')[0] + "_"
				end
			end
			cpr << "Various"
		end
		puts "#{chosen_med.release.gid}:#{cpr}"
	end
end


# need to add in link_attribute and link_attribute type to remove "additional" composers

#=end

=begin
Model::Disc.where('1=1').each do |di|
	if (di.mediumAcoustCandidate.size == 0) && (di.mediumOffsetCandidate.size == 0)
		st = di.file.order(:track)[0]
		puts "#{di.pathname}"
		binding.pry
		puts "#{di.pathname}\t#{di.number}\t#{st.tag.where(name: 'album')[0].value}"
	end
end
=end