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
					{ 	:id => PropertyMeta.new( :attribute, :DIDL, true, false),
						:parentID => PropertyMeta.new(:attribute, :DIDL, true, false),
						:title => PropertyMeta.new(:element,:DC,true,false),
						:creator => PropertyMeta.new(:element,:DC,false,false),
						:res => PropertyMeta.new(:element, :DIDL,false,true),
						:class => PropertyMeta.new(:element, :UPnP,true,false),
						:restricted => PropertyMeta.new(:attribute, :DIDL,true,false),
						:writeStatus => PropertyMeta.new(:element, :UPnP,false,false)
					}
				}
#				
#  set up the properties for derived objects by adding a new entry to the top level hash 
#  that combines the properties of the new class and the class it is derived from
#
	@@properties.merge! ({ :CDItem => @@properties[:CDObject].merge(
					{
					:refID => PropertyMeta.new(:attribute,:DIDL,false,false),
					}
					)  })
# and so on..					
	@@properties.merge! ({ :CDContainer => @@properties[:CDObject].merge(
					{
					:childCount => PropertyMeta.new(:attribute,:DIDL,false,false),
					:createClass => PropertyMeta.new(:element,:UPnP,false,true),
					:searchClass => PropertyMeta.new(:element,:UPnP,false,true),
					:searchable => PropertyMeta.new(:attribute,:UPnP,false,false)
					}
					)  })
	@@properties.merge! ({ :CDAlbum => @@properties[:CDContainer].merge(
					{
					:storageMedium => PropertyMeta.new(:element,:UPnP,false,false),
					:longDescription => PropertyMeta.new(:element,:UPnP,false,false),
					:description => PropertyMeta.new(:element,:DC,false,false),
					:publisher => PropertyMeta.new(:element, :DC,false,true),
					:contributor => PropertyMeta.new(:element, :DC,false,true),
					:date => PropertyMeta.new(:element, :DC,false,false),
					:relation => PropertyMeta.new(:element, :DC,false,true),
					:rights => PropertyMeta.new(:element, :DC,false,true)
					}
					)  })
	@@properties.merge! ({ :CDMusicAlbum => @@properties[:CDAlbum].merge(
					{
					:artist => PropertyMeta.new(:element,:UPnP,false,true),
					:genre => PropertyMeta.new(:element,:UPnP,false,true),
					:producer => PropertyMeta.new(:element,:UPnP,false,true),
					:albumArtURI => PropertyMeta.new(:element,:UPnP,false,true),
					:toc => PropertyMeta.new(:element,:UPnP,false,false)
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
	
	def createXMLFragment(filter)
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



