module AV

class Property
	def initialize(name,xmltype,namespace)
		@name = name
		@xmlType = xmltype
		@namespace = namespace
	end
	@@Properties = { 	:id => Property.new(:id,:attribute,:DIDL),
					:title => Property.new(:title,:element,:DC),
					:creator => Property.new(:creator,:element,:DC),
					:res => Property.new(:res,:element,:DIDL),
					:class => Property.new(:class,:element,:UPnP),
					:searchable => Property.new(:searchable,:attribute,:UPnP),
					:searchClass => Property.new(:searchClass, :element, :UPnP),
					:createClass => Property.new(:createClass, :element, :UPnP),
					:parentID => Property.new(:parentID, :attribute,:DIDL),
					:refID => Property.new(:parentID,:attribute,:DIDL),
					:restricted => Property.new(:restricted,:attribute,:DIDL),
					:writeStatus => Property.new(:writeStatus, :element, :UPnP),
					:childCount => Property.new(:childCount, :attribute, :DIDL),
					:storageMedium => Property.new(:storageMedium,:element,:UPnP), 
					:longDescription => Property.new(:longDescription,:element,:UPnP), 
					:description => Property.new(:description,:element,:DC), 
					:publisher => Property.new(:publisher, :element, :DC), 
					:contributor => Property.new(:contributor,:element, :DC), 
					:date => Property.new(:date,:element,:DC), 
					:relation => Property.new(:relation,:element,:DC), 
					:rights => Property.new(:rights,:element,:DC), 
					:artist => Property.new(:artist,:element,:UPnP), 
					:genre => Property.new(:genre, :element, :UPnP), 
					:producer => Property.new(:producer,:element,:UPnP), 
					:albumArtURI => Property.new(:albumArtURI,:element,:UPnP), 
					:toc => Property.new(:toc,:element,:UPnP)
			}
end


class CDObject
	
	attr_reader :properties
	def requiredProperty?(prop)
		return @properties[prop][0]
	end
	def multiValuedProperty?(prop)
		return @properties[prop][1]
	end
	def initialize
		@parent = nil
		@properties = 		{  	:id => [true,false], :parentID => [true,false], :title => [true,false], 
					:creator => [false,false], :res => [false,true], :class => [true,false], 	
					:restricted => [true,false],:writeStatus => [false,false] }

	end
end

class CDItem < CDObject
	def initialize
		super
		@properties.merge!( { :refID => [false,false] })
	end
	def linkToParent(p)
		@parent = p
		p.addChild(self)
	end
	def setParent(p)
		@parent = p
	end
end

class CDContainer < CDObject
	def initialize
		super
		@children = Array.new
		@properties.merge!({ :childCount => [false,false], :createClass => [false,true], :searchClass => [false,true], :searchable => [false,false]})
	end
	def addChild(c)
		@children << c
		c.setParent(self)
	end
	def removeChild(c)
		c.setParent(nil)
		@children.delete(c)
	end
end

class CDAlbum < CDContainer
	def initialize
		super
		@properties.merge!({ :storageMedium => [false,false], :longDescription => [false,false], :description => [false,false], 
		:publisher => [false,true], :contributor => [false,true], :date => [false,false], :relation => [false,true], :rights => [false,true] })
	end
end

class CDMusicAlbum < CDAlbum
	def initialize
		super
		@properties.merge!({ :artist => [false,true], :genre => [false,true], :producer => [false,true], :albumArtURI => [false,true], :toc => [false,false] })
	end
end

end #module

x = AV::CDContainer.new
puts x.requiredProperty?(:id)
puts x.requiredProperty?(:childCount)


