require_relative 'utils'
#require 'pry'

class FingerEntry
  attr_reader :start, :interval
  attr_accessor :node
  
  def initialize(start, finish, node)
    @start = start
    @interval = ClosedOpenInterval.new(start, finish)
    @node = node
  end

  def display
    print @start.to_s + " "
    @interval.display
    print " " + @node.id.to_s + "\n"
  end
end

class Node

  attr_reader :id
  attr_reader :predecessor
  attr_reader :finger

  def initialize(id)
    @id = id
    @data = {}

    @finger = []
    for i in 0...M do
      start = (@id + 2**i) % KEYSPACE_SIZE
      finish = (@id + 2**(i+1)) % KEYSPACE_SIZE
      @finger.push(FingerEntry.new(start, finish, self))
    end
  end

  def print_fingers
    @finger.each do |x|
      x.display
    end
    nil
  end

  def successor
    if @finger.empty?
      nil
    else
      @finger[0].node
    end
  end

  def predecessor=(n)
    puts "set predecessor of " + self.id.to_s + " to " + n.id.to_s
    @predecessor = n
  end

  def add_finger(f)
    @finger.push(f)
  end

  def join(n)
    @predecessor = nil
    if not n.nil?
      @finger[0].node = n.find_successor(@id)
      stabilize
      n.stabilize
    end

    stabilize_thread = Thread.new do
      while true
        sleep(1)
        stabilize()
        fix_fingers()
      end
    end
  end

  def stabilize
    x = successor.predecessor
    r = OpenOpenInterval.new(@id, successor.id)
    if not x.nil? and (r.contains? x.id or @id == successor.id)
      @finger[0].node = x
    end
    successor.notify(self)
  end

  def notify(n)
    if (n != self and @predecessor.nil?) or
      (not @predecessor.nil? and OpenOpenInterval.new(@predecessor.id, @id).contains? n.id)
      @predecessor = n
    end
  end

  def fix_fingers
    i = Random.rand(M)
    @finger[i].node = find_successor(@finger[i].start)
  end

  # finds the node whose id is equal to or greater than key
  def find_successor(key)
    if key == @id
      return self
    end
    
    n = find_predecessor(key)
    n.successor
  end

  def find_predecessor(key)
    #    binding.pry
    n = self
    r = OpenClosedInterval.new(n.id, n.successor.id)

    while not r.contains? key
      n = n.closest_preceding_finger(key)
#      puts n.id, n.successor.id
      r = OpenClosedInterval.new(n.id, n.successor.id)
    end

    n
  end

  def closest_preceding_finger(key)
#    binding.pry
    r = OpenOpenInterval.new(@id, key)
    @finger.reverse_each do |f|
      if (r.contains? f.node.id)# or @id == key)
        return f.node
      end
    end

    #    return self
    return @predecessor
  end
      

  def owns?(key)
    if @predecessor.nil?
      return true
    end

    r = OpenClosedInterval.new(@predecessor.id, @id)
    r.contains? key
  end

  def store(key, value)
    if owns? key
      @data[key] = value
    else
      successor.store(key, value)
    end
  end

  def get(key)
    if owns? key
      @data[key]
    else
      n = find_successor(key)
      n.get(key)
    end
  end
  
end

=begin
a = Node.new 0
b = Node.new 1
c = Node.new 3

a.predecessor = c
b.predecessor = a
c.predecessor = b

a.add_finger FingerEntry.new(1, 2, b)
a.add_finger FingerEntry.new(2, 4, c)
a.add_finger FingerEntry.new(4, 0, a)

b.add_finger FingerEntry.new(2, 3, c)
b.add_finger FingerEntry.new(3, 5, c)
b.add_finger FingerEntry.new(5, 1, a)

c.add_finger FingerEntry.new(4, 5, a)
c.add_finger FingerEntry.new(5, 7, a)
c.add_finger FingerEntry.new(7, 3, a)
=end
