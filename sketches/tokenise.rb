
require 'minitest/autorun'


=begin rdoc
This code parses a search request and evaluates it against an object - the object is assumed to contain a properties
hash with values for each property.

The search request can be arbitrarily complex (in practice I hope it won't be) with nested brackets and the need to 
treat AND and OR with the correct precedence.  I can't claim to have tested the code exhaustively.  Here's how it works:

1.  An instance of the Evaluator class is created from a string.  The string is split into tokens separated by whitespace.
Note that values can be quoted and therefore contain spaces -> "hello world!" - this also means that double quote (") 
characters can be escaped inside such strings -> "hello \"new\" world!" and that in turn means backslashes have to be escaped
as \\

2.  The tokens are then parsed for brackets.  Each token inside brackets (including the enclosing brackets) is given an ID and
a level - this allows conditions grouped inside brackets to be identified.  An example

	a = b or (x = y and (p = q or m = n) or (1 = 2)) will be broken into tokens with IDs and levels
ID	0 0 0 0  11 1 1 1   22 2 2 2  2 2 22 1  33 3 331
Lvl	0 0 0 0  11 1 1 1   22 2 2 2  2 2 22 1  22 2 221

3.  The tokens are then broken down into Conditions.  Conditions can be simple of complex.
Simple conditions are of the for property-comparator-value e.g.  a = "b" or x exists true.
Complex conditions are collections of simple and other complex conditions, grouped by brackets
So in the example above the complex conditions are
(a) the entire string
(b) x = y and (ref to complex condition) or (ref to another complex condition)
(c) p = q or m = n
(d) 1 = 2 (this is a complex condition by virtue of being bracketed, even though it only contains a single simple condition)

4.  Complex conditions have clauses (simple or other complex conditions) and connectors - the ands and ors

5.  In order to evaluate the ands and or with the correct precedence all the complex conditions need to be rearranged.
I call this "reduce" as the aim is to reduce all the complex conditions to one where the connectors are either
all ands or all ors. I do this by grouping sequences of ands into new complex conditions, so

a = b or x = y and p = q or c = d and e = f and g = h

effectively becomes

a = b or (x = y and p = q) or (c = d and e = f and g = h)

6.  Conditions are evaluated recursively, so in the example above the code evaluates
a = b
then 
(x = y and p = q)
then (c = d and e = f and g = h)

7.  The only attempt I've made to optimise this is not to evaluate redundant conditions so (again, same example)
the code will 
- return true if a = b  (no point checking the ors)
- when evaluating (x = y and p = q) it will return false for that sub-condition (not the whole thing), without 
evaluating p = q, if (x = y) is false

=end




class EvaluatorError < RuntimeError
end

class ParserError < EvaluatorError
end


class Evaluator


attr_reader :tokens


class Token

	attr_reader :value, :type
	attr_accessor :brkId, :level
	
	
	def initialize(v,q = false)
		@brkId = 0
		@level = 0
		@value = v
		case v
		when "exists"
			@type = :existsOp
		when "true", "false"
			@type = :boolVal
		when "<", "<=", ">", ">=", "=", "!="
			@type = :relOp
		when "and", "or"
			@type = :logOp
		when "("
			@type = :openBrk
		when ")"
			@type = :closeBrk
		when "contains", "doesNotContain", "derivedfrom"
			@type = :stringOp
		else
			if (q)
				@type = :quotedVal
			else
				@type = :property
			end
		end
	end
	
	def self.dump(t)
		s = ""
		t.each {|u| s << u.value << '/' }
		return s
	end
	
end

def firstPass_Brackets
	l = 0
	idStack = [0]
	brkId = 0
	@tokens.each do |token|
		if (token.type == :openBrk)
			idStack.push(brkId += 1)
			l += 1
			token.level = l
			token.brkId = idStack.last
		else
			token.brkId = idStack.last
			if (token.type == :closeBrk)
				token.level = l
				l -= 1
				idStack.pop
				if l < 0
					raise ParserError, "too many closing brackets"
				end
			else
				token.level = l
			end
		end
	end
	if (l != 0)
		raise ParserError, "unbalanced brackets"
	end
	return self
end

def initialize(i)
	@tokens = Array.new
	p = 0
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
						raise ParserError, "Quoted string didn't terminate properly"
					end
				end
				if (i[p] == '"')
					endOfQuote = true
					p += 1
				else
					if (p >= (i.length-1))
						raise ParserError, "Input ends with backslash"
					else
						if (['\\','"'].include? i[p+1])
							t << i[p+1]
							p += 2
						else
							raise ParserError, "Illegal use of backslash - not followed by quote or another slash"
						end
					end
					if p>= i.length 
						raise ParserError, "Quoted string didn't terminate properly"
					end
				end
			end until (endOfQuote)
			@tokens << Token.new(t,true)
		when ')','('
			@tokens << Token.new(i[p])
			p += 1
		when " ","\t","\v","\n","\f","\r"
			p += 1
		else
			t = String.new
			begin
				t << i[p]
				p += 1
			end until ( (p >= i.length) || (["(",")"," ","\t","\v","\n","\f","\r"].include? i[p]) ) 
			@tokens << Token.new(t)
		end
	end
end


class Condition
end

class SimpleCondition < Condition
	attr_reader :property
	attr_reader :value
	attr_reader :comparator
	attr_reader :text
	attr_reader :level
	def initialize(t)
		@level = t[0].level
		if t[0].type != :property
			raise ParserError, "Should be a Property first - #{t[0].value}/#{t[1].value}/#{t[2].value}"
		else
			@property = t[0].value
			case t[1].type
			when :existsOp
				@comparator = :exists
				if t[2].type != :boolVal
					raise ParserError, "3rd part should be true or false - #{t[0].value}/#{t[1].value}/#{t[2].value}"
				end
				if t[2].value == "true"
					@value = true
				else
					@value = false
				end
			when :relOp, :stringOp
				@comparator = t[1].value
				@value = t[2].value
				if t[2].type != :quotedVal
					raise ParserError, "3rd part should be quoted value - #{t[0].value}/#{t[1].value}/#{t[2].value}"
				end
			else
				raise ParserError, "2nd part of condition of wrong type (is #{t[1].type}) - #{t[0].value}/#{t[1].value}/#{t[2].value}"
			end
		end
		@text = "[#{@property} #{@comparator} #{@value}]"
	end
	
	def dump
		"Simple: (level #{@level}) \n#{@text}"
	end
	
	def evaluate(obj)
	
#		puts "Evaluating #{@property} #{@comparator} #{@value}"
#		puts "against #{obj}"
		
		case @comparator
		when :exists
			if obj.properties[@property]
				return @value
			else
				return !@value
			end
		when "contains"
			return (obj.properties[@property].include?(@value))
		when "doesNotContain"
			return !(obj.properties[@property].include?(@value))
		when "derivedfrom"
			return (@property.include?(@value))
		when "="
			return (obj.properties[@property] == @value)
		when "<="
			return (obj.properties[@property] <= @value)
		when "<"
			return (obj.properties[@property] < @value)
		when ">="
			return (obj.properties[@property] >= @value)
		when ">"
			return (obj.properties[@property] > @value)
		when "!="
			return (obj.properties[@property] != @value)
		else
			return false
		end
#  ideally the "derivedFrom" check could be smarter as @property needs to begin with the text in @value not just include it
#  and the <,<=,>,>= checks should convert numbers - but who's going to use numbers in searches anyway?

	end

end

class ComplexCondition < Condition
	
	attr_reader :clauses
	attr_reader :connectors
	attr_reader :text
	attr_reader :level
		
	def initialize
		@clauses = Array.new
		@connectors = Array.new
		@parent = nil
		@level = 0
	end
		
	def fillFromTokens(t,parent = nil)
		p = 0
		@level = t[p].level
#		puts "starting loop for #{Token.dump(t)}"
		while p < t.size do
#			puts "restarting loop"
			if t[p].type == :openBrk
#				puts "opening bracket found at #{p}"
				q = p
				while (q < t.size) && (t[q].level >= t[p].level)  do q += 1 end
#				puts "p,q = #{p},#{q} and tokens are #{Token.dump(t)}"
				@clauses << ComplexCondition.new.fillFromTokens(t[p+1..q-1],self)
				p = q
#				puts "open bracket completely processed, p now #{p}"
			else
#				puts "ready to process simple condition #{Token.dump(t[p..p+2])}"
				@clauses << SimpleCondition.new(t[p..p+2])
				p += 3
#				puts "simple condition processed, p now #{p}"
			end
			if p < t.size
				while (p< t.size) && (t[p].type == :closeBrk) do
#					puts "closing bracket found at #{p}"
					p += 1
				end
				if p < t.size
					if t[p].type != :logOp
						raise ParserError, "should be and/or here at position #{p} of #{Token.dump(t)}"
					else
						if t[p].value == "and"
							@connectors << :and
						else
							@connectors << :or
						end
						p += 1
						if p >= t.size
							raise ParserError, "shouldn't finish with and/or"
						end
					end
				end
			end
		end
#		puts "finished loop"
		return self
	end

	def fillFromComplex(c,rs,re)
		@level = c.level + 1
		@parent = c
		@connectors = c.connectors[rs..re]
		@clauses = c.clauses[rs..re+1]
		return self
	end

	def dump
		s = "Complex:\n"
		s << "Level #{@level}\n"
		@connectors.each_index do |i|
			s << @clauses[i].dump << "\n"
			s << "#{@connectors[i]}" << "\n"
		end
		s << @clauses.last.dump
	end

	def reduce
		# take a complex clause with ands and ors and simplify it to one with ors only (put all the ands into another ComplexClause object)
		andCount = 0
		orCount = 0
#		puts "in reduce, connectors are #{@connectors.join(" ")}"
		@connectors.each do |c|
			if c == :and
				andCount += 1
			else
				orCount += 1
			end
		end
		andRanges = Array.new
		if (andCount > 0) && (orCount  > 0)  #ie only if we have a mix of ands and ors
			firstAnd = 0
			lastAnd = 0
			@connectors.each_index do |i|
#				puts "processing index #{i}"
				if @connectors[i] == :and
#					puts "it's an and"
					if (i == 0) 
						firstAnd = 0
#						puts " i==0 "
					else 
						if (@connectors[i-1] == :or)
#							puts "prev index was an or"
							firstAnd = i
#							puts "firstAnd is now #{firstAnd}"
						end
					end
					if (i == (@connectors.size - 1))
						lastAnd = i
#						puts "i is now at max, range is #{firstAnd}..#{lastAnd}"
						andRanges << [firstAnd,lastAnd]
					else
						if @connectors[i+1] == :or
							lastAnd = i
							andRanges << [firstAnd,lastAnd]
#							puts "about to hit an or, range is #{firstAnd}..#{lastAnd}"
						end
					end
				end
			end
		end
		andRanges.reverse.each do |range|
#			puts "in reduce, tackling range #{range[0]}..#{range[1]}"
			c = ComplexCondition.new.fillFromComplex(self,range[0],range[1])
#			puts "currently have #{@connectors.size} connectors and #{@clauses.size} clauses"
			@connectors.slice!(range[0]..range[1])
			@clauses.slice!(range[0]..(range[1]+1))
			@clauses.insert(range[0],c)
#			puts "now have #{@connectors.size} connectors and #{@clauses.size} clauses"
		end
	end
	
	def getChildren
		
#	puts "in getChildren"	
		l = Array.new
		@clauses.each do |d|
#			puts d.class
			if d.kind_of? (Evaluator::ComplexCondition)
#				puts "going recursive"
				l.concat(d.getChildren)
				l << d
			end
		end
#		puts "done #{l.size}"
#		l.each {|m| puts m.to_s}
		return l
	end
	
	def reduceAll
		# like reduce, but recursive
		self.getChildren.each {|c| c.reduce }
		self.reduce
	end
	
	def evaluate(obj)
		if @connectors[0] == :and
			@clauses.each do |c|
				if (c.evaluate(obj) == false)
					return false
				end
			end
			return true
		else
			@clauses.each do |c|
				if (c.evaluate(obj) == true)
					return true
				end
			end
			return false
		end
	end
	
end




end # Evaluator class


class TestTokenise < Minitest::Test

def test_simple
	
	t = Array.new
	t << ["hello world!","hello","world!"]
	t << [" hello\tworld!\f","hello","world!"]
	t << ["hello world! ","hello","world!"]
	t << ["hello  world!","hello","world!"]
	t << ["hello wor ld!","hello","wor", "ld!"]
	t << ['hello "w orld!"',"hello",'w orld!']
	t << ["hello (wor)ld!","hello","(","wor",")","ld!"]
	t << ['hello "wor\\\\ld!"',"hello","wor\\ld!"]
	t << ['hello "wor\\"ld!"','hello','wor"ld!']


	t.each do |u|
		v= Evaluator.new(u[0]).tokens
		w = u[1..-1]
		assert_equal v.size, w.size , "Size Difference on @#{u[0]}@"
		w.zip(v).each do |exp,act|
			assert_equal exp, act.value, "Value Difference on @#{u[0]}@ - expected @#{exp}@ and got @#{act.value}@"
		end
	end
	
	t = ['"hel\\lo"','"hello\\"','"hello'] 
	t.each do |u| 
		e = assert_raises do Evaluator.new(u).tokens end 
	end

end

def test_classify
	
	t = Array.new
	
	str = 'foo = "bar"'
	tokens = ['foo','=','bar']
	types = [:property, :relOp, :quotedVal]
	t << [str,tokens,types]
	
	str = 'foo exists false'
	tokens = ['foo','exists','false']
	types = [:property, :existsOp, :boolVal]
	t << [str,tokens,types]

	str = "and\for\sor!"
	tokens = ['and','or','or!']
	types = [:logOp, :logOp, :property]
	t << [str,tokens,types]

	str = 'careful contains "nuts" and (this = "that") or ( this != "twit" ) '
	tokens = ['careful','contains','nuts','and','(','this','=','that',')','or','(','this','!=','twit',')']
	types = [:property,:stringOp,:quotedVal,:logOp,:openBrk,:property,:relOp,:quotedVal,:closeBrk,:logOp,:openBrk,:property,:relOp,:quotedVal,:closeBrk]
	t << [str,tokens,types]

	t.each do |u|
		v = Evaluator.new(u[0]).tokens
		assert_equal v.size, u[1].size , "Size Difference on @#{u[0]}@"
		assert_equal v.size, u[2].size , "Size Difference on @#{u[0]}@"
		u[1].zip(v).each do |exp, act|
			assert_equal exp, act.value, "Value Difference on @#{u[0]}@ - expected @#{exp}@ and got @#{act.value}@"
		end
		u[2].zip(v).each do |exp, act|
			#puts act.value
			assert_equal exp, act.type, "Type Difference on @#{u[0]}@ - expected @#{exp}@ and got @#{act.type}@"
		end
	end

end

def test_firstPass

	t = Array.new
	
	str = 'careful contains "nuts" and (this = "that") or ( this != "twit" ) '
	tokens = ['careful','contains','nuts','and','(','this','=','that',')','or','(','this','!=','twit',')']
	types = [:property,:stringOp,:quotedVal,:logOp,:openBrk,:property,:relOp,:quotedVal,:closeBrk,:logOp,:openBrk,:property,:relOp,:quotedVal,:closeBrk]
	levels = [0,0,0,0,1,1,1,1,1,0,1,1,1,1,1]
	ids = [0,0,0,0,1,1,1,1,1,0,2,2,2,2,2]
	
	str = '(x = "y") and (b > "c") or ( (e contains "d") or ( f derivedfrom "g" )) or h exists true'
	tokens = ['(','x','=','y',')','and','(','b','>','c',')','or','(','(','e','contains','d',')','or','(','f','derivedfrom','g',')',')','or','h','exists','true']
	types = [:openBrk,:property,:relOp,:quotedVal,:closeBrk,:logOp,:openBrk,:property,:relOp,:quotedVal,:closeBrk,:logOp,:openBrk,:openBrk,:property,:stringOp,:quotedVal,:closeBrk,:logOp,:openBrk,:property,:stringOp,:quotedVal,:closeBrk,:closeBrk,:logOp,:property,:existsOp,:boolVal]
	levels = [1,1,1,1,1,0,1,1,1,1,1,0,1,2,2,2,2,2,1,2,2,2,2,2,1,0,0,0,0]
	ids = [1,1,1,1,1,0,2,2,2,2,2,0,3,4,4,4,4,4,3,5,5,5,5,5,3,0,0,0,0]
	t << [str,tokens,types,levels,ids]

	t.each do |u|
		v = Evaluator.new(u[0]).firstPass_Brackets.tokens
		assert_equal v.size, u[1].size , "Size Difference on @#{u[0]}@"
		assert_equal v.size, u[2].size , "Size Difference on @#{u[0]}@"
		u[1].zip(v).each do |exp, act|
			assert_equal exp, act.value, "Value Difference on @#{u[0]}@"
		end
		u[2].zip(v).each do |exp, act|
			#puts act.value
			assert_equal exp, act.type, "Type Difference on @#{u[0]}@"
		end
		u[3].zip(v).each do |exp, act|
			#puts act.value
			assert_equal exp, act.level, "Level Difference on @#{u[0]}@"
		end
		u[4].zip(v).each do |exp, act|
			#puts act.value
			assert_equal exp, act.brkId, "ID Difference on @#{u[0]}@"
		end
	end
	
	t = Array.new

	t << 'oh ( dear ) ) (oh dear) ((('
	t << 'ooops ((( oops ))'
	
	t.each do |u|
		assert_raises do
			Evaluator.new(u).firstPass_Brackets
		end
	end
	

end

def test_SimpleCondition
	
	str = 'a >= "b" and x = "y" and q exists true and p exists false or i contains "j"'
	offsets = [0,4,8,12,16]
	properties = ['a','x','q','p','i']
	comparators = ['>=','=',:exists,:exists,'contains']
	values = ['b','y',true,false,'j']
	
	t = Evaluator.new(str).firstPass_Brackets.tokens
	offsets.each_index do |i|
		c = Evaluator::SimpleCondition.new(t[offsets[i]..offsets[i]+2])
		assert_equal properties[i], c.property, "Property difference on #{t[offsets[i]..offsets[i]+2].to_s}"
		assert_equal comparators[i], c.comparator, "Property difference on #{t[offsets[i]..offsets[i]+2].to_s}"
		assert_equal values[i], c.value, "Property difference on #{t[offsets[i]..offsets[i]+2].to_s}"
	end
	
	str = 'a > b and q exists flaws and x <> "y" and p "error" q or "a" = "b" or true exists false'
	offsets = [0,4,8,12,16,20]
	t = Evaluator.new(str).firstPass_Brackets.tokens
	offsets.each_index do |i|
		assert_raises do
			c = Evaluator::SimpleCondition.new(t[offsets[i]..offsets[i]+2])
		end
	end
	
end

def test_ComplexCondition
	
	
	u = 'x = "y"'
	
	c = Evaluator::ComplexCondition.new
	c.fillFromTokens(Evaluator.new(u).firstPass_Brackets.tokens)
	assert_equal 0,c.connectors.size
	assert_equal 1,c.clauses.size
	assert_kind_of Evaluator::SimpleCondition,c.clauses[0]
	assert_equal "x", c.clauses[0].property
	assert_equal "=", c.clauses[0].comparator
	assert_equal "y", c.clauses[0].value
	
	u = 'x = "y" and (a > "b" or c < "d")'

	c = Evaluator::ComplexCondition.new
	c.fillFromTokens(Evaluator.new(u).firstPass_Brackets.tokens)
	assert_equal 1, c.connectors.size
	assert_equal 2, c.clauses.size	
	assert_equal :and, c.connectors[0]
	
	c1 = c.clauses[0]
	c2 = c.clauses[1]
	assert_kind_of Evaluator::SimpleCondition, c1
	assert_equal "x", c1.property
	assert_equal "=", c1.comparator
	assert_equal "y", c1.value

	assert_kind_of Evaluator::ComplexCondition, c2
	assert_equal 1, c2.connectors.size
	assert_equal 2, c2.clauses.size
	assert_equal :or, c2.connectors[0]
	
	c3 = c2.clauses[0]
	c4 = c2.clauses[1]
	assert_kind_of Evaluator::SimpleCondition, c3
	assert_kind_of Evaluator::SimpleCondition, c4
	assert_equal "a", c3.property
	assert_equal ">", c3.comparator
	assert_equal "b", c3.value
	assert_equal "c", c4.property
	assert_equal "<", c4.comparator
	assert_equal "d", c4.value
	assert_equal 0, c1.level
	assert_equal 1, c2.level
	assert_equal 1, c3.level
	assert_equal 1, c4.level
	
	u = '(x contains "y") and (a = "b" or c < "d" and e > "f" and (g != "h" or i exists false)) or p = "q"'

	c = Evaluator::ComplexCondition.new
	c.fillFromTokens(Evaluator.new(u).firstPass_Brackets.tokens)
	assert_equal 2, c.connectors.size
	assert_equal 3, c.clauses.size	
	assert_equal :and, c.connectors[0]
	assert_equal :or, c.connectors[1]
	
	c1 = c.clauses[0]
	c2 = c.clauses[1]
	c3 = c.clauses[2]
	assert_kind_of Evaluator::ComplexCondition, c1
	assert_kind_of Evaluator::ComplexCondition, c2
	assert_kind_of Evaluator::SimpleCondition, c3
	
	assert_equal "p", c3.property
	assert_equal "=", c3.comparator
	assert_equal "q", c3.value

	assert_equal 0, c1.connectors.size
	assert_equal 1, c1.clauses.size	
	c4 = c1.clauses[0]
	assert_kind_of Evaluator::SimpleCondition, c4
	assert_equal "x", c4.property
	assert_equal "contains", c4.comparator
	assert_equal "y", c4.value

	assert_equal 3, c2.connectors.size
	assert_equal 4, c2.clauses.size	
	assert_equal :or, c2.connectors[0]
	assert_equal :and, c2.connectors[1]
	assert_equal :and, c2.connectors[2]
	c6 = c2.clauses[0]
	c7 = c2.clauses[1]
	c8 = c2.clauses[2]
	c9 = c2.clauses[3]
	assert_kind_of Evaluator::ComplexCondition, c9
	assert_kind_of Evaluator::SimpleCondition, c6
	assert_kind_of Evaluator::SimpleCondition, c7
	assert_kind_of Evaluator::SimpleCondition, c8

	assert_equal "a", c6.property
	assert_equal "=", c6.comparator
	assert_equal "b", c6.value
	assert_equal "c", c7.property
	assert_equal "<", c7.comparator
	assert_equal "d", c7.value
	assert_equal "e", c8.property
	assert_equal ">", c8.comparator
	assert_equal "f", c8.value
	
	assert_equal 1, c9.connectors.size
	assert_equal 2, c9.clauses.size	
	assert_equal :or, c9.connectors[0]
	c10 = c9.clauses[0]
	c11 = c9.clauses[1]
	assert_equal "g", c10.property
	assert_equal "!=", c10.comparator
	assert_equal "h", c10.value
	assert_equal "i", c11.property
	assert_equal :exists, c11.comparator
	assert_equal false, c11.value
	
#	assert_equal 0, c.level
	assert_equal 1, c1.level
	assert_equal 1, c2.level
	assert_equal 0, c3.level
	assert_equal 1, c4.level

	assert_equal 1, c6.level
	assert_equal 1, c7.level
	assert_equal 1, c8.level
	assert_equal 2, c9.level
	assert_equal 2, c10.level
	assert_equal 2, c11.level

end

def test_reductions

	u = 'x = "y"'
	c = Evaluator::ComplexCondition.new.fillFromTokens(Evaluator.new(u).firstPass_Brackets.tokens)
	c.reduceAll

	assert_equal 0,c.connectors.size
	assert_equal 1,c.clauses.size
	assert_kind_of Evaluator::SimpleCondition,c.clauses[0]
	assert_equal "x", c.clauses[0].property
	assert_equal "=", c.clauses[0].comparator
	assert_equal "y", c.clauses[0].value
	
	u = 'x = "y" and (a > "b" or c < "d")'

	c = Evaluator::ComplexCondition.new.fillFromTokens(Evaluator.new(u).firstPass_Brackets.tokens)
	c.reduceAll
	
	assert_equal 1, c.connectors.size
	assert_equal 2, c.clauses.size	
	assert_equal :and, c.connectors[0]
	
	c1 = c.clauses[0]
	c2 = c.clauses[1]
	assert_kind_of Evaluator::SimpleCondition, c1
	assert_equal "x", c1.property
	assert_equal "=", c1.comparator
	assert_equal "y", c1.value

	assert_kind_of Evaluator::ComplexCondition, c2
	assert_equal 1, c2.connectors.size
	assert_equal 2, c2.clauses.size
	assert_equal :or, c2.connectors[0]
	
	c3 = c2.clauses[0]
	c4 = c2.clauses[1]
	assert_kind_of Evaluator::SimpleCondition, c3
	assert_kind_of Evaluator::SimpleCondition, c4
	assert_equal "a", c3.property
	assert_equal ">", c3.comparator
	assert_equal "b", c3.value
	assert_equal "c", c4.property
	assert_equal "<", c4.comparator
	assert_equal "d", c4.value
	assert_equal 0, c1.level
	assert_equal 1, c2.level
	assert_equal 1, c3.level
	assert_equal 1, c4.level

	u = 	'x = "y" and a = "b" or c = "d"'
	c = Evaluator::ComplexCondition.new.fillFromTokens(Evaluator.new(u).firstPass_Brackets.tokens)
	assert_equal 2,c.connectors.size
	assert_equal 3,c.clauses.size
	assert_kind_of Evaluator::SimpleCondition,c.clauses[0]
	assert_kind_of Evaluator::SimpleCondition,c.clauses[1]
	assert_kind_of Evaluator::SimpleCondition,c.clauses[2]
		
	
	c.reduceAll

	assert_equal 1, c.connectors.size
	assert_equal :or, c.connectors[0]
	assert_equal 2, c.clauses.size
	assert_kind_of Evaluator::ComplexCondition,c.clauses[0]
	assert_kind_of Evaluator::SimpleCondition,c.clauses[1]

	c1 = c.clauses[0]
	c2 = c.clauses[1]
	assert_equal "c", c2.property
	

	assert_equal 1, c1.connectors.size
	assert_equal :and, c1.connectors[0]
	assert_equal 2, c1.clauses.size
	assert_kind_of Evaluator::SimpleCondition,c1.clauses[0]
	assert_kind_of Evaluator::SimpleCondition,c1.clauses[1]
	
	c3 = c1.clauses[0]
	c4 = c1.clauses[1]
	
	assert_equal "x", c3.property
	assert_equal "a", c4.property

	u = 	'x = "y" or a = "b" and c = "d"'
	c = Evaluator::ComplexCondition.new.fillFromTokens(Evaluator.new(u).firstPass_Brackets.tokens)
	assert_equal 2,c.connectors.size
	assert_equal 3,c.clauses.size
	assert_kind_of Evaluator::SimpleCondition,c.clauses[0]
	assert_kind_of Evaluator::SimpleCondition,c.clauses[1]
	assert_kind_of Evaluator::SimpleCondition,c.clauses[2]
		
	
	c.reduceAll

	assert_equal 1, c.connectors.size
	assert_equal :or, c.connectors[0]
	assert_equal 2, c.clauses.size
	assert_kind_of Evaluator::ComplexCondition,c.clauses[1]
	assert_kind_of Evaluator::SimpleCondition,c.clauses[0]

	c1 = c.clauses[0]
	c2 = c.clauses[1]
	assert_equal "x", c1.property
	

	assert_equal 1, c2.connectors.size
	assert_equal :and, c2.connectors[0]
	assert_equal 2, c2.clauses.size
	assert_kind_of Evaluator::SimpleCondition,c2.clauses[0]
	assert_kind_of Evaluator::SimpleCondition,c2.clauses[1]
	
	c3 = c2.clauses[0]
	c4 = c2.clauses[1]
	
	assert_equal "a", c3.property
	assert_equal "c", c4.property

	u = 	'x = "y" or a = "b" or c = "d"'
	c = Evaluator::ComplexCondition.new.fillFromTokens(Evaluator.new(u).firstPass_Brackets.tokens)
	assert_equal 2,c.connectors.size
	assert_equal 3,c.clauses.size
	assert_kind_of Evaluator::SimpleCondition,c.clauses[0]
	assert_kind_of Evaluator::SimpleCondition,c.clauses[1]
	assert_kind_of Evaluator::SimpleCondition,c.clauses[2]
		
	
	c.reduceAll

	assert_equal 2,c.connectors.size
	assert_equal 3,c.clauses.size
	assert_kind_of Evaluator::SimpleCondition,c.clauses[0]
	assert_kind_of Evaluator::SimpleCondition,c.clauses[1]
	assert_kind_of Evaluator::SimpleCondition,c.clauses[2]
		
	u = 	'x = "y" and a = "b" and c = "d"'
	c = Evaluator::ComplexCondition.new.fillFromTokens(Evaluator.new(u).firstPass_Brackets.tokens)
	assert_equal 2,c.connectors.size
	assert_equal 3,c.clauses.size
	assert_kind_of Evaluator::SimpleCondition,c.clauses[0]
	assert_kind_of Evaluator::SimpleCondition,c.clauses[1]
	assert_kind_of Evaluator::SimpleCondition,c.clauses[2]
		
	
	c.reduceAll

	assert_equal 2,c.connectors.size
	assert_equal 3,c.clauses.size
	assert_kind_of Evaluator::SimpleCondition,c.clauses[0]
	assert_kind_of Evaluator::SimpleCondition,c.clauses[1]
	assert_kind_of Evaluator::SimpleCondition,c.clauses[2]
		
		
	u = 	'x = "y" and a = "b" or (c = "d" or e = "f" and g = "h" and i = "j" or k = "l" and m = "n")'
	c = Evaluator::ComplexCondition.new.fillFromTokens(Evaluator.new(u).firstPass_Brackets.tokens)
	assert_equal 2,c.connectors.size
	assert_equal 3,c.clauses.size
	assert_kind_of Evaluator::SimpleCondition,c.clauses[0]
	assert_kind_of Evaluator::SimpleCondition,c.clauses[1]
	assert_kind_of Evaluator::ComplexCondition,c.clauses[2]
		
	
	c.reduceAll

	assert_equal 1,c.connectors.size
	assert_equal 2,c.clauses.size
	assert_kind_of Evaluator::ComplexCondition,c.clauses[0]
	assert_kind_of Evaluator::ComplexCondition,c.clauses[1]
	
	assert_equal :or, c.connectors[0]
	
	c0 = c.clauses[0]
	c1 = c.clauses[1]
	
	assert_equal 1,c0.connectors.size
	assert_equal 2,c0.clauses.size
	assert_kind_of Evaluator::SimpleCondition,c0.clauses[0]
	assert_kind_of Evaluator::SimpleCondition,c0.clauses[1]
	assert_equal :and, c0.connectors[0]
	c00 = c0.clauses[0]
	c01 = c0.clauses[1]
	assert_equal "x", c00.property
	assert_equal "a", c01.property
	
	assert_equal 2,c1.connectors.size	
	assert_equal 3,c1.clauses.size
	assert_equal :or, c1.connectors[0]
	assert_equal :or, c1.connectors[1]
	
	c10 = c1.clauses[0]
	c11 = c1.clauses[1]
	c12 = c1.clauses[2]
	
	assert_kind_of Evaluator::SimpleCondition,c10
	assert_kind_of Evaluator::ComplexCondition,c11
	assert_kind_of Evaluator::ComplexCondition,c12
	assert_equal "c", c10.property
	
	assert_equal 2, c11.connectors.size
	assert_equal 3, c11.clauses.size
	assert_equal :and, c11.connectors[0]
	assert_equal :and, c11.connectors[1]

	c110 = c11.clauses[0]
	c111 = c11.clauses[1]	
	c112 = c11.clauses[2]
	assert_kind_of Evaluator::SimpleCondition,c110
	assert_kind_of Evaluator::SimpleCondition,c111
	assert_kind_of Evaluator::SimpleCondition,c112
	
	assert_equal "e", c110.property
	assert_equal "g", c111.property
	assert_equal "i", c112.property
	
	
	assert_equal 1, c12.connectors.size
	assert_equal 2, c12.clauses.size
	assert_equal :and, c12.connectors[0]
	
	c120 = c12.clauses[0]
	c121 = c12.clauses[1]	
	assert_kind_of Evaluator::SimpleCondition,c120
	assert_kind_of Evaluator::SimpleCondition,c121
	
	assert_equal "k", c120.property
	assert_equal "m", c121.property

	end


end

class TestEvaluate < MiniTest::Test

class Obj
	attr_accessor :properties
	def initialize
		@properties = Hash.new
	end
end


def test_eval

	obj = Obj.new
	obj.properties["name"] = "Fred Bloggs"
	obj.properties["name.first"] = "Fred"
	obj.properties["name.last"] = "Bloggs"

	tests = [
	['name = "Fred Blaggs"',false],
	['name = "Fred Bloggs"',true],
	['name != "Fred Blaggs"',true],
	['name != "Fred Bloggs"',false],
	['name <= "Fred Blaggs"',false],
	['name <= "Fred Bloggs"',true],
	['name <= "Fred Blzggs"',true],
	['name >= "Fred Blaggs"',true],
	['name >= "Fred Bloggs"',true],
	['name >= "Fred Blzggs"',false],
	['name > "Fred Bloggs"',false],
	['name > "Fred Blzggs"',false],
	['name > "Fred Blaggs"',true],
	['name < "Fred Bloggs"',false],
	['name < "Fred Blaggs"',false],
	['name < "Fred Blzggs"',true],
	['name exists true', true],
	['name exists false', false],
	['nome exists true', false],
	['nome exists false', true],
	['name contains "red Bl"',true],
	['name contains "r3d Bl"',false],
	['name doesNotContain "r3d Bl"',true],
	['name doesNotContain  "red Bl"',false],
	['name.last derivedfrom "name"', true],
	['name.last derivedfrom "name.first"', false],
	['name.first = "Fred" or name.last = "Fred"',true],
	['name.first = "Fred" and name.last = "Fred"',false],
	['name.first = "Fred" and (name.last = "Fred" or name.last = "Bloggs")',true],
	['(name.first = "Fred" and name.last = "Blegges") or (name.last = "Fred" or (name = "Fred Bloggs" and (name.last != "Bleggs")))',true],

	]
	tests.each do |test|
		c = Evaluator::ComplexCondition.new.fillFromTokens(Evaluator.new(test[0]).firstPass_Brackets.tokens)
		c.reduceAll
		assert_equal test[1], c.evaluate(obj), test[0]
	end

end

end