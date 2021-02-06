require_relative '../cds.rb'


o1 = AV::CDContainer.new(:CDMusicAlbum,nil)
o2 = AV::CDItem.new(:CDItem,o1)

o1.addProperty(:title,"test album")
o1.addProperty(:restricted,"false")
o1.checkProperties

doc = REXML::Document.new
doc.add_element("DIDL-Lite").add_namespace('dc','http://purl.org/dc/elements/1.1')

doc = o1.XMLFragment(doc,'*')

doc.write(:indent => 2)