################################################################################
# Gobblet gobblers
################################################################################

include("Game.jl")
include("Encoding.jl")
include("Solve.jl")
include("Interface.jl")
#include("Tests.jl")

using Crayons
using Serialization
using Printf

const SOLUTION_FILE = "$(string(GAME)).sol"

if isfile(SOLUTION_FILE)
  solution = deserialize(SOLUTION_FILE)
else
  solution = Solution()
end

while !solution.complete
  println("Starting learning iteration: ", solution.itnum + 1)
  iterate!(solution, progressbar=true)
  serialize(SOLUTION_FILE, solution)
  @printf("Solved states: %d/%d (%.2f%%).\n",
    solution.numsolved,
    CARD_BOARDS,
    100 * solution.numsolved / CARD_BOARDS)
end

print("\n")

state = State()
interactive!(state, AI=solution)

################################################################################
