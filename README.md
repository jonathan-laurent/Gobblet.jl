# Gobblet.jl

The [Gobblet](https://en.wikipedia.org/wiki/Gobblet) game is a three-dimensional
_Tic-Tac-Toe_ variant where players have to align goblets that come in different
size, bigger pieces having the ability to cover smaller ones.

This repo contains a [Julia](https://julialang.org/) implementation of the game,
along with a [perfect strategy](https://en.wikipedia.org/wiki/Solved_game) for
the [junior
version](https://www.blueorangegames.com/index.php/games/gobbletgobblers) that
is played on a 3x3 board with goblets coming in three different sizes. We prove
that the first player can always secure a win, provided that their first move is
to place a small or large goblet (as opposed to a medium-sized one).

## Solving the Junior Game

The junior game has about three billion possible states. Therefore, it can be
solved by exhaustive search. Doing so on a personal computer requires a careful
implementation though. Moreover, we think that it makes for a good showcase of
how [Julia](https://julialang.org/) makes writing high-performance code painless
and natural.

To speed-up the search process, we use the following tricks:

+ We augment the standard _Value Iteration_ algorithm by maintaining both a
lower and an upper bound on the value of each state. When these two coincide,
the state is labelled as _solved_ and does not have to be updated using the
Bellman equation in future iterations. Because most states get solved in early
iterations, using this trick yields a ≈15x overall speedup.
+ Instead of using a hash table to store the value function, we build an
explicit bijection between the set of game states and the
[0, 2881473967] integer range. This allows a very compact representation of the
value function as a bit vector that can easily fit into main memory.

Using those tricks, a solution can be computed in about eight hours on a
personal computer.


## Usage

To start a game, just use `./run.sh`. The optimal strategy is computed and
stored at first launch.
