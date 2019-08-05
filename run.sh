#!/bin/sh

julia -O3 --check-bounds=no --color=yes Main.jl
