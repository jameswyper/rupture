
require_relative 'UPnPBase'
require 'pry'

root = UPnPRootDevice.new("test_type",2,"127.0.0.1",54321,"test UPnP server v0000")
root.addService(UPnPService.new("test_service",9))
root.addService(UPnPService.new("test_other_service",8))

root.keepAlive.each { |s| puts s}

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

delay, response = root.handleSearch(m5)

puts "response: delay=" + delay
puts response

# add search stuff
