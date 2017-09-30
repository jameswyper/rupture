
require_relative 'common'
require 'rexml/document'
require 'rexml/xmldecl'

module UPnP


class Subscription
	attr_reader :sid
	attr_reader :expiryTime
	attr_reader :callbackURL
	attr_reader :eventSeq

	def initialize(service,callback, expiry)
		self.renew(expiry)
		@callbackURL = callback
		@sid = "uuid:" + SecureRandom.uuid
		@eventSeq = 0
		@service = service
		@service.addSubscription(self)

	end
	
	def expired?
		(@expiryTime) && (@expiryTime <= Time.now)
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
		if @eventSeq > 4294967295 then @eventSeq = 1 end
	end

end

end