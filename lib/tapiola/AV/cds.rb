

require 'rexml/document'

module AV

class CDSetupError < ::StandardError
end

class CDObject
	PropertyMeta = Struct.new(:xmlType, :namespace, :required, :multiValued)
#
#  set up the properties for the base Content Directory Object in a hash
#	
	@@properties = {
					:CDObject => 
					{ 	:id => PropertyMeta.new( :attribute, "", true, false),
						:parentID => PropertyMeta.new(:attribute, "", true, false),
						:title => PropertyMeta.new(:element,:dc,true,false),
						:creator => PropertyMeta.new(:element,:dc,false,false),
						:res => PropertyMeta.new(:element, "",false,true),
						:class => PropertyMeta.new(:element, :upnp,true,false),
						:restricted => PropertyMeta.new(:attribute, "",true,false),
						:writeStatus => PropertyMeta.new(:element, :upnp,false,false)
					}
				}
#				
#  set up the properties for derived objects by adding a new entry to the top level hash 
#  that combines the properties of the new class and the class it is derived from
#
	@@properties.merge! ({ :CDItem => @@properties[:CDObject].merge(
					{
					:refID => PropertyMeta.new(:attribute,"",false,false),
					}
					)  })
# and so on..					
	@@properties.merge! ({ :CDContainer => @@properties[:CDObject].merge(
					{
					:childCount => PropertyMeta.new(:attribute,"",false,false),
					:createClass => PropertyMeta.new(:element,:upnp,false,true),
					:searchClass => PropertyMeta.new(:element,:upnp,false,true),
					:searchable => PropertyMeta.new(:attribute,:upnp,false,false)
					}
					)  })
	@@properties.merge! ({ :CDAlbum => @@properties[:CDContainer].merge(
					{
					:storageMedium => PropertyMeta.new(:element,:upnp,false,false),
					:longDescription => PropertyMeta.new(:element,:upnp,false,false),
					:description => PropertyMeta.new(:element,:dc,false,false),
					:publisher => PropertyMeta.new(:element, :dc,false,true),
					:contributor => PropertyMeta.new(:element, :dc,false,true),
					:date => PropertyMeta.new(:element, :dc,false,false),
					:relation => PropertyMeta.new(:element, :dc,false,true),
					:rights => PropertyMeta.new(:element, :dc,false,true)
					}
					)  })
	@@properties.merge! ({ :CDMusicAlbum => @@properties[:CDAlbum].merge(
					{
					:artist => PropertyMeta.new(:element,:upnp,false,true),
					:genre => PropertyMeta.new(:element,:upnp,false,true),
					:producer => PropertyMeta.new(:element,:upnp,false,true),
					:albumArtURI => PropertyMeta.new(:element,:upnp,false,true),
					:toc => PropertyMeta.new(:element,:upnp,false,false)
					}
					)  })
	@@classes = { :CDItem => "object.item", 
				:CDContainer => "object.container", 
				:CDAlbum => "object.container.album", 
				:CDMusicAlbum => "object.container.musicAlbum"}
	 
	 
	@@id = 0

	attr_reader :type
	attr_reader :property
	attr_reader :id
	
	def initialize(classname, parent)

		@property = Hash.new
		@classname = classname
		@updateID = 0
		if (@type = @@classes[classname] == nil)
			raise CDSetupError, "class #{classname} undefined"
		else
			self.addProperty(:class,@@classes[classname])
		end

		@id = @@id
		@@id = @@id + 1

		self.addProperty(:id,@id)
		@parent = parent
		if (parent)
			@parent.addChild(self)
			self.addProperty(:parentID,@parent.id)
		else
			self.addProperty(:parentID,-1)
		end
	end
	
	def addProperty(name,value)
		p = @@properties[@classname][name]
		if p
			@property[name] = value
		else
			raise CDSetupError, "Property #{name} not defined for class #{@classname}"
		end
		@updateID = @updateID + 1
		# todo handle multiple values
	end
	
	def checkProperties
		ok = true
		missing = Array.new
		required = Hash.new
		@@properties[@classname].each do |k,v|
			if v.required
				required[k] = false
			end
		end
		@property.each do |k,v|
			if required[k] != nil
				required[k] = true
			end
		end
		required.each do  |k,v|
			ok = ok && v
			if (!v)
				missing << k
			end
		end
		if !ok
			raise CDSetupError, "required properties #{missing.to_s} missing for #{@classname}"
		end
	end
	
	def XMLFragment(doc,filter)
		object_or_container = @children ? "container" : "object"
		obj = doc.root.add_element(object_or_container)
		@property.each do |k,val|
			attrs = @@properties[@classname][k]
			if (filter == '*') || (filter.include? k.to_s) || (attrs.required)
				if attrs.xmlType == :attribute
					obj.add_attribute(k.to_s,val)
				else
					element = attrs.namespace.to_s + ':' + k.to_s
					obj.add_element(element).add_text(val)
				end
			end
		end
		return doc
	end
		
	
end

class CDItem < CDObject
	def initialize(classname,parent)
		super
	end
end

class CDContainer < CDObject
	
	def initialize(classname, parent)
		super
		@children = Array.new
		@updateID = 0
	end

	def addChild(child)
		@children << child
	end
	
	def removeChild(child)
		@children.delete(child)
	end
	
	def getChildren(object,sort,offset,limit)
		if (@@cacheObject != object || @@cacheSort != sort)
			@@cacheChildren = getAllChildren(object,sort)
		end
		s = @@cacheChildren.size
		if (offset > s)
			return Array.new
		end
		if ((offset + limit - 1) > s)
			return @@cacheChildren[offset..s]
		else
			return @@cacheChildren[offset..(offset + limit -1)]
		end
	end
	
	def getAllChildren(object,sort)
		@@cacheObject = object
		@@cacheSort = sort
		if sort.empty?
			return @children
		else
			return @children.sort do |x,y|
				sort.each do |p|
					if x.property[p] > y.property[p]
						return 1
					else
						if x.property[p] < y.property[p]
							return -1
						end
					end
					return 0
				end
			end
		end
	end
	

end

end #module



