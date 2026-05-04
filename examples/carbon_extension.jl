# # Carbon-tax extension
#
# Side-by-side comparison of the base `Model` and `ModelCarbon`. The carbon
# variant taxes a single sector heavily; we expect that sector's prices to rise
# and the government's tax revenue to be higher under the carbon model.

import BeforeIT as Bit
using Plots, JLD2, Random

# Load NL/2015Q1 calibration (matches `examples/basic_example.jl`).
data = load("data/020_calibration_output/NL/2015Q1_parameters_initial_conditions.jld2")
parameters = data["parameters"]
initial_conditions = data["initial_conditions"]

T = 16
G = Int(parameters["G"])

# Pick one sector to be "dirty". Its index depends on the calibration's sector
# ordering — sector 1 is just a placeholder; pick whichever sector you want to
# study once real emission data is wired in.
dirty_sector = 1
intensity = zeros(Float64, G)
intensity[dirty_sector] = 1.0
# Tax per carbon output
tau_carbon = 0.02

# Total carbon intensity at the current model state: sum over sectors of
# (per-sector intensity × per-sector Y), computed at firm level.
carbon_total(firms, intensity_s) = sum(intensity_s[firms.G_i] .* firms.Y_i)

# Run the base model.
Random.seed!(1)
base = Bit.Model(parameters, initial_conditions)
carbon_base = Float64[]
for _ in 1:T
    Bit.step!(base; parallel = true)
    Bit.collect_data!(base)
    push!(carbon_base, carbon_total(base.firms, intensity))
end

# Run the carbon model with the same RNG seed so the only difference is the tax.
Random.seed!(1)
carbon = Bit.ModelCarbon(
    parameters, initial_conditions; tau_carbon = tau_carbon, carbon_intensity_s = intensity,
)
carbon_carbon = Float64[]
for _ in 1:T
    Bit.step!(carbon; parallel = true)
    Bit.collect_data!(carbon)
    push!(carbon_carbon, carbon_total(carbon.firms, intensity))
end

# Plot GDP deflator and government revenue, base vs carbon.
p1 = plot(base.data.gdp_deflator_growth_ea, label = "base", title = "EA inflation")
plot!(p1, carbon.data.gdp_deflator_growth_ea, label = "carbon")

p2 = plot(base.data.taxes_production, label = "base", title = "taxes_production", ylims = (0, Inf))
plot!(p2, carbon.data.taxes_production, label = "carbon")

p3 = plot(
    1:T, carbon_base, label = "base", title = "total carbon intensity",
    xlabel = "timestep", ylabel = "Σ intensity_g · Y_g",
)
plot!(p3, 1:T, carbon_carbon, label = "carbon")

# Average price in the dirty sector over time. Recomputed from final firm-level
# state for both models for a quick sanity print.
dirty_mask_base = base.firms.G_i .== dirty_sector
dirty_mask_carbon = carbon.firms.G_i .== dirty_sector
println("base   mean price in dirty sector: ", sum(base.firms.P_i[dirty_mask_base]) / count(dirty_mask_base))
println("carbon mean price in dirty sector: ", sum(carbon.firms.P_i[dirty_mask_carbon]) / count(dirty_mask_carbon))
println("base   gov.Y_G: ", base.gov.Y_G)
println("carbon gov.Y_G: ", carbon.gov.Y_G)

plot(p1, p2, p3, layout = (1, 3), size = (1350, 350))
