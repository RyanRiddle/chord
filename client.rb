#!/usr/bin/ruby

require_relative 'lib/node_reference'

def make_script data, reqs
	viz_script = "
	<html>
		<head>
			<style>
				body {
					margin: 0px;
					padding: 0px;
				}
			</style>
		</head>
		<body>
			<canvas id='myCanvas' width='578' height='250'></canvas>
			<script>
				var identifiers = #{data};
				var requests = #{reqs};
				var canvas = document.getElementById('myCanvas');
				canvas.width = window.innerWidth;
				canvas.height = window.innerHeight;
				var context = canvas.getContext('2d');
				var centerX = canvas.width / 2;
				var centerY = canvas.height / 2;
				var radius = 220;
				var angle = -Math.PI / 2.0;

				context.beginPath();
				context.arc(centerX, centerY, radius, 0, Math.PI*2, false);
				context.stroke();

				identifiers.forEach(function(id) {
					angle += id.angleDelta;
					x = Math.cos(angle) * radius + centerX;
					y = Math.sin(angle) * radius + centerY;

					context.beginPath();
					context.arc(x, y, id.radius, 0, Math.PI*2.0, false);
					context.stroke();
					context.fillStyle = 'blue';
					context.fill();
				});

				angle = -Math.PI / 2.0;
				x = Math.cos(angle) * radius + centerX;
				y = Math.sin(angle) * radius + centerY;
				context.moveTo(x, y);
				requests.forEach(function(req) {
					angle += req.angleDelta;	
					x = Math.cos(angle) * radius + centerX;
					y = Math.sin(angle) * radius + centerY;

					context.lineTo(x, y);
					context.stroke();
				});
					
			</script>
		</body>
	</html>"
end

def connect address, port
	@connection = NodeReference.new address, port.to_i
	if @connection.online?
		puts "Connection to #{address}:#{port} succeeded!"
	else
		puts "Connection to #{address}:#{port} failed :("
	end	
end

def it_get key
	requests = []
	puts "Asking #{@connection.addr}:#{@connection.port} to find \"#{key}\""
	last = @connection
	n = @connection.get key
	while n.is_a? NodeReference
		delta = node_delta last, n	
		requests.push delta
		puts "Asking #{n.addr}:#{n.port} to find \"#{key}\""
		last = n
		n = n.get key
	end

	if n.nil?
		puts "Query failed!"
	else
		puts "Found the node!"
		if n.empty?
			puts "Entry not found :("
		else
			puts n
		end
	end

	requests
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

def node_delta a, b
	(((b.id - a.id) % 2**M) / (2**M).to_f) * Math::PI * 2
end

def map args
	data = "["

	n = @connection
	data += "{ radius: 10, angleDelta: 0 }, "
	puts "#{n.addr}    #{n.port}"
	puts ""
	last = n
	n = n.successor
	while n.addr != @connection.addr or n.port != @connection.port
		delta = node_delta last, n
		data += "{ radius: 10, angleDelta: #{delta}}, "
		puts "#{n.addr}    #{n.port}"
		puts ""
		last = n
		n = n.successor
	end

	data += "]"

	reqs = "["
	if not args.empty? and args[0] == "request"
		key = args.slice(1, args.count).join " "
		requests = it_get key
		requests.each do |r|
			reqs += "{ angleDelta: #{r}}, "
		end
	end
	reqs += "]"

	script = make_script data, reqs
	File.open("script.html", "w", File::CREAT|File::TRUNC) do |f|
		f.write script
	end
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
	elsif f == "map"
			map args
	elsif f == "quit"
		exit
	else
		puts "\"#{command}\" is an invalid command"
	end	
end

while true
	print "dht client > "
	command = gets

	execute command
end
