require 'net/http'
require_relative 'model'
require 'json'
#require 'pry'

STDOUT.sync = true
$log = Logger.new(STDOUT) unless $log
$log.level = Logger::INFO

class CoverArt
	attr_reader :url
	def initialize(rel)
		@rel = rel
		@url = nil		
		def fetch(uri_str, limit = 5)
			raise ArgumentError, 'HTTP redirect too deep' if limit == 0
		  
			url = URI.parse(uri_str)
			req = Net::HTTP::Get.new(url.path)
			response = Net::HTTP.start(url.host, url.port) { |http| http.request(req) }
			case response
			when Net::HTTPSuccess     then response
			when Net::HTTPNotFound    then response
			when Net::HTTPRedirection then fetch(response['location'], limit - 1)
			else
			  response.error!
			end
		end
		
		r = fetch("http://coverartarchive.org/release/#{rel.gid}/")
		if r.code.to_i == 200
			j = JSON.parse(r.body)
			j["images"].each do |i|
				if i["front"]
					@url = i["image"]
				end
			end
		end
		

		unless @url
			if rel.amazon_urls.size > 0
				uri = URI(rel.amazon_urls[0])
				req = Net::HTTP::Get.new(uri)
				req['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.88 Safari/537.36'

				res = Net::HTTP.start(uri.hostname, uri.port,:use_ssl => uri.scheme == 'https') {|http|
				http.request(req)
				}
				sleep (rand * 2)
				m = res.body.scan(/(https:\/\/.+?\.jpg)/)
				ids = Hash.new(Array.new)
				m.each do |ms|
					id = nil
					f = ms[0].match(/.*\/[A-Z]\/([A-Za-z0-9%]+)\._(AC_)?[A-Z]+([0-9]+)_\.jpg/)
					if f
						id = f.captures[0]
						ids[id.dup] =  ids[id.dup] << f.captures[2].dup
					end
				end
				@url = "https://images-na.ssl-images-amazon.com/images/I/#{ids.keys[0]}.jpg"
			end
		end
	end
end

