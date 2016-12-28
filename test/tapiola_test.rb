
require_relative '../lib/tapiola/UPnP'
#require 'pry'

root = UPnP::RootDevice.new("test_type",2,"127.0.0.1",54321,"test UPnP server v0000")
root.addService(UPnP::Service.new("test_service",9))
root.addService(UPnP::Service.new("test_other_service",8))

#root.keepAlive.each { |s| puts s}

#root.byeBye.each { |s| puts s }

m= "M-SEARCH * HTTP 1.1\nHOST: 239.255.255.150:1900\nMAN: "
m << '"ssdp:discover"'
m << "\nMX: 35\nST: "

m1 = m + "ssdp:all"
m2 = m + "upnp:rootdevice"
m3 = m + "urn:schemas-upnp-org:service:test_service:8"
m4 = m + "urn:schemas-upnp-org:device:test_type:2"
m5 = m + "uuid:" + root.uuid




puts m5

delay, response = root.handleSearch(m1)

puts "response: delay=" + delay
puts response

d = REXML::Document.new
d << REXML::XMLDecl.new
d << REXML::Element.new("root")
root.deviceXMLDescription.each do |e|
	d.root.add_element(e)
end

d.write($stdout, 4)
puts


# add search stuff
