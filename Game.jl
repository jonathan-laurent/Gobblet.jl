################################################################################
# Gobblet gobblers
################################################################################

# Three games are available, from simplest to hardest to solve
@enum GameChoice Standard Simple TicTacToe

const GAME = Standard

const BOARD_SIDE = 3
const NUM_POSITIONS = BOARD_SIDE ^ 2

if GAME == Standard
  const NUM_LAYERS = 3
  const NUM_GOBBLET_COPIES = 2 # 2 two gobblers of each kind
elseif GAME == Simple
  const NUM_LAYERS = 2
  const NUM_GOBBLET_COPIES = 2
elseif GAME == TicTacToe
  const NUM_LAYERS = 1
  const NUM_GOBBLET_COPIES = NUM_POSITIONS
end

################################################################################

@enum Player Red Blue
const LayerCell = Union{Nothing, Player}
const Board = Array{LayerCell, 2}

################################################################################

function make_board()
  B = Board(undef, (NUM_POSITIONS, NUM_LAYERS))
  fill!(B, nothing)
  return B
end

################################################################################

struct Action
  move :: Bool
  size :: Int
  from :: Int  # useful if `move = true`
  to   :: Int
end

MoveAction(size, from, to) = Action(true, size, from, to)
AddAction(size, to) = Action(false, size, 0, to)

# No action is available from a winning position
mutable struct State
  board :: Board
  top :: Vector{Int}
  curplayer :: Player
  finished :: Bool
  winner :: Union{Nothing, Player}
  available_red :: Vector{Int}
  available_blue :: Vector{Int}
  
  function State(;first_player=Red)
    s = new(
      make_board(),
      zeros(NUM_POSITIONS),
      first_player,
      false,
      nothing,
      fill(NUM_GOBBLET_COPIES, NUM_LAYERS),
      fill(NUM_GOBBLET_COPIES, NUM_LAYERS))
  end
end

################################################################################

pos_of_xy((x, y)) = (y - 1) * BOARD_SIDE + (x - 1) + 1

xy_of_pos(pos) = ((pos - 1) % BOARD_SIDE + 1, (pos - 1) ÷ BOARD_SIDE + 1)

# Dimensions: BOARD_SIDE × NUM_ALIGNMENTS
const ALIGNMENTS = begin
  local N = BOARD_SIDE
  local XY = [
    [[(i, j) for j in 1:N] for i in 1:N];
    [[(i, j) for i in 1:N] for j in 1:N];
    [[(i, i) for i in 1:N]];
    [[(i, N - i + 1) for i in 1:N]]]
  [pos_of_xy(al[i]) for i in 1:N, al in XY]
end

const NUM_ALIGNMENTS = size(ALIGNMENTS)[2]

################################################################################

@inline available(s::State, p::Player) =
  (p == Red) ? s.available_red : s.available_blue
  
@inline symmetric(p::Player) = (p == Blue) ? Red : Blue

# So that symmetric can be use on `LayerCell`
@inline symmetric(::Nothing) = nothing

@inline function switch_player!(s::State)
  s.curplayer = symmetric(s.curplayer)
end

@inline function poscolor(s::State, pos)
  (s.top[pos] == 0) && (return nothing)
  v = s.board[pos, s.top[pos]]
  @assert !isnothing(v)
  return v
end

@inline function cango(s::State, size, pos)
  s.top[pos] < size
end

################################################################################

update_invariant(board, pos, layer) =
  all(isnothing(board[pos, i]) for i in layer+1:NUM_LAYERS)

function put!(s::State, pos, layer, ::Nothing)
  @assert update_invariant(s.board, pos, layer)
  cur = s.board[pos, layer]
  @assert isa(cur, Player)
  available(s, cur)[layer] += 1
  s.board[pos, layer] = nothing
  i = s.top[pos] - 1
  while i > 0 && isnothing(s.board[pos, i])
    i -= 1
  end
  s.top[pos] = i
end

function put!(s::State, pos, layer, p::Player)
  @assert update_invariant(s.board, pos, layer)
  @assert isnothing(s.board[pos, layer])
  available(s, p)[layer] -= 1
  s.board[pos, layer] = p
  s.top[pos] = layer
end

################################################################################

function has_won(s::State, player::Player)
  for al in 1:NUM_ALIGNMENTS
    won = true
    for i in 1:BOARD_SIDE
      pos = ALIGNMENTS[i, al]
      if poscolor(s, pos) != player
        won = false
        break
      end
    end
    won && (return true)
  end
  return false
end

# If it returns true, the game ends with a draw
# Otherwise, there has to exist an available action
if NUM_LAYERS == 1
  function is_stuck(s::State)
    for pos in 1:NUM_POSITIONS
      (s.top[pos] == 0) && (return false)
    end
    return true
  end
else
  is_stuck(s::State) = false
end

# We assume the action is valid
function execute_action!(s::State, a::Action)
  @assert !s.finished && isnothing(s.winner)
  put!(s, a.to, a.size, s.curplayer)
  if a.move
    put!(s, a.from, a.size, nothing)
  end
  # the winner (if it exists) always has the last move
  if has_won(s, s.curplayer)
    s.finished = true
    s.winner = s.curplayer
  elseif is_stuck(s)
    s.finished = true
  end
  switch_player!(s)
end

function cancel_action!(s, a)
  s.finished = false
  s.winner = nothing
  switch_player!(s)
  put!(s, a.to, a.size, nothing)
  if a.move
    put!(s, a.from, a.size, s.curplayer)
  end
end

# The state must be returned unchanged.
function fold_actions(f::Function, s::State, init)
  @assert !s.finished
  acc = init
  # Look for places to add a new gobbler
  for l in 1:NUM_LAYERS
    if available(s, s.curplayer)[l] > 0
      for p in 1:NUM_POSITIONS
        if cango(s, l, p)
          acc = f(acc, AddAction(l, p))
        end
      end
    end
  end
  # Look to move an existing gobbler
  for from in 1:NUM_POSITIONS
    if poscolor(s, from) == s.curplayer
      size = s.top[from]
      for to in 1:NUM_POSITIONS
        if cango(s, size, to)
          acc = f(acc, MoveAction(size, from, to))
        end
      end
    end
  end
  return acc
end

function iter_actions(f::Function, s::State)
  fold_actions(s, nothing) do acc, a
    f(a) ; nothing
  end
end

################################################################################

# Warning: slow function
function available_actions(s::State)
  actions = Vector{Action}()
  iter_actions(s) do a
    push!(actions, a)
  end
  return actions
end

################################################################################

# Does not update the game status (optimization)
function process_board_update!(s::State)
  s.available_blue .= NUM_GOBBLET_COPIES
  s.available_red .= NUM_GOBBLET_COPIES
  s.top .= 0
  for l in 1:NUM_LAYERS
    for p in 1:NUM_POSITIONS
      v = s.board[p,l]
      if v == Red
        s.available_red[l] -= 1
        s.top[p] = l
      elseif v == Blue
        s.available_blue[l] -= 1
        s.top[p] = l
      end
    end
  end
end

################################################################################
