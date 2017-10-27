
#Copyright 2017 James Wyper

require_relative 'common'
require 'rexml/document'
require 'rexml/xmldecl'
require 'uri'

module UPnP


class Subscription
	attr_reader :sid
	attr_reader :expiryTime
	attr_reader :callbackURI
	attr_reader :eventSeq
	attr_reader :service
	attr_reader :callbackHost

	def initialize(service,callback, expiry)
		
		@sid = "uuid:#{SecureRandom.uuid}"
		@service = service
		@service.addSubscription(self)
		self.renew(expiry)
		url = "http://#{callback}" unless callback.start_with?('http')
		@callbackURI = URI.parse(url)
		@callbackHost = "#{@callbackURI.host}:#{@callbackURI.port}"
		@eventSeq = 0
		@active=false

	end
		
	def activate
		@active=true
	end
	
# A subscription is not active until we are sure that the subscriber has received the acknowledgement to their subscription request and knows the SID
	def active?
		@active
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