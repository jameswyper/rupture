
module Base
     class Base1
		def hello
			puts "hello from base1"
		end
     end
end

require_relative'base2/base2.rb'
