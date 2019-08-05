################################################################################
# Console Interface
################################################################################

using Crayons

style(p::Player) = p == Red ? crayon"light_red" : crayon"light_blue"

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
        print(style(poscolor(s, pos)), l, crayon"reset")
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

function interactive!(s::State; human::Player=Red, AI::AI=RandomAI())
  while true
    print_board(s, with_position_names=true)
    if INTERFACE_PRINT_AVAILABLE
      print("\n")
      print_available(s, human)
      print(" ")
      print_available(s, symmetric(human))
      print("\n")
    end
    print("\n")
    if s.finished
      if s.winner == human
        msg = "You win!"
      elseif s.winner == symmetric(human)
        msg = "You loose!"
      else
        msg = "This is a tie."
      end
      println(crayon"yellow", msg, crayon"reset")
      break
    end
    # The human plays
    if s.curplayer == human
      a = nothing
      while a == nothing || a ∉ available_actions(s)
        print("> ")
        input = readline()
        isempty(input) && return
        a = parse_action(s, input)
        if isnothing(a) && isa(AI, Solution) # Special command
          inputws = split(lowercase(input))
          if inputws[1] ∈ ["v", "value"]
            println(value(AI, s))
          elseif inputws[1] ∈ ["q", "qvalue"] && length(inputws) >= 2
            aquery = parse_action(s, inputws[2])
            if !isnothing(aquery) && aquery ∈ available_actions(s)
              println(Qvalue(AI, s, aquery))
            end
          end
        end
      end
      execute_action!(s, a)
      println("")
    # The computer plays
    else
      a = play(AI, s)
      execute_action!(s, a)
    end
  end
end

################################################################################
