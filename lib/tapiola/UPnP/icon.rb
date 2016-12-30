
require 'securerandom'
require_relative 'common'

module UPnP

# Simple structure to hold information about an Icon
class Icon
	
	# class variable to hold reference (by URL) to each icon
	@@icons = Hash.new
	
	def self.byURL(id)
		@@icons[id]
	end
	
	# MIME type e.g "image/png"
	attr_reader :type   
	# width in pixels
	attr_reader :width
	# height in pixels
	attr_reader :height
	# colour depth - bits per pixel
	attr_reader :depth
	# path to where the icon is stored on the filesystem.  Might need to turn this into a method.
	attr_reader :path
	# address / url where clients will be able to access the icon from
	attr_reader :addr
	
	# create an icon object and add it to the collection
	def initialize(t,w,h,d,p)
		@type = t
		@width = w
		@height = h
		@depth = d
		@path = p
		@uuid = SecureRandom.uuid
		@@icons[@uuid] = self
	end
	
end

end