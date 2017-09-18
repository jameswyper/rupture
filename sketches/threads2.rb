

q = Queue.new

t = Array.new

(1..5).each do |i|

	t[i] = Thread.new do
		while true do
			x = q.pop 
			puts "Thread #{i} awake popped #{x}"
			sleep(rand*0.01)
		end
	end
end

(1..15).each {|x| q.push x }

sleep(1)

(1..5).each {|i| t[i].kill }
t[1].kill 
