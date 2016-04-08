
require_relative 'UPnPBase'

root = UPnPRootDevice.new("test_type",2,"127.0.0.1",54321,"test UPnP server v0000")
root.addService(UPnPService.new("test_service",9))

puts root.keepAlive

puts root.byeBye

#todo - why aren't embedded devices / services working?
# add search stuff
# binding.pry (require pry)