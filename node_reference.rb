require 'socket'
require_relative 'utils'

class NodeReference
  attr_reader :id
  attr_reader :addr
  attr_reader :port

  def initialize(addr, port)
    @addr = addr
    @port = port

		@id = sha1 "#{addr}:#{port}"
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

			if response.start_with? "ERROR"
				return nil
			end

			tokens = response.split
			addr = tokens[3]
			port = tokens[5].to_i
			NodeReference.new(addr, port)
		end
	end

	def successor
		s = connect
		if not s.nil?
			s.puts("SUCCESSOR\n")
			response = s.gets.chomp
			s.close

			tokens = response.split
			addr = tokens[3]
			port = tokens[5].to_i
			NodeReference.new(addr, port)
		end
	end

	def find_successor(key)
		s = connect
		if not s.nil?
			s.puts("FIND SUCCESSOR #{key}\n")
			response = s.gets.chomp
			s.close

			tokens = response.split
			addr = tokens[3]
			port = tokens[5].to_i
			NodeReference.new(addr, port)
		end
	end

	def closest_preceding_finger(key)
		s = connect
		if not s.nil?
			s.puts "CLOSEST PRECEDING FINGER #{key}"
			response = s.gets.chomp
			s.close

			tokens = response.split
			addr = tokens[3]
			port = tokens[5].to_i
			NodeReference.new(addr, port)
		end
	end	

	def stabilize
		s = connect
		if not s.nil?
			s.puts "STABILIZE\n"
			s.close
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

	def get(key)
		s = connect
		if not s.nil?
			s.puts "GET #{key}\n"
			response = s.gets.chomp
			s.close
		
			tokens = response.split
			tokens.slice(1, tokens.length).join " "
		end
	end
end
