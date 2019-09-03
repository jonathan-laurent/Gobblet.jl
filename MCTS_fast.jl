################################################################################
# Implementing Monte Carlo Tree Search
################################################################################

# Some resources
# https://web.stanford.edu/~surag/posts/alphazero.html
# https://int8.io/monte-carlo-tree-search-beginners-guide/
# https://medium.com/oracledevs/lessons-from-alpha-zero-part-5-performance-optimization-664b38dc509e

################################################################################

"""
A fast and modular implementation of the Monte Carlo Tree Search algorithm.
The interface for `MCTS.Env{State, Board, Action}` is the following:
  
  + `copy(::State)`
  + `copy(::Board)`
  + `curplayer(::State)`
  + `status(::State) :: Union{Nothing, Float64}`
  + `board(::State)`
  + `board_symmetric(::State)`
  + `available_actions(::State) :: Vector{Action}`
  + `fold_actions(f, ::State, init)`
  + `play!(::State, ::Action)`
  + `dummy_action(::Type{Action})`

"""
module MCTS

export Env, explore!

using DataStructures

# Mandatory interface
function curplayer end
function status end
function board end
function board_symmetric end
function available_actions end
function fold_actions end
function play! end
function undo! end
function dummy_action end
function debug_board end

################################################################################

const DEFAULT_UCT_C = 2 * sqrt(2)

struct StateStatistics
  Q :: Float64
  N :: Int
end

mutable struct Env{State, Board, Action}
  # Store state statistics assuming player one is to play
  tree  :: Dict{Board, StateStatistics}
  stack :: Stack{Action}
  state :: State
  # Parameters
  uct_c :: Float64
  
  function Env{S, B, A}() where {S, B, A}
    new(Dict{B, StateStatistics}(), Stack{A}(), S(), DEFAULT_UCT_C)
  end
end

################################################################################

symmetric_reward(R) = -R

symmetric(s::StateStatistics) = StateStatistics(symmetric_reward(s.Q), s.N)

# Returns statistics for the current player
function state_statistics(env::Env)
  b = curplayer(env.state) ? board(env.state) : board_symmetric(env.state)
  if haskey(env.tree, b)
    return env.tree[b]
  else
    return env.tree[copy(b)] = StateStatistics(0, 0)
  end
end

function set_state_statistics!(env::Env, reward)
  if curplayer(env.state)
    r = reward
    b = board(env.state)
  else
    r = symmetric_reward(reward)
    b = board_symmetric(env.state)
  end
  stats = get(env.tree, b, StateStatistics(0, 0))
  env.tree[copy(b)] = StateStatistics(stats.Q + r, stats.N + 1)
end

# Only call when actions are available
# Allocation-free.
function best_action(score, env::Env{S,B,A}, arg) :: A where {S,B,A}
  R = Base.promote_op(score, typeof(arg), A)
  init = (arg, dummy_action(A), typemin(R))
  _, action, _ =
    fold_actions(env.state, init) do (arg, best_action, best_score), a
      s = score(arg, a)
      if s > best_score
        best_score = s
        best_action = a
      end
      (arg, best_action, best_score)
    end
  return action
end

################################################################################

function uct_score(c, parent::StateStatistics, child::StateStatistics)
  child.N == 0 && return Inf
  return child.Q / child.N + c * sqrt(log(parent.N) / child.N)
end

# Updates the state
function select!(env::Env)
  reward = nothing
  while true
    reward = status(env.state)
    isnothing(reward) || break
    stats = state_statistics(env)
    stats.N == 0 && break
    # Use UCT to find the best action
    action = best_action(env, env) do env, a
      player = curplayer(env.state)
      play!(env.state, a)
      cstats = state_statistics(env)
      if curplayer(env.state) != player
        cstats = symmetric(cstats)
      end
      undo!(env.state, a)
      uct_score(env.uct_c, stats, cstats)
    end
    push!(env.stack, action)
    play!(env.state, action)
  end
  return reward
end

