class A
	def initialize(f, args)
		@fn = f
		@args = args
	end
	
	def invoke(a)
		method(@fn).call(a, args)
	end
end

def fnarr (a, args)
	puts a["in1"]
	puts a["in2"]
	puts args["obj"].prop
end

x = Hash.new
x["in1"] = "hello"
x["in2"] = "there"

class P
	attr_accessor :prop
end

o = P.new
o.prop = "success?"

act = A.new(fnarr, "obj" => o)

act.invoke(x)