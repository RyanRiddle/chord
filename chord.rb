require 'openssl'

KEYSPACE_SIZE = 2**160

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

class Node

  attr_reader :id
  attr_reader :predecessor
  attr_reader :successor
  attr_reader :data

  def initialize(id)
    @id = id
    @data = {}
  end

  def diff(key)
    (@id - key) % KEYSPACE_SIZE
  end

  def successor=(n)
    @successor = n
  end

  def predecessor=(n)
    @predecessor = n
  end

  def owns?(key)
    if predecessor.nil?
      return true
    end
      return diff(key) < @predecessor.diff(key)
  end

  def store(key, value)
    if owns? key
      data[key] = value
    else
      @successor.store(key, value)
    end
  end

  def get(key)
    if owns? key
      data[key]
    else
      @successor.get(key)
    end
  end
  
end
