
require 'minitest/autorun'

def tokenise(i)
	tokens = Array.new
	p = 0
	inQuoteStr = false
	while (p < i.length) do
		case i[p]
		when '"'
			p += 1 # move past the "
			t = String.new
			endOfQuote = false
			begin
				while !(['"','\\'].include? i[p]) do
					t << i[p]
					p += 1
					if (p >= i.length)
						raise "Quoted string didn't terminate properly"
					end
				end
				if (i[p] == '"')
					endOfQuote = true
					p += 1
				else
					if (p >= (i.length-1))
						raise "Input ends with backslash"
					else
						if (['\\','"'].include? i[p+1])
							t << i[p+1]
							p += 2
						else
							raise "Illegal use of backslash - not followed by quote or another slash"
						end
					end
				end
			end until (endOfQuote || (p >= i.length)) 
			tokens << t
		when ')','('
			tokens << i[p]
			p += 1
		when ' ' # should expand to all wChar later
			p += 1
		else
			t = String.new
			begin
				t << i[p]
				p += 1
			end until ( (p >= i.length) || (['(',')',' '].include? i[p]) ) 
			tokens << t
		end
	end
	return tokens
end

def classify(a)
	
end

class TestTokenise < Minitest::Test

def test_simple
	t = Array.new
	t << ["hello world!","hello","world!"]
	t << [" hello world!","hello","world!"]
	t << ["hello world! ","hello","world!"]
	t << ["hello  world!","hello","world!"]
	t << ["hello wor ld!","hello","wor", "ld!"]
	t << ['hello "w orld!"',"hello",'w orld!']
	t << ["hello (wor)ld!","hello","(","wor",")","ld!"]
	t << ['hello "wor\\\\ld!"',"hello","wor\\ld!"]
	t << ['hello "wor\\"ld!"','hello','wor"ld!']



	t.each do |u|
		v = tokenise(u[0])
		w = u[1..-1]
		assert_equal v, w , "Difference on @#{u[0]}@"
	end

end

end

