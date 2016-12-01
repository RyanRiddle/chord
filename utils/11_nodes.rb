######################################################################
# Use this script to launch 11 nodes on a machine.  This is useful if
# you want to simulate a DHT but only have one box available.
# Consider changing these parameters before running...
# addr - this is the address a node tells other nodes to use when
#        connecting to it.  The default value is "localhost" which
#        will not work because Node objects do not listen for connection
#        on their loop back address.
# port - this is the port the node listens on.  The default is 50000.
# dir  - this is the directory in which the node stores its data.  
#        Nodes write their data to disk in case the data is too big for
#        memory.  Change this paramater if you want to store your data
#        in a more conspicuous location.
######################################################################


require_relative 'lib/chord'

puts "You might want to edit the connection parameters before running (details in comments)"

addr = 'localhost'
port = 50000 
dir = "tmpdata"

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

