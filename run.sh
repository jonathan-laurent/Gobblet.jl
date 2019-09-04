#!/bin/sh

julia --project -O3 --check-bounds=no --color=yes scripts/Driver.jl # tictactoe
