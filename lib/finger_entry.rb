require_relative 'utils'

class FingerEntry
  attr_reader :start, :interval
  attr_accessor :noderef
  
  def initialize(start, finish, noderef)
    @start = start
    @interval = ClosedOpenInterval.new(start, finish)
    @noderef = noderef
  end

  def display
    print @start.to_s + " "
    @interval.display
    print " " + @noderef.id.to_s + "\n"
  end
end
