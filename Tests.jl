################################################################################
# Tests
################################################################################

include("Game.jl")
include("Encoding.jl")
include("Solve.jl")
include("Interface.jl")

using Test

@testset "Unit tests" begin

################################################################################
# Interface

@testset "pos conversions" begin
  for p in 1:NUM_POSITIONS
    @test pos_of_xy(xy_of_pos(p)) == p
  end
end

@testset "parsing" begin
  all(parse_pos(print_pos(i)) == i for i in 1:NUM_POSITIONS)
  print_pos(parse_pos('b')) == 'B'
end

################################################################################
# Encodings

@testset "layout encodings" begin
  for (i, l) in enumerate(LAYER_LAYOUTS)
    @test encode_layout(l...) == i - 1
  end
end

@testset "k-subsets encoding" begin
  k, a, b = 2, 1, 10
  N = binomial(b-a+1,k)
  codes = [encode_ksubset(S, k, a, b) for S in enumerate_ksubsets(k, a, b)]
  @test codes == collect(0:N-1)
end

@testset "layer encoding" begin
  for i in 0:CARD_LAYERS-1
    @test encode_layer(decode_layer(i)) == i
  end
end

################################################################################
# Solving

@testset "state status encoding" begin
  for minv in -1:1
    for maxv in -1:1
      if minv <= maxv
        s = Status(minv, maxv)
        @test minvalue(s) == minv
        @test maxvalue(s) == maxv
      end
    end
  end
end

################################################################################

end

################################################################################
