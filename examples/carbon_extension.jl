# # Carbon-tax extension — overview (both comparisons)
#
# Convenience entrypoint that runs BOTH validity comparisons in one go:
#   * WITH abatement    — sectors in `abatement_sectors` get a renewable firm and
#                         the tax can be abated by switching technology.
#   * WITHOUT abatement — no green firms; the tax cuts emissions only by
#                         destroying demand.
# Run the dedicated scripts instead to get just one:
#   * examples/carbon_extension_ab.jl   (with abatement)
#   * examples/carbon_extension_nab.jl  (without abatement)
# All shared data, the tax path and the list of abatement strategies live in
# examples/carbon_extension_common.jl — edit `abatement_sectors` there to add a
# green firm in another industry.

include("carbon_extension_common.jl")

p_ab = run_comparison(; abatement = true)
p_nab = run_comparison(; abatement = false)

display(p_ab)
display(p_nab)
