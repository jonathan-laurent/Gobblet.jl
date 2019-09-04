################################################################################
# Module exports
################################################################################

export GAME
export BOARD_SIDE, NUM_POSITIONS, NUM_LAYERS, NUM_GOBBLET_COPIES
export Player, Red, Blue
export Board, Action, MoveAction, AddAction, State
export symmetric, pos_color, execute_action!, cancel_action!
export fold_actions, iter_actions, available_actions

export Solution, iterate_value!, solve

export Agent, Human, AI, RandomAI, PerfectPlay, play
export print_board, player_name, interactive!

include("Game.jl")
include("Encoding.jl")
include("Solve.jl")
include("Interface.jl")

################################################################################
