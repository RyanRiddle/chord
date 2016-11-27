require_relative 'finger_entry'
require_relative 'node_reference'

class Node

  attr_reader :id
	attr_reader :ref
  attr_reader :predecessor
  attr_reader :finger
  attr_reader :data
  attr_accessor :successor_list

  def initialize(addr, port, dir)
    @data = {}
		@dir = File.absolute_path dir
		if not Dir.exist? @dir
			Dir.mkdir @dir
		else
			read_from_disk
		end

		@addr = addr
		@port = port
		@id = sha1 "#{@addr}:#{port}"

		@ref = NodeReference.new @addr, @port
    @finger = []
    for i in 0...M do
      start = (@id + 2**i) % KEYSPACE_SIZE
      finish = (@id + 2**(i+1)) % KEYSPACE_SIZE
      @finger.push(FingerEntry.new(start, finish, @ref))
    end
    @successor_list = Array.new NUM_ADJACENT
  end

	def read_from_disk
		Dir.foreach @dir do |filename|
			tokens = filename.split "_"
			hash = tokens[0].to_i
			key = tokens[1]
			
			if @data[hash].nil?
				@data[hash] = {key=>filename}
			else
				@data[hash][key] = filename
			end	 
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
      @finger[0].noderef
    end
  end

  def next_successor
    if @successor_list.empty?
      return nil
    end
    
    n = @successor_list[0]
    @successor_list = @successor_list.slice(1, @successor_list.length)
		@finger[0].noderef = n
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
			noderef = NodeReference.new addr, port
			notify noderef
		elsif req.start_with? "STORE"
			req = socket.gets
			key_size = req.split[1].to_i
			key = socket.read key_size
			req = socket.gets
			value_size = req.split[1].to_i
			value = socket.read value_size
			store key, value
		elsif req.start_with? "REPLICATE"
			req = socket.gets
			key_size = req.split[1].to_i
			key = socket.read key_size
			req = socket.gets
			value_size = req.split[1].to_i
			value = socket.read value_size
			replicate key, value
		elsif req.start_with? "GET"
			req = socket.gets
			tokens = req.split
			key_size = tokens[1].to_i
			key = socket.read(key_size)
			value = get key
			if value.is_a? NodeReference
				response = "ASK ADDR #{value.addr} PORT #{value.port}"
				socket.puts response
			else
				response = "HERE #{value.bytes.count}"
				socket.puts response
				socket.write value
			end
		elsif req.start_with? "CLIENT GET"
			req = socket.gets
			tokens = req.split
			key_size = tokens[1].to_i
			key = socket.read(key_size)
			value = get key
			while value.is_a? NodeReference
				value = value.get key
			end

			response = "HERE #{value.bytes.count}"
			socket.puts response
			socket.write value
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
        sleep 2
        stabilize()
        fix_fingers()
      end
    end

    server_thread = Thread.new do
			local_addr = Socket.ip_address_list.find do |ip|
				ip.ipv4? and not ip.ipv4_loopback?
			end
      server = TCPServer.new(local_addr.getnameinfo[0], @port)
      loop do
				Thread.start(server.accept) do |s|
					handle_request s
				end
      end
    end
  end

  def update_successor_list
    # successor_list[0] is not the same as finger[0].  it is finger[0].successor

    s = successor
    for i in 0...NUM_ADJACENT do
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

    successor.notify(@ref)

  end

  def transfer_keys(n)
		sleep 60		# sleep to make sure we are not transfering too much during initial setup
		n = @predecessor
		if n.addr != @addr
			puts "transferring..."
			r = OpenClosedInterval.new(@id, n.id)
			transfers = {}
			
			@data.each do |hash, kvpairs|
				if r.contains? hash
					transfers[hash] = kvpairs
				end
			end

			puts "transfers identified."

			transfers.each do |hash, kvpairs|
				@data.delete hash
				kvpairs.each do |key, filename|
					fullpath = File.join(@dir, filename)
					if not key or not File.exist? fullpath
						next
					end
					f = File.open(fullpath, "r")
					value = f.read
					f.close

					File.delete fullpath

					n.store(key, value)
				end
			end
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
    if not i.nil?
      @i = i 
		else
			@i = 0 if @i.nil?
			@i = (@i + 1) % M
    end
    
    @finger[@i].noderef = find_successor(@finger[@i].start)
		
		r = OpenClosedInterval.new @finger[@i].start, @finger[@i].noderef.id
		while r.contains? @finger[(@i+1) % M].start
			@finger[(@i+1) % M].noderef = @finger[@i].noderef
			@i = (@i + 1) % M
		end
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

	def persist key, hash, value
		filename = "#{hash}_#{key}"
		f = File.open(File.join(@dir, filename), "w")
		f.write value
		f.close

		if @data[hash].nil?
			@data[hash] = {key => value}
		else
			@data[hash][key] = filename
		end
	end

  def replicate(key, value)
		h = sha1 key

		persist key, h, value
  end

  def store(key, value)
		h = sha1 key
    if owns? h

			persist key, h, value

			# store data in adjacent nodes in case this node fails
      successor.replicate(key, value)
      @successor_list.each do |s|
        if not s.nil? and s.online?
          s.replicate(key, value)
        end
      end

    else
			s = find_successor h
			s.store key, value
      #successor.store(key, value)
    end
  end

  def get(key)
		h = sha1 key
    if owns? h #or not @data[h].nil?
      unless @data[h].nil? 
				filename = "#{h}_#{key}"
				f = File.open(File.join(@dir, filename), "r")
				value = f.read
				f.close
				value
			else
				""
			end	
    else
      n = closest_preceding_finger h
			if n == @predecessor
				successor
			else
				n.successor
			end
    end
  end
end
