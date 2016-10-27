require 'openssl'
require_relative 'constants'

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

  def display
    print "(" + @first.to_s + ", " + @last.to_s + ")"
  end
end

class ClosedOpenInterval < Interval
  def contains? (val)
    difference(@first, val) <= difference(@last, val)
  end
end

class OpenClosedInterval < Interval
  def contains? (val)
    difference(val, @last) <= difference(val, @first)
  end
end

class OpenOpenInterval < Interval
  def contains? (val)
    d1 = difference(@first, val)
    d2 = difference(@last, val)

    0 < d1 and 0 < d2 and d1 < d2
  end
end

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
