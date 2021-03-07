require 'citrus'
require 'tempfile'


g = Citrus.eval(<<HERE)
grammar Test

rule quotedVal
  /^"(?:[^"\\\\]|\\\\\\\\|\\\\")*"$/
end

# 
# /"((\\\\{2})*|(.*?[^\\\\](\\\\{2})*))"/

end
HERE

m = Test.parse '"fr\\"ed\\\\"'
m.dump

=begin
m = Predicate.parse '(name = "james" or name = "fred" or title = "mr")'
m = Predicate.parse 'name = "james" or name = "fr\\"ed" or title = "mr"'

m = Predicate.parse 'name = "banana"'


m = Predicate.parse 'name = "james" and name = "fred" or name = "banana"' 


m = Predicate.parse '(name = "james" and name = "fred") or name = "banana"' 

m = Predicate.parse 'name = "james" and name = "fred" or (name = "banana")'
m.dump
=end