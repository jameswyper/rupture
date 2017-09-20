#The main UPnP file.  Require this to have access to all the UPnP code


module UPnP



end


require_relative 'UPnP/device.rb'
require_relative 'UPnP/rootDevice.rb'
require_relative 'UPnP/service.rb'
require_relative 'UPnP/icon.rb'
require_relative 'UPnP/action.rb'
require_relative 'UPnP/subscription.rb'

Thread.abort_on_exception = true






