################################################################################
# Solving the game using value iteration
# No attempt is made to exploit a weak adversary
################################################################################

# No guarantee for end states.
# 00: unsolved or part of a loop
# 10: guaranteed win for the nominal player
# 01: guaranteed loss for the nominal player
# 11: guaranteed tie

const NOMINAL_PLAYER = Red
const ADVERSARY = Blue

mutable struct Solution <: AI
  V :: BitVector
  complete :: Bool
  numsolved :: Int # number of solved state
  itnum :: Int # number of previous iterations
  function Solution()
    new(falses(2 * CARD_BOARDS), false, 0, 0)
  end
end

const Status = Tuple{Bool, Bool}

function status(env::Solution, bcode::Int) :: Status
  win  = env.V[2 * bcode + 1]
  loss = env.V[2 * bcode + 2]
  return (win, loss)
end

function solved(env::Solution, bcode::Int)
  win, loss = status(env, bcode)
  return win || loss
end

function set_status!(env::Solution, bcode::Int, (win, loss)::Status)
  @assert !solved(env, bcode)
  if (win || loss) env.numsolved += 1 end
  env.V[2 * bcode + 1] = win
  env.V[2 * bcode + 2] = loss
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
      return (true, true)
    elseif (s.winner == s.curplayer)
      return (true, false)
    else
      return (false, true)
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
  other_won, other_lost = status(env, s)
  cancel_action!(s, a)
  return (other_lost, other_won)
end

# There is a total order on status:
# 10 > 11 > 00 > 01

status_rank((win, loss)) = 2 * (Int(win) - Int(loss)) + Int(win && loss)

function best_status(st1, st2)
  status_rank(st1) > status_rank(st2) ? st1 : st2
end

function iterate!(env::Solution; progressbar=false)
  s = State(first_player=NOMINAL_PLAYER)
  progressbar && (progress = Progress(CARD_BOARDS, 1))
  pre_numsolved = env.numsolved
  for code in 0:CARD_BOARDS-1
    decode_board!(s.board, code)
    process_board_update!(s)
    @assert !s.finished # per our optimization of `process_board_update!`
    if !solved(env, code)
      init = ((false, true), true, env, s)
      status, stuck, env, s = fold_actions(s, init) do acc, a
        # We take care of capturing no variable so that no closure is needed.
        local status, stuck, env, s = acc
        status = best_status(status, Qstatus(env, s, a))
        (status, false, env, s)
      end
      # No action available: we solve the state so we don't have to explore
      # it anymore. Should not happen for gobblet gobblers.
      if (stuck) status = (true, true) end
      set_status!(env, code, status)
    end
    progressbar && (next!(progress))
  end
  env.complete = pre_numsolved == env.numsolved
  env.itnum += 1
end

function solve()
  env = Solution()
  while !env.complete
    iterate!(env)
  end
  return env
end

################################################################################

function value(env::Solution, s::State)
  win, loss = status(env, s)
  return Int(win) - Int(loss)
end

function Qvalue(env::Solution, s::State, a::Action)
  execute_action!(s, a)
  Q = - value(env, s)
  cancel_action!(s, a)
  return Q
end

function play(env::Solution, s::State)
  actions = available_actions(s)
  Qs = [Qvalue(env, s, a) for a in actions]
  a = argmax(Qs)
  return actions[a]
end

################################################################################
