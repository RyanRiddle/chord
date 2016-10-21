require 'test/unit'
require 'utils'

# redefining a constant so i do not have to change my tests when i want to scale the network
M = 3

class UtilTests < Test::Unit::TestCase
  def test_difference
    assert(difference(0, 1) == 1)
    assert(difference(0, 7) == 7)
    assert(difference(1, 7) == 6)
    assert(difference(1, 0) == 7)
    assert(difference(7, 2) == 3)
  end
end
