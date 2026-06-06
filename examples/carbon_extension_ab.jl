# # Carbon-tax extension — WITH abatement
#
# Base (no-tax) vs carbon-tax comparison where the sectors listed in
# `abatement_sectors` (carbon_extension_common.jl) are each split into a fossil and
# a renewable "green firm". The carbon run ramps the tax AND reallocates capacity
# from fossil to renewable, s,0o emissions can fall both by switching technology and
# by reduced demand. Compare against carbon_extension_nab.jl (no green firms) to
# see how much of the result the abatement channel is responsible for.

include("carbon_extension_common.jl")

display(run_comparison(; abatement = true, show_tables = true))
