###############################################################################
# Solving the game using value iteration
###############################################################################

const NOMINAL_PLAYER = Red
const ADVERSARY = Blue

mutable struct Solution
  V :: BitVector
  changed :: Bool
  numsolved :: Int # number of solved state
  itnum :: Int # number of previous iterations
  function Solution()
    new(falses(3 * CARD_BOARDS), true, 0, 0)
  end
end

computed(s::Solution) = !s.changed

# Represents a nonempty subinterval of {-1, 0, 1}
# The initial value (false, false, false) codes for {-1, 0, 1}
struct Status
  solved :: Bool
  noloss :: Bool
  nowin  :: Bool
end

Status(v) = Status(true, v >= 0, v <= 0)
Status(minv, maxv) = Status(minv == maxv, minv >= 0, maxv <= 0)
minvalue(s::Status) = Int(s.noloss) - Int(!s.solved || s.nowin)
maxvalue(s::Status) = Int(!s.solved || s.noloss) - Int(s.nowin)
symmetric(s::Status) = Status(s.solved, s.nowin, s.noloss)

function status(env::Solution, bcode::Int) :: Status
  solved = env.V[3 * bcode + 1]
  noloss = env.V[3 * bcode + 2]
  nowin  = env.V[3 * bcode + 3]
  return Status(solved, noloss, nowin)
end

solved(env::Solution, bcode::Int) = env.V[3 * bcode + 1]

function set_bit!(env::Solution, bcode, offset, v)
  idx = 3 * bcode + offset
  if (env.V[idx] != v) env.changed = true end
  env.V[idx] = v
end

function set_status!(env::Solution, bcode::Int, status)
  @assert !solved(env, bcode)
  if (status.solved) env.numsolved += 1 end
  set_bit!(env, bcode, 1, status.solved)
  set_bit!(env, bcode, 2, status.noloss)
  set_bit!(env, bcode, 3, status.nowin)
end

function encode_board_symmetric(board)
  encode_board(board) do b, i, j
    symmetric(b[i, j])
  end
end

# Status for the current player
function status(env::Solution, s::State)
  if s.finished
    if isnothing(s.winner)
      return Status(0)
    elseif s.winner == s.curplayer
      return Status(1)
    else
      return Status(-1)
    end
  else
    if s.curplayer == NOMINAL_PLAYER
      code = encode_board(s.board)
    else
      code = encode_board_symmetric(s.board)
    end
    return status(env, code)
  end
end

function Qstatus(env::Solution, s::State, a::Action)
  execute_action!(s, a)
  other = status(env, s)
  cancel_action!(s, a)
  return symmetric(other)
end

function iterate!(env::Solution; progressbar=false)
  s = State(first_player=NOMINAL_PLAYER)
  progressbar && (progress = Progress(CARD_BOARDS, 1))
  env.changed = false
  for code in 0:CARD_BOARDS-1
    if !solved(env, code)
      decode_board!(s.board, code)
      process_board_update!(s)
      @assert !s.finished # per our optimization of `process_board_update!`
      minv, maxv, env, s = fold_actions(s, (-1, -1, env, s)) do acc, a
        # We take care of capturing no variable so that no closure is needed.
        local minv, maxv, env, s = acc
        Q = Qstatus(env, s, a)
        minv = max(minv, minvalue(Q))
        maxv = max(maxv, maxvalue(Q))
        return (minv, maxv, env, s)
      end
      set_status!(env, code, Status(minv, maxv))
    end
    progressbar && (next!(progress))
  end
  env.itnum += 1
end

function solve()
  env = Solution()
  while env.changed
    iterate!(env)
  end
  return env
end

################################################################################

# If the state is unresolved, then it is part of an infinite loop.
value(s::Status) = s.solved ? minvalue(s) : 0

value(env::Solution, s::State) = value(status(env, s))

Qvalue(env::Solution, s::State, a::Action) = value(Qstatus(env, s, a))

################################################################################
