
require_relative 'common'
require 'rexml/document'
require 'rexml/xmldecl'

module UPnP


class Subscription
	attr_reader :sid
	attr_reader :expiryTime
	attr_reader :callbackURLs
	attr_reader :eventSeq
	
	def initialise(callback, expiry)
		self.renew(expiry)
		@callbackURLs = Array.new
		@sid = SecureRandom.uuid
		@eventSeq = 0
		#TODO #parse callback line and put into array
		#TODO find a way of ensuring all evented variables are sent
		
		#if callback can't be parsedlog.warn
	end
	
	def expired?
		(@expiryTime <= Time.now)
	end
	
	def invalid?
		(@callbackURLs.size == 0)
	end
	
	def renew(expiry)
		if (expiry > 0)
			@expiryTime = Time.now + expiry
		else
			@expiryTime = nil
		end
	end
	
	def cancel
		@expiryTime = Time.now
	end
	
	def increment
		@eventSeq += 1
	end

end

end