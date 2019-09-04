# julia --project --track-allocation=user test/profile.jl

using Gobblet
using Profile

onesec = Gobblet.CARD_BOARDS ÷ 7200
Gobblet.test_encode_board(n = onesec)
Profile.clear_malloc_data()
@time Gobblet.test_encode_board(n = 10 * onesec)
