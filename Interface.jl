################################################################################
# A simple console Interface
################################################################################

abstract type Agent end

struct Human <: Agent end

abstract type AI <: Agent end
# Interface: play(::AI, ::State)
# It is guaranteed that at least one valid action exists when `play` is called.

struct RandomAI <: AI end

function play(::RandomAI, s::State)
  rand(available_actions(s))
end

struct PerfectPlay <: AI
  solution :: Solution
  function PerfectPlay(s::Solution)
    @assert computed(s)
    new(s)
  end
end

function play(ai::PerfectPlay, s::State)
  actions = available_actions(s)
  Qs = [Qvalue(ai.solution, s, a) for a in actions]
  a = rand(actions[Qs .== maximum(Qs)])
  # a = actions[argmax(Qs)]
  return a
end

################################################################################

using Crayons

style(p::Player) = p == Red ? crayon"light_red" : crayon"light_blue"
playername(p::Player) = p == Red ? "Red" : "Blue"

const INTERFACE_PRINT_AVAILABLE = (NUM_LAYERS > 1)

################################################################################

# Position naming scheme:
# A B C
# D E F
# G H I

function parse_pos(c::Char) :: Union{Nothing, Int}
  x = Int(uppercase(c)) - Int('A')
  (0 <= x < NUM_POSITIONS) ? x + 1 : nothing
end

function print_pos(pos)
  Char(Int('A') + pos - 1)
end

################################################################################

function parse_action(state::State, s) :: Union{Nothing, Action}
  (length(s) < 2) && (return nothing)
  to = parse_pos(s[2])
  isnothing(to) && return nothing
  from = parse_pos(s[1])
  if isnothing(from)
    try
      size = parse(Int, s[1])
      return AddAction(size, to)
    catch err
      return nothing
    end
  else
    size = state.top[from]
    return MoveAction(size, from, to)
  end
end

################################################################################

function print_available(s::State, p::Player)
  print(style(p))
  for l in reverse(1:NUM_LAYERS)
    av = available(s, p)[l]
    for i in 1:av
      print(l, " ")
    end
  end
  print(crayon"reset")
end

function print_board(s::State; with_position_names=false)
  for y in 1:BOARD_SIDE
    for x in 1:BOARD_SIDE
      pos = pos_of_xy((x, y))
      l = s.top[pos]
      if l == 0
        print(" ")
      else
        print(style(pos_color(s, pos)), l, crayon"reset")
      end
      print(" ")
    end
    if with_position_names
      print(" | ")
      for x in 1:BOARD_SIDE
        print(print_pos(pos_of_xy((x, y))), " ")
      end
    end
    print("\n")
  end
end

################################################################################

function interactive!(s::State; red::Agent, blue::Agent, solution=nothing)
  while true
    print(style(s.curplayer), playername(s.curplayer), "'s turn")
    print(crayon"reset", "\n\n")
    print_board(s, with_position_names=true)
    if INTERFACE_PRINT_AVAILABLE
      print("\n")
      print_available(s, Red)
      print(" ")
      print_available(s, Blue)
      print("\n")
    end
    print("\n")
    if s.finished
      if isnothing(s.winner)
        println(crayon"yellow", "It's a tie!")
      else
        println(style(s.winner), "$(playername(s.winner)) wins !")
      end
      break
    end
    curagent = s.curplayer == Red ? red : blue
    # The human plays
    if isa(curagent, Human)
      a = nothing
      while a == nothing || a ∉ available_actions(s)
        print("> ")
        input = readline()
        isempty(input) && return
        a = parse_action(s, input)
        if isnothing(a) && !isnothing(solution) # Special command
          inputws = split(lowercase(input))
          if inputws[1] ∈ ["v", "value"]
            println(value(solution, s))
          elseif inputws[1] ∈ ["q", "qvalue"] && length(inputws) >= 2
            aquery = parse_action(s, inputws[2])
            if !isnothing(aquery) && aquery ∈ available_actions(s)
              println(Qvalue(solution, s, aquery))
            end
          end
        end
      end
      execute_action!(s, a)
      println("")
    # The computer plays
    else
      @assert isa(curagent, AI)
      a = play(curagent, s)
      execute_action!(s, a)
    end
  end
end

################################################################################
