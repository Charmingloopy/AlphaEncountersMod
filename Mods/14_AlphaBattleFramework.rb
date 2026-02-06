class PokemonTemp
  attr_accessor :battleRewards

  alias_method :old_initialize, :initialize

  def initialize
    old_initialize
    @battleRewards = []
  end
end






