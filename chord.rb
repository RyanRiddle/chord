require 'pry'

require_relative 'finger_entry'
require_relative 'node_reference'

class Node

  attr_reader :id
  attr_reader :predecessor
  attr_reader :finger
  attr_reader :data
  attr_accessor :successor_list

  def initialize(id, addr, port)
    @id = id
    @data = {}

		@addr = addr
		@port = port

		@ref = NodeReference.new @id, @addr, @port
    @finger = []
    for i in 0...M do
      start = (@id + 2**i) % KEYSPACE_SIZE
      finish = (@id + 2**(i+1)) % KEYSPACE_SIZE
      @finger.push(FingerEntry.new(start, finish, @ref))
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
			unless @predecessor.nil?
				id = @predecessor.id
				addr = @predecessor.addr
				port = @predecessor.port
				response = "ID #{id} ADDR #{addr} PORT #{port}\n"
			else
				response = "ERROR"
			end

			socket.puts response
		elsif req == "SUCCESSOR"
			s = successor
			id = s.id
			addr = s.addr
			port = s.port
			response = "ID #{id} ADDR #{addr} PORT #{port}\n"

			socket.puts response
		elsif req == "STABILIZE"
			stabilize
		elsif req.start_with? "FIND SUCCESSOR"
			tokens = req.split
			key = tokens[2].to_i

			noderef = find_successor key
			id = noderef.id
			addr = noderef.addr
			port = noderef.port
			response = "ID #{id} ADDR #{addr} PORT #{port}\n"
			socket.puts response
		elsif req.start_with? "CLOSEST PRECEDING FINGER"
			tokens = req.split
			key = tokens[3].to_i

			noderef = closest_preceding_finger key
			id = noderef.id
			addr = noderef.addr
			port = noderef.port
			response = "ID #{id} ADDR #{addr} PORT #{port}\n"
			socket.puts response
		elsif req.start_with? "NOTIFY"
			tokens = req.split
			id = tokens[2].to_i
			addr = tokens[4]
			port = tokens[6].to_i
			noderef = NodeReference.new id, addr, port
			notify noderef
		elsif req.start_with? "STORE"
			tokens = req.split
			store tokens[1].to_i, tokens[2]
		elsif req.start_with? "REPLICATE"
			tokens = req.split
			replicate tokens[1].to_i, tokens[2]
		elsif req.start_with? "GET"
			tokens = req.split
			key = tokens[1].to_i
			value = get key
			response = "VALUE #{value}\n"
			socket.puts response
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
				# do i need to kill this thread?
      end
    end
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

		# i think i need to change successor to s
    successor.notify(@ref)

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
    if (n.id != @id and (@predecessor.nil? or not @predecessor.online?)) or
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
      return @ref
    end
    
    n = find_predecessor(key)
    n.successor
  end

  def find_predecessor(key)
    #    binding.pry
    n = @ref
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
      if (r.contains? f.noderef.id)# or @id == key)
        return f.noderef
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
end
