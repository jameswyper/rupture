require_relative '../../lib/tapiola/Metadata/metaconfig.rb'

require 'minitest/autorun'

class Test_config < Minitest::Test
	
	def setup
		f = File.new(File.expand_path('~/.config/metascan'),"w")
		g = File.new(File.expand_path('~/testy.testy'),"w")
		f.write("MusicBrainz_Server: 192.168.0.10")
		g.write("AcoustID_Server: ac.com\n")
		g.write("DiscID_offsets:\n")
		g.write(" - 150\n")
		g.write(" - 160\n")
		f.close
		g.close
	end
	
	def test_stdfile
		o1 = Meta::Config.new(["directory","-a","no","-d","no"])
		o1.instance_variables.each  {|v| puts "#{v}: #{o1.instance_variable_get(v)}" }
		assert_equal(0,o1.errors.size)
		assert_equal("directory",o1.directory)
		assert_equal("192.168.0.10",o1.mbserver)
		assert_equal("acoustid.org",o1.acserver)
		assert_equal(7,o1.offsets.size)
		end
	
	def test_customfile
		o1 = Meta::Config.new(["director2","-c","~/testy.testy"])
		o1.instance_variables.each  {|v| puts "#{v}: #{o1.instance_variable_get(v)}" }
		assert_equal(0,o1.errors.size)
		assert_equal("director2",o1.directory)
		assert_equal("musicbrainz.org",o1.mbserver)
		assert_equal("ac.com",o1.acserver)
		assert_equal(2,o1.offsets.size)
		assert_equal(160,o1.offsets[1])
	end
	
	def teardown
		File.delete(File.expand_path('~/.config/metascan'))
		File.delete(File.expand_path('~/testy.testy'))
	end
	
end

class Test_config_nofile < Minitest::Test
	
	def setup
	end
	
	def test_stdfile
		o1 = Meta::Config.new(["director2"])
		assert_equal(1,o1.errors.size)
	end
	
	def test_customfile
		o1 = Meta::Config.new(["director2","-c","~/testy.testy"])
		assert_equal(1,o1.errors.size)
	end
	
	def test_nodir
		o1 = Meta::Config.new([])
		assert_equal(2,o1.errors.size)
	end
	
	def teardown
	end
	
end