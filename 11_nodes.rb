require_relative 'lib/chord'

puts "You probably want to edit the connection parameters before running"

addr = 'localhost'
port = 50000 
dir = "data"

alpha = Node.new addr, port, dir
alpha.join nil
puts "Listening on #{addr}:#{port}"

nodes = (1..10).collect do |i|
	n = Node.new addr, port+i, dir
	n.join alpha.ref
	puts "Listening on #{addr}:#{port+i}"
	n
end

@nodes = [alpha] + nodes

#dead = (50101..50150).select { |port| not (NodeReference.new 'localhost', port).online? }
#puts dead.count
=begin
dead.each do |port|
	(Node.new 'localhost', port, dir).join alpha.ref
end

puts (50000..50100).count { |port| (NodeReference.new 'localhost', port).online? }
=end
