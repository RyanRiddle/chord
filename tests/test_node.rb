require 'test/unit'
require 'chord'

class NodeTests < Test::Unit::TestCase
  def test_finger
    a = Node.new 0

    assert(a.finger.length == M)
  end
end
