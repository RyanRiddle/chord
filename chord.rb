require 'openssl'

KEYSPACE_SIZE = 8 #2**160

=begin
def hash(key)
  sha1 = OpenSSL::Digest::SHA1.new
  str = sha1.digest key.to_s
  hex_bytes = str.bytes.collect { |byte| "%02x" % byte }
  hex = hex_bytes.join("")
  OpenSSL::BN.new(hex, 16)
end


def generate_key
  hash(Time.now.to_s)
end
=end

def difference(a, b)
  (b - a) % KEYSPACE_SIZE
end

class Interval
  attr_reader :first
  attr_reader :last

  def initialize(first, last)
    @first = first
    @last = last
  end
end

class ClosedOpenInterval < Interval
  def contains? (val)
    difference(@first, val) < difference(@last, val)
  end
end

class OpenClosedInterval < Interval
  def contains? (val)
    difference(val, @last) < difference(val, @first)
  end
end

class OpenOpenInterval < Interval
  def contains? (val)
    d1 = difference(@first, val)
    d2 = difference(@last, val)

    0 < d1 and 0 < d2 and d1 < d2
  end
end

class FingerEntry
  attr_reader :start, :interval, :node
  
  def initialize(start, finish, node)
    @start = start
    @interval = ClosedOpenInterval.new(start, finish)
    @node = node
  end
end

class Node

  attr_reader :id

  def initialize(id)
    @id = id
    @data = {}
    @finger = []
  end

  def successor
    if @finger.empty?
      nil
    else
      @finger[0].node
    end
  end

  def predecessor=(n)
    @predecessor = n
  end

  def add_finger(f)
    @finger.push(f)
  end

  def find_successor(key)
    n = find_predecessor(key)
    n.successor
  end

  def find_predecessor(key)
    n = self
    r = OpenClosedInterval.new(n.id, n.successor.id)

    while not r.contains? key
      n = n.closest_preceding_finger(key)
      r = OpenClosedInterval.new(n.id, n.successor.id)
    end

    n
  end

  def closest_preceding_finger(key)
    r = OpenOpenInterval.new(@id, key)
    @finger.reverse_each do |f|
      if (r.contains? f.node.id)
        return f.node
      end
    end

    return self
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
