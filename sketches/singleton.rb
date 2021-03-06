

class Response

	def sendResponse(s)
		puts "Base method: #{s}"
	end
	
end

res = Response.new

res.sendResponse("hello")

puts "define singleton"

def res.sendResponse(s)
	self.class.instance_method(:sendResponse).bind(self).call(s)
	puts "Singleton method: #{s}"
	@v = 1
end

def res.pv
	puts @v
end

res.sendResponse("goodbye")
res.pv