require  'rexml/document'
require  'rexml/xpath'
require 'pry'

TX = <<ENDXML
<?xml version="1.0? encoding="utf-8??>
<s:Envelope s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
<s:Body>
<u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
<InstanceID>0</InstanceID>
<CurrentURI><![CDATA[http://my.site.com/path/to/my/content.mp4]]>
</CurrentURI>
<CurrentURIMetaData></CurrentURIMetaData>
</u:SetAVTransportURI>
</s:Body>
</s:Envelope>
ENDXML


doc = REXML::Document.new TX

x = REXML::XPath.first(doc, "//m:Envelope/m:Body", {"m"=>"http://schemas.xmlsoap.org/soap/envelope/"})
puts x.name, x.expanded_name
y =  REXML::XPath.first(x,"//p:SetAVTransportURI",{"p" => "urn:schemas-upnp-org:service:AVTransport:1"})
action = y.name
puts action
y.elements.each {|z| puts "name = #{z.name}, value = \"#{z.text}\""}

s = '"aaaaa#bbb"'
s = nil
re = /^"(.*)#(.*)"$/
md = re.match(s)
if (md[1] != nil) && (md[2] != nil)
	puts md[1], md[2]
end


#x = doc.elements("//m:Envelope", {"m"=>"http://schemas.xmlsoap.org/soap/envelope/"})
#x.each {|y| puts ">> #{y}"}

#binding.pry


=begin
get action name from headers
get envelopes, count them
warn if > 1
for each envelope
check a body child exists
find an element with the same action name
get values of child elements
=end
