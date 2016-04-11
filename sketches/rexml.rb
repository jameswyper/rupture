require 'rexml/document'
include REXML
d = Document.new 
d.add_element("root")

d.write $stdout