################################################################################
# Gobblet
################################################################################

using Crayons
using Serialization
using Printf

if "tictactoe" ∈ ARGS
  using Gobblet: TicTacToe
  using Gobblet.TicTacToe
  const Game = TicTacToe
else
  using Gobblet
  const Game = Gobblet
end

println(crayon"yellow", "\nLet's play Gobblet Gobblers!", crayon"reset")
flush(stdout)

################################################################################

const SOLUTION_FOLDER = "solution"
const SOLUTION_FILE = "$(SOLUTION_FOLDER)/$(string(GAME)).sol"

if !isdir(SOLUTION_FOLDER) mkdir(SOLUTION_FOLDER) end

if isfile(SOLUTION_FILE)
  solution = deserialize(SOLUTION_FILE)
else
  solution = Solution()
end

while solution.changed
  println("Starting learning iteration: ", solution.itnum + 1)
  iterate_value!(solution, progressbar=true)
  serialize(SOLUTION_FILE, solution)
  @printf("Solved states: %d/%d (%.2f%%).\n",
    solution.numsolved,
    Game.CARD_BOARDS,
    100 * solution.numsolved / Game.CARD_BOARDS)
end

print("\n")

function player_choice_prompt(p::Player)
  name = lowercase(player_name(p))
  while true
    print("Select $(name) player ([h]uman, [c]omputer): ")
      input = lowercase(readline())
      print("\n")
      if input ∈ ["h", "human"]
        return Human()
      elseif input ∈ ["c", "computer"]
        return PerfectPlay(solution)
      elseif input == ""
        return Human()
      end
    end
end

state = State()
red = player_choice_prompt(Red)
blue = player_choice_prompt(Blue)
interactive!(state, red=red, blue=blue, solution=solution)

################################################################################
