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
					:childCount => Property.new(:childCount, :attribute, :DIDL)
				}
end


class CDObject
	
	def properties
		{  	:id => [true,false], :parentID => [true,false], :title => [true,false], 
					:creator => [false,false], :res => [false,true], :class => [true,false], 	
					:restricted => [true,false],:writeStatus => [false,false] }
	end
	def requiredProperty?(prop)
		return properties[prop][0]
	end
	def multiValuedProperty?(prop)
		return properties[prop][1]
	end
	def initialize
		@parent = nil
	end
end

class CDItem < CDObject
	def properties
		super.merge( { :refID => [false,false] })
	end
	def initialize
		super
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
	def properties
		super.merge({ :childCount => [false,false], :createClass => [false,true], :searchClass => [false,true], :searchable => [false,false]})
	end
	def initialize
		super
		@children = Array.new
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

end #module

x = AV::CDContainer.new
puts x.requiredProperty?(:childCount)
