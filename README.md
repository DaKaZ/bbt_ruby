Beebotte ruby gem
=================


THIS IS ALPHA SOFTWARE - USE AT YOUR OWN PERIL

Example usage:
--------------
```
b = Beebotte::Connector.new("<yourApiKey>", "<yourSecretKey>", 'api.beebotte.com', 443)

channel_name = SecureRandom.hex(8)
resource_name = SecureRandom.hex(8)
resource_name2 = SecureRandom.hex(8)

puts "\n\n---------\nadd_channels:"
channel = {"name":channel_name, "resources": [{"name":resource_name, "vtype":"any"}]}
b.add_channel(channel) {|r, code| puts "(#{code}) #{r.inspect}" }

puts "\n\n---------\nwrite:"
b.write(channel_name, resource_name, { id: rand(1000000), status:"A sample write message"})

puts "\n\n---------\npublish:"
b.publish(channel_name, resource_name, { id: rand(1000000), status:"A sample publish message"})

puts "\n\n---------\nread:"
b.read({channel: channel_name, resource: resource_name, limit: 1}) {|r, code| puts "(#{code}) #{r.inspect}"}


puts "\n\n---------\nadd_resource:"
resource2 = {"name":resource_name2, "vtype":"any"}
b.add_resource(channel_name, resource2) {|r, code| puts "(#{code}) #{r.inspect}"}

puts "\n\n---------\ndel_resource:"
b.del_resource(channel_name, resource_name2) {|r, code| puts "(#{code}) #{r.inspect}"}

puts "\n\n---------\nget_channels:"
b.get_channels {|r, code| puts "(#{code}) #{r.inspect}"}

puts "\n\n---------\nget_channel:"
b.get_channel(channel_name) {|r, code| puts "(#{code}) #{r.inspect}"}

puts "\n\n---------\nget_connections:"
b.get_connections {|r, code| puts "(#{code}) #{r.inspect}"}

puts "\n\n---------\nget_resources:"
b.get_resources(resource_name) {|r, code| puts "(#{code}) #{r.inspect}"}


puts "\n\n---------\ndel_channel:"
b.del_channel(channel_name) {|r, code| puts "(#{code}) #{r.inspect}"}

```

TODO:
-----
1. Documentation
1. Testing
1. Bulk API
1. Stream API