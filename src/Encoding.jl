################################################################################
# Establishes an explicit bijection between the set of board states and
# an integer range, for fast indexing purposes
################################################################################

import StaticArrays

################################################################################

# A layout specifies the respective number of red/blue goblets on a layer

const LAYER_LAYOUTS = [(nr, nb)
  for nr in NUM_GOBBLET_COPIES:-1:0 for nb in NUM_GOBBLET_COPIES:-1:0]

const NUM_LAYER_LAYOUTS = length(LAYER_LAYOUTS)

function encode_layout(nr, nb)
  N = NUM_GOBBLET_COPIES
  return (N - nr) * (N + 1) + (N - nb)
end

const CUM_LAYERS_WITH = begin
  local count_layers_with_layout((nr, nb)) =
    binomial(NUM_POSITIONS, nr) * binomial(NUM_POSITIONS - nr, nb)
  [0; cumsum(map(count_layers_with_layout, LAYER_LAYOUTS))]
end

const CARD_LAYERS = CUM_LAYERS_WITH[end]

################################################################################

# Enumerates the subsets of size k of the integer range [a, b]
function enumerate_ksubsets(k, a, b)
  if k == 0
    return [[]]
  else
    with(x) = [[x;tl] for tl in enumerate_ksubsets(k-1, x+1, b)]
    return vcat([with(x) for x in a:b-k+1]...)
  end
end

function encode_ksubset(data, k, a, b)
  code = 0
  i = 1
  while k > 0
    x = data[i]
    code += binomial(b-a+1, k) - binomial(b-x+1, k)
    i += 1
    k -= 1
    a = x + 1
  end
  return code
end

################################################################################

# Defined once outside `encode_layer` to avoid useless allocations
const global_rs = StaticArrays.MVector{NUM_GOBBLET_COPIES, Int}(undef)
const global_bs = StaticArrays.MVector{NUM_GOBBLET_COPIES, Int}(undef)

function encode_layer(get, layer)
  nr = 0
  nb = 0
  for i in 1:NUM_POSITIONS
    if get(layer, i) == Red
      nr += 1
      global_rs[nr] = i
    elseif get(layer, i) == Blue
      nb += 1
      global_bs[nb] = i - nr
    end
  end
  code = CUM_LAYERS_WITH[encode_layout(nr, nb) + 1]
  rcode = encode_ksubset(global_rs, nr, 1, NUM_POSITIONS)
  bcode = encode_ksubset(global_bs, nb, 1, NUM_POSITIONS - nr)
  code += rcode + bcode * binomial(NUM_POSITIONS, nr)
  return code
end

encode_layer(layer) = encode_layer((L, i) -> L[i], layer)

################################################################################

function generate_layers_table()
  N = CARD_LAYERS
  done = falses(CARD_LAYERS)
  table = Array{LayerCell, 2}(undef, (NUM_POSITIONS, CARD_LAYERS))
  for (nr, nb) in LAYER_LAYOUTS
    for rs in enumerate_ksubsets(nr, 1, NUM_POSITIONS)
      for bs in enumerate_ksubsets(nb, 1, NUM_POSITIONS - nr)
        # Generate a layer
        L = Vector{LayerCell}(undef, NUM_POSITIONS)
        fill!(L, nothing)
        for r in rs
          L[r] = Red
          bs[bs .>= r] .+= 1
        end
        for b in bs
          L[b] = Blue
        end
        # Add the layer to the table
        code = encode_layer(L)
        done[code+1] = true
        table[:,code+1] = L
      end
    end
  end
  @assert all(done) # all layers have been enumerated
  return table
end

const LAYERS = generate_layers_table()

function decode_layer(code)
  return LAYERS[:,code+1]
end

# For performance reasons, we provide a version that writes the result in place
function decode_layer!(set, dest, code)
  for i in 1:NUM_POSITIONS
    set(dest, i, LAYERS[i, code+1])
  end
end

################################################################################

function encode_board(get, board)
  code = 0
  for l in 1:NUM_LAYERS
    lcode = encode_layer(board) do b, i
      get(b, i, l)
    end
    code += CARD_LAYERS^(l-1) * lcode
  end
  return code
end

function encode_board(board)
  encode_board(board) do b, i, j
    b[i, j]
  end
end

function decode_board!(board, code)
  for l in 1:NUM_LAYERS
    lcode = code % CARD_LAYERS
    decode_layer!(board, lcode) do b, i, v
      b[i,l] = v
    end
    code = code ÷ CARD_LAYERS
  end
end

const CARD_BOARDS = CARD_LAYERS ^ NUM_LAYERS

################################################################################

using ProgressMeter

function test_encode_board(;n=CARD_BOARDS, progressbar=false)
  B = make_board()
  progressbar && (p = Progress(n, 1))
  for i in 0:n-1
    decode_board!(B, i)
    @assert encode_board(B) == i
  progressbar && next!(p)
  end
end

################################################################################
