
require 'test/unit'
require_relative '../lib/tapiola/UPnPBase.rb'

class TestUPnPBase < Test::Unit::TestCase
	
	def setup
		@devtype = "test_type"
		@devver = 2
		@devip = "127.0.0.1"
		@devport = 54321
		@devdesc = "test UPnP server v0000"
		@devserv1 = "test service"
		@devserv2 = "test_other_service"
		@devservver1 = 9
		@devservver2  = 8
		
		@root = UPnPRootDevice.new(@devtype,@devver,@devip,@devport,@devdesc)
		@root.addService(UPnPService.new(@devserv1, @devservver1))
		@root.addService(UPnPService.new(@devserv2, @devservver2))
	end
	
	def teardown
	end

	def test_keepalive
		res = Array.new
		# split the answer into a 2D array of messages and lines in each message
		@root.keepAlive.each { |s| res.<<(s.split("\n")) }
		
		#check the content of the first message
		
		assert_equal('NOTIFY * HTTP/1.1',res[0][0])
		assert_equal('HOST: 239.255.255.250:1900',res[0][1])
		assert_equal('CACHE-CONTROL: max-age = ' + @root.cacheControl.to_s,res[0][2])
		assert_equal('LOCATION: http://' + @devip + ":" + @devport.to_s + '/rupture/description',res[0][3])
		assert_equal('NT: upnp:rootdevice',res[0][4])
		assert_equal('NTS: ssdp:alive',res[0][5])
		assert_equal('SERVER: Linux/3 UPnP/1.0 ' + @devdesc,res[0][6])
		assert_match(/USN: uuid:.*::upnp:rootdevice/,res[0][7])
		
		res[0][7] =~ /USN: uuid:(.*)::upnp:rootdevice/
		uu = $1
		assert_match(/[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}/,uu)
		
		
		# most of the lines in the subsquent messages (there are 5 in total) are the same as the first, so check those
		
		[0,1,2,3,5,6].each do |n|
			[1,2,3,4].each { |m| assert_equal(res[0][n],res[m][n]," line #{n} of message #{m} didn't match the first message")}
		end
			
		# now check lines [4] and [7] (the 5th and 8th lines)	
			
		assert_equal(res[1][4],"NT: uuid:"+uu)
		assert_equal(res[2][4],"NT: urn:schemas-upnp-org:device:#{@devtype}:#{@devver}")
		assert_equal(res[3][4],"NT: urn:schemas-upnp-org:service:#{@devserv1}:#{@devservver1}")
		assert_equal(res[4][4],"NT: urn:schemas-upnp-org:service:#{@devserv2}:#{@devservver2}")

		assert_equal(res[1][7],"USN: uuid:#{uu}")
		
		# why is devtype utf-8 and everything else not?
		
		assert_equal(res[2][7],"USN: uuid:#{uu}:urn-schemas-upnp-org:device:#{@devtype}:#{@devver}")
		assert_equal(res[3][7],"USN: uuid:#{uu}:urn-schemas-upnp-org:service:#{@devserv1}:#{@devservver1}")
		assert_equal(res[4][7],"USN: uuid:#{uu}:urn-schemas-upnp-org:service:#{@devserv2}:#{@devservver2}")		
	end


	def test_byebye
		bb= @root.byeBye
	end

end
