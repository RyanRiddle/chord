require_relative 'lib/chord'

puts "Remember to set the right connection parameters"
@a = Node.new "localhost", 50000, "tmpdata"
@a.join NodeReference.new "localhost", 50000


