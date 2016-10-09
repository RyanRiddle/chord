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

class Node

  attr_reader :id
  attr_reader :predecessor
  attr_reader :successor
  attr_reader :data

  def initialize(id)
    @id = id
    @data = {}
  end

=begin
  def diff(key)
    (@id - key) % KEYSPACE_SIZE
  end
=end

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

    r = OpenClosedInterval.new(@predecessor.id, @id)
    r.contains? key

    #return diff(key) < @predecessor.diff(key)
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
