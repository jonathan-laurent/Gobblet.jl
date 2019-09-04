################################################################################
# Gobblet.jl
################################################################################

module Gobblet

  export TicTacToe
  
  const GAME = :standard
  include("Module.jl")
  
  module TicTacToe
    const GAME = :tictactoe
    include("Module.jl")
  end
  
end

################################################################################
