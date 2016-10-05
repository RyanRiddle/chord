require 'openssl'

class Node
  @@sha1 = OpenSSL::Digest::SHA1.new
  @@keyspace_size = 2**160

  attr_reader :id
  attr_reader :predecessor

  def initialize
    @id = hash(Time.now.to_s)
  end

  def hash(key)
    str = @@sha1.digest key.to_s
    hex_bytes = str.bytes.collect { |byte| "%02x" % byte }
    hex = hex_bytes.join("")
    OpenSSL::BN.new(hex, 16)
  end

  def diff(key)
    key - @id % @@keyspace_size
  end

  
  
end
