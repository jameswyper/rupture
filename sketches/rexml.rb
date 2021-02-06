require 'rexml/document'

d = REXML::Document.new 
e = d.add_element("DIDL-Lite")
e.add_namespace('dc','http://purl.org/dc/elements/1.1')
i = e.add_element("item")
t = i.add_element("dc:title")
t.text = "Desert Rose"


d.write $stdout

puts d.root