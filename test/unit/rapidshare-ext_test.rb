require 'test/unit'

class RapidshareExtTest < Test::Unit::TestCase
  def test_first
    assert true
    rs = Rapidshare::Api.new
  end
end