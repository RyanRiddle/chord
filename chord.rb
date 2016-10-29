require_relative 'utils'
require 'pry'

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
  attr_reader :data
  attr_accessor :alive
  attr_accessor :successor_list

  def initialize(id)
    @alive = true
    @id = id
    @data = {}

    @finger = []
    for i in 0...M do
      start = (@id + 2**i) % KEYSPACE_SIZE
      finish = (@id + 2**(i+1)) % KEYSPACE_SIZE
      @finger.push(FingerEntry.new(start, finish, self))
    end
    @successor_list = Array.new M
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

  def next_successor
    if @successor_list.empty?
      return nil
    end
    
    n = @successor_list[0]
    @successor_list = @successor_list.slice(1, @successor_list.length)
    n
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

  def update_successor_list
    # successor_list[0] is not the same as finger[0].  it is finger[0].successor

    s = successor
    for i in 0...M do
      if s.nil? or not s.alive
        break
      end
      
      successor_list[i] = s.successor
      s = s.successor
    end
  end

  def stabilize
    s = successor
    while not ping s
      s = next_successor
    end

    if s.nil?
      puts "None of node #{@id}'s successors are online!"
    end

    x = s.predecessor
    if not x.nil? and not ping x
      x = s
    end
    
    r = OpenClosedInterval.new(@id, s.id)
    if not x.nil? and (r.contains? x.id or @id == successor.id)
      @finger[0].node = x
    end

    update_successor_list    

    successor.notify(self)

  end

  def transfer_keys(n)
    r = OpenClosedInterval.new(@id, n.id)
    transfers = {}
    
    @data.each do |key, value|
      if r.contains? key
        transfers[key] = value
        @data.delete key
      end
    end

    transfers.each do |key, value|
      n.store(key, value)
    end
  end

  def notify(n)
    if (n != self and (@predecessor.nil? or not @predecessor.alive)) or
      (not @predecessor.nil? and OpenOpenInterval.new(@predecessor.id, @id).contains? n.id)
      @predecessor = n
      transfer_keys n
    end
  end

  def fix_fingers(i=nil)
    if i.nil?
      i = Random.rand(M)
    end
    
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

  def replicate(key, value)
    @data[key] = value
  end

  def store(key, value)
    if owns? key
      @data[key] = value
      successor.replicate(key, value)
      @successor_list.each do |s|
        if not s.nil? and s.alive
          s.replicate(key, value)
        end
      end
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

  def ping(n)
    n.alive
  end
  
end
