
re = Regexp.new /^"(?:[^"\\]|\\\\|\\")*"$/

['hello','"hell"o','"hello"','"hell"o"','""hello""','"fred" and "bob"',
 '"hell\\\\o"','"hell\\"o"','"he\\l\"o"'].each do |w|
    m = re.match(w)
    puts "#{w} #{ m ? "matches" : "does not match"}"
end