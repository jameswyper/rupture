require 'UPnPBase.rb'

=begin rdoc
    
    initialisation: 
    create a response queue object to hold responses
    create a multicast queue object to hold advertisments / bye-byes
    
    normal running:
    set up three threads
    
    1st will sit for a while and occasionally push advertisment messages to the queue
    2nd will block waiting for multicast messages from other clients, when one arrives it will generate responses and add them to the queue
    3rd will process both queues sending unicast or multicast messages as required
    
    each thread loops while a "terminated" condition is true or (for 3rd thread) bye-byes not sent
    
    termination:
    
    set "terminated" condition to false for 1st and 2nd threads
    add bye-bye messages to queue
    
    
=end