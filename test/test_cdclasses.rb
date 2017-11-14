

=begin

	
=end

require 'minitest/autorun'
require_relative '../lib/tapiola/AV/classes.rb'
require  'rexml/document'
require 'pry'

class TestBaseClass < Minitest::Test
	
		
	def setup


	end
	

	def test_simple
		
		c0 = AV::CDContainer.new(:CDContainer,nil)
		c0.addProperty(:restricted,"true")
		c0.addProperty(:title,"title for c0")
		i10 = AV::CDContainer.new(:CDContainer,c0)
		i10.addProperty(:restricted,"true")
		i10.addProperty(:title,"title for i10")
		c11 = AV::CDContainer.new(:CDItem,c0)
		c11.addProperty(:restricted,"true")
		c11.addProperty(:title,"title for c11")
		c12 = AV::CDContainer.new(:CDItem,c0)
		c12.addProperty(:title,"title for c12")
		
		assert_raises AV::CDSetupError do 
			j0 = AV::CDContainer.new(:rubbish,nil)
		end
		
		j1 = AV::CDContainer.new(:CDItem,nil)
		assert_raises AV::CDSetupError do
			j1.addProperty(:rubbish,0)
		end
		
		c0.checkProperties
		i10.checkProperties
		c11.checkProperties
		
		assert_raises AV::CDSetupError do
			c12.checkProperties
		end
		
		c12.addProperty(:restricted,"true")		
		
		c12.checkProperties
		
		
	end	
	
	
	def teardown

		
	end
	
end

