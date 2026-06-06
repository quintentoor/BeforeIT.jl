# # Carbon-tax extension — WITHOUT abatement
#
# Base (no-tax) vs carbon-tax comparison with NO sector splits: there is no
# cleaner firm to switch to, so the carbon run (a plain `CarbonTaxRamp`) can only
# cut emissions by destroying demand — higher prices, lower output. This isolates
# the pure tax effect and is the cleaner control for the with-abatement run in
# carbon_extension_ab.jl.

include("carbon_extension_common.jl")

display(run_comparison(; abatement = false, show_tables = true))
