#######################################################################
# Use this script to spin up a node on a machine.
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
# Also, the last line makes the new node join an existing network.
# Either provide the address and port of a node in an existing network.
# Or pass nil to Node::join 
#######################################################################

require_relative 'lib/chord'

puts "Remember to set the right connection parameters"
@a = Node.new "localhost", 50000, "tmpdata"
@a.join NodeReference.new "localhost", 50001


