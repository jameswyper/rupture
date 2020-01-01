require 'net/http'
#require 'pry'

uri = URI('https://www.amazon.co.uk/Schubert-Vol-1-Various-Artists/dp/B017I2VVKA')

req = Net::HTTP::Get.new(uri)
req['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.88 Safari/537.36'

res = Net::HTTP.start(uri.hostname, uri.port,:use_ssl => uri.scheme == 'https') {|http|
  http.request(req)
}

#puts res.body
m = res.body.scan(/(https:\/\/.+?\.jpg)/)
ids = Hash.new(Array.new)
m.each do |ms|
	id = nil
	#puts "checking #{ms[0]}"
  	f = ms[0].match(/.*\/[A-Z]\/([A-Za-z0-9%]+)\._(AC_)?[A-Z]+([0-9]+)_\.jpg/)
	if f
		#puts "got a candidate #{ms[0]}"
		puts f.inspect
		id = f.captures[0]
		puts "id is #{id}"
		ids[id.dup] =  ids[id.dup] << f.captures[2].dup
	end
end
ids.each_key do |i|
	puts "id #{i} has #{ids[i]}"
end

puts ids.keys[0]



