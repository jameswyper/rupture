

q = Queue.new

t = Thread.new do
	puts "Hello"
	q.pop
	puts "Goodbye"
end

sleep(1)
t.kill
