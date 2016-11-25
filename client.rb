#!/usr/bin/ruby

require_relative 'lib/node_reference'

def connect address, port
	@connection = NodeReference.new address, port.to_i
	if @connection.online?
		puts "Connection to #{address}:#{port} succeeded!"
	else
		puts "Connection to #{address}:#{port} succeeded!"
	end	
end

def it_get key
	puts "Asking #{@connection.addr}:#{@connection.port} to find \"#{key}\""
	n = @connection.get key
	while n.is_a? NodeReference
		puts "Asking #{n.addr}:#{n.port} to find \"#{key}\""
		n = n.get key
	end

	if n.nil?
		puts "Query failed!"
	else
		puts "Found it!"
		puts n
	end
end	

def get key
	puts "Asking #{@connection.addr}:#{@connection.port} to find \"#{key}\""
	socket = TCPSocket.open @connection.addr, @connection.port
	socket.puts "CLIENT GET"
	socket.puts "KEY #{key.bytes.count}"
	socket.write key
	size = socket.gets.chomp.split[1].to_i
	data = socket.read size
	puts data
end

def parse command
	f, *args = command.split
	return f, args
end

def execute command
	f, args = parse command
	
	if f == "connect"
		connect *args
	elsif f == "itget"
		it_get args.join " "
	elsif f == "get"
		get args.join " "
	else
		puts "Don't know how to #{f}"
	end	
end

while true
	print "dht client > "
	command = gets

	execute command
end
