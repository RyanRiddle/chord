require_relative 'utils'
require 'pry'

require 'socket'

class FingerEntry
  attr_reader :start, :interval
  attr_accessor :noderef
  
  def initialize(start, finish, noderef)
    @start = start
    @interval = ClosedOpenInterval.new(start, finish)
    @noderef = noderef
  end

  def display
    print @start.to_s + " "
    @interval.display
    print " " + @noderef.id.to_s + "\n"
  end
end

class NodeReference
  attr_reader :id
  attr_reader :addr
  attr_reader :port

  def initialize(id, addr, port)
    @id = id
    @addr = addr
    @port = port
  end

	def connect
		begin
			s = TCPSocket.new(@addr, @port)
		rescue Errno::ECONNREFUSED
			nil
		end
	end

	def online?
		s = connect
		if s.nil?
			return false
		end
	
		s.close
		true
	end

	def predecessor
		s = connect
		if not s.nil?
			s.puts("PREDECESSOR\n")
			response = s.gets.chomp
			s.close

			tokens = response.split
			NodeReference.new(tokens[1], tokens[3], tokens[5])
		end
	end

	def successor
		s = connect
		if not s.nil?
			s.puts("SUCCESSOR\n")
			response = s.gets.chomp
			s.close

			tokens = response.split
			NodeReference.new(tokens[1], tokens[3], tokens[5])
		end
	end

	def notify(n)
		s = connect
		if not s.nil?
			id = n.id
			addr = n.addr
			port = n.port
			s.puts("NOTIFY ID #{id} ADDR #{addr} PORT #{port}\n")
			s.close
		end
	end

	def store(key, value)
		s = connect
		if not s.nil?
			s.puts "STORE #{key} #{value}\n"
			# don't want server to chomp any newlines at the end of value.
			# how do we fix this?
			s.close
		end
	end

	def replicate(key, value)
		s = connect
		if not s.nil?
			s.puts "REPLICATE #{key} #{value}\n"
			s.close
		end
	end

end

class Node

  attr_reader :id
  attr_reader :predecessor
  attr_reader :finger
  attr_reader :data
  attr_accessor :alive
  attr_accessor :successor_list

  def initialize(id, addr, port)
    @alive = true
    @id = id
    @data = {}

		@addr = addr
		@port = port

		ref = NodeReference.new @id, @addr, @port
    @finger = []
    for i in 0...M do
      start = (@id + 2**i) % KEYSPACE_SIZE
      finish = (@id + 2**(i+1)) % KEYSPACE_SIZE
      @finger.push(FingerEntry.new(start, finish, ref))
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
      @finger[0].noderef
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

	def handle_request(socket)
		req = socket.gets.chomp
		if req == "PREDECESSOR"
			id = @predecessor.id
			addr = @predecessor.addr
			port = @predecessor.port
			response = "ID #{id} ADDR #{addr} PORT #{port}\n"

			socket.puts response
		elsif req == "SUCCESSOR"
			s = successor
			id = s.id
			addr = s.addr
			port = s.port
			response = "ID #{id} ADDR #{addr} PORT #{port}\n"

			socket.puts response
		elsif req.start_with? "NOTIFY"
			tokens = req.split
			noderef = NodeReference.new tokens[2], tokens[4], tokens[6]
			notify noderef
		elsif req.start_with? "STORE"
			tokens = req.split
			store tokens[1], tokens[2]
		elsif req.start_with "REPLICATE"
			tokens = req.split
			replicate tokens[1], tokens[2]
		end

		socket.close
	end

  def join(n)
    @predecessor = nil
    if not n.nil?
      @finger[0].noderef = n.find_successor(@id)
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

    server_thread = Thread.new do
      server = TCPServer.new(@addr, @port)
      loop do
				Thread.start(server.accept) do |s|
					handle_request s
				end
      end
    end
  end


  def send(addr, port, msg)
    s = TCPSocket.new(addr, port)
    s.puts(msg)
    puts s.gets
  end

  def update_successor_list
    # successor_list[0] is not the same as finger[0].  it is finger[0].successor

    s = successor
    for i in 0...M do
      if s.nil? or not s.online?
        break
      end
      
      s = s.successor
      successor_list[i] = s
    end
  end

  def stabilize
    s = successor
    while s.nil? or not s.online?
      s = next_successor
    end

    if s.nil?
      puts "None of node #{@id}'s successors are online!"
			# should we exit here?
			return
    end

    x = s.predecessor
    if not x.nil? and not x.online?
      x = s
    end
    
    r = OpenClosedInterval.new(@id, s.id)
    if not x.nil? and (r.contains? x.id or @id == successor.id)
      @finger[0].noderef = x
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
    if (n.id != @id and (@predecessor.nil? or not @predecessor.alive)) or
      (not @predecessor.nil? and OpenOpenInterval.new(@predecessor.id, @id).contains? n.id)
      @predecessor = n
      transfer_keys n
    end
  end

  def fix_fingers(i=nil)
    if i.nil?
      i = Random.rand(M)
    end
    
    @finger[i].noderef = find_successor(@finger[i].start)
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
        if not s.nil? and s.online?
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