# Play randomly, return reward for player one
function rollout(env::Env)
  state = copy(env.state)
  while true
    reward = status(state)
    isnothing(reward) || (return reward)
    action = rand(available_actions(state))
    play!(state, action)
  end
end

function backprop!(env::Env, reward)
  set_state_statistics!(env, reward)
  while !isempty(env.stack)
    action = pop!(env.stack)
    undo!(env.state, action)
    set_state_statistics!(env, reward)
  end
end

function reset!(env::Env)
  empty!(env.tree)
end

function set_root!(env::Env, state)
  env.state = state
end

function most_visited_action(env::Env)
  best_action(env, env) do env, a
    play!(env.state, a)
    stats = state_statistics(env)
    undo!(env.state, a)
    stats.N
  end
end

function explore!(env::Env)
  @assert isempty(env.stack)
  reward = select!(env)
  if isnothing(reward)
    reward = rollout(env)
  end
  backprop!(env, reward)
  @assert isempty(env.stack)
end

const EXPLORE_INCREMENT = 1000

function explore!(env::Env, time_budget)
  start = time()
  while time() - start <= time_budget
    for i in 1:EXPLORE_INCREMENT
      explore!(env)
    end
  end
end

################################################################################

end

################################################################################
# Test Usage

const GAME = :tictactoe
include("Gobblets.jl")

using .MCTS

import Base.copy
  
struct StateWrapper
  wrapped :: State
  symboard :: Board
  StateWrapper(s::State) = new(s, copy(s.board))
  StateWrapper() = StateWrapper(State())
end

copy(s::StateWrapper) = deepcopy(s)

MCTS.curplayer(s::StateWrapper) = s.wrapped.curplayer == Red

MCTS.board(s::StateWrapper) = s.wrapped.board

MCTS.dummy_action(::Type{Action}) = Action(true, 0, 0, 0)

MCTS.available_actions(s::StateWrapper) = available_actions(s.wrapped)

MCTS.play!(s::StateWrapper, a) = execute_action!(s.wrapped, a)

MCTS.undo!(s::StateWrapper, a) = cancel_action!(s.wrapped, a)

MCTS.debug_board(b) = print_board(State(b))

function MCTS.fold_actions(f, s::StateWrapper, init)
  fold_add_actions(f, s.wrapped, init)
end

function MCTS.available_actions(s::StateWrapper)
  actions = Action[]
  MCTS.fold_actions(s, actions) do actions, a
    push!(actions, a)
    actions
  end
  return actions
end

function MCTS.status(s::StateWrapper) :: Union{Nothing, Float64}
  s.wrapped.finished || return nothing
  isnothing(s.wrapped.winner) && return 0
  s.wrapped.winner == Red && return 1
  return -1
end

function MCTS.board_symmetric(s::StateWrapper)
  for i in eachindex(s.wrapped.board)
    s.symboard[i] = symmetric(s.wrapped.board[i])
  end
  return s.symboard
end

const GobbletMCTS = Env{StateWrapper, Board, Action}

env = GobbletMCTS()

using ProgressMeter

function debug_tree(env, k=10)
  pairs = collect(env.tree)
  k = min(k, length(pairs))
  most_visited = sort(pairs, by=(x->x.second.N), rev=true)[1:k]
  for (b, stats) in most_visited
    println(stats)
    print_board(State(b))
  end
end

################################################################################

struct MCTS_AI <: AI
  env :: GobbletMCTS
end

function play(ai::MCTS_AI, state)
  MCTS.set_root!(ai.env, StateWrapper(state))
  MCTS.explore!(ai.env, 5.0)
  MCTS.most_visited_action(ai.env)
end

################################################################################
#=
state = State(Board(
  reshape([Blue Blue Red nothing Red nothing Blue nothing Red], (9, 1))))

println("Playing from:")
print_board(state)

MCTS.set_root!(env, StateWrapper(state))
MCTS.explore!(env, 0.1)
debug_tree(env)
=#
################################################################################

state = State()
MCTS.set_root!(env, StateWrapper(state))
MCTS.explore!(env, 2.)
debug_tree(env)
interactive!(state, red=MCTS_AI(env), blue=Human())

################################################################################
