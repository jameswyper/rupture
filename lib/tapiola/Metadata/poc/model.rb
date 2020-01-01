require 'active_record'

module Model

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: '/tmp/mb.db'
)

class Artist < ActiveRecord::Base
  has_many :artist_alias
  has_many :artist_credit_name
  has_many :l_artist_work
 end

class ArtistCredit < ActiveRecord::Base
  has_many :artist_credit_name
  has_many :recording
  has_many :track
  has_many :release
  has_many :release_group
end

class ArtistCreditName < ActiveRecord::Base
  belongs_to :artist
  belongs_to :artist_credit
end

class Recording < ActiveRecord::Base
  belongs_to :artist_credit
  has_many :track
  has_many :work_link, class_name: 'LRecordingWork', foreign_key: :recording_id
  
  def works
	  w = Array.new
	  self.work_link.joins(:link_type).merge(LinkType.recordingOf).each { |r| w << r.work }
	  return w
  end
  
end

class Track < ActiveRecord::Base
  belongs_to :recording
  belongs_to :medium
  belongs_to :artist_credit
end

class Medium < ActiveRecord::Base
  has_many :track
  belongs_to :release
  has_many :medium_cdtoc
  has_many :cdtoc, through: :medium_cdtoc
#  belongs_to :format
end

class MediumCdtoc < ActiveRecord::Base
  belongs_to :cdtoc
  belongs_to :medium
end

class Cdtoc < ActiveRecord::Base
  has_many :medium_cdtoc
  has_many :medium, through: :medium_cdtoc
end

class Release < ActiveRecord::Base
  belongs_to :artist_credit
  has_many :medium
end

class ReleaseGroup < ActiveRecord::Base
	has_many :release
	belongs_to :artist_credit
end

class Disc < ActiveRecord::Base
	has_many :file
	has_many :mediumOffsetCandidate
	has_many :mediumAcoustCandidate
end

class File < ActiveRecord::Base
	belongs_to :disc
	has_many :tag
end

class Tag < ActiveRecord::Base
	belongs_to :file
end

class MediumOffsetCandidate < ActiveRecord::Base
	belongs_to :disc
	belongs_to :medium
end

class MediumAcoustCandidate < ActiveRecord::Base
	belongs_to :disc
	belongs_to :medium
end

class Work < ActiveRecord::Base
	belongs_to :work_type
	has_many :work_alias
	has_many :artist_link, class_name: 'LArtistWork', foreign_key: :work_id
	has_many :parent_link, class_name:'LWorkWork', foreign_key: :work1_id
	has_many :child_link, class_name:'LWorkWork', foreign_key: :work0_id
	has_many :recording_link, class_name: 'LRecordingWork', foreign_key: :work_id
	has_many :work_attribute
	
	def parent_parts
		pw = Array.new
		self.parent_link.joins(:link_type).merge(LinkType.workParts).each do |pl|
				pw << pl.parent_work
		end
		return pw
	end
	
	def has_parent_part?
		(parent_parts.size > 0)
	end
	
	def has_key?
		self.work_attribute.where(work_attribute_type: WorkAttributeType.where(name: "Key")[0].id).size > 0
	end
	
	def composers
		c = Array.new
		self.artist_link.joins(:link_type).merge(LinkType.composedBy).each {|n| c << n.artist}
		return c
	end
	
end

class WorkType < ActiveRecord::Base
	has_many :work
end

class WorkAlias < ActiveRecord::Base
	belongs_to :work
end

class LArtistWork < ActiveRecord::Base
	belongs_to :work
	belongs_to :artist
	belongs_to :link
	has_one :link_type, through: :link
end

class Link < ActiveRecord::Base
	has_one :l_artist_work
	has_one :l_work_work
	belongs_to :link_type
end

class LinkType < ActiveRecord::Base
	has_many :link
	scope :composedBy, -> {where('entity_type0 = ? and entity_type1 = ? and name = ?','artist','work','composer') }
	scope :recordingOf, -> {where('entity_type0 = ? and entity_type1 = ? and name = ?','recording','work','performance') }
	scope :workParts, -> {where('entity_type0 = ? and entity_type1 = ? and name = ?','work','work','parts') }
end

class LWorkWork < ActiveRecord::Base
	belongs_to :child_work, class_name: 'Work', foreign_key: :work1_id
	belongs_to :parent_work, class_name: 'Work', foreign_key: :work0_id
	belongs_to :link
	has_one :link_type, through: :link
end

class WorkAttribute < ActiveRecord::Base
	belongs_to :work
	belongs_to :work_attribute_type
	belongs_to :work_attribute_type_allowed_value
end

class WorkAttributeType < ActiveRecord::Base
	has_many :work_attribute
end

class WorkAttributeTypeAllowedValue < ActiveRecord::Base
	belongs_to :work_attribute_type
	has_many :work_attribute
end

class LRecordingWork < ActiveRecord::Base
	belongs_to :work
	belongs_to :recording
	belongs_to :link
	has_one :link_type, through: :link
end



end

