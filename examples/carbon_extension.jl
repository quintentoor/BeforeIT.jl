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

T = 32
G = Int(parameters["G"])

# CES elasticity of substitution across consumption sectors. Applied to BOTH
# `Bit.Model` and `Bit.ModelCarbon` below via the shared `parameters` dict.
# 0 → Leontief (original behavior); 1 → Cobb-Douglas; >1 → strong substitution.
# No α rescaling is needed: all model prices are initialised to 1
# (agg.P_bar_g, firms.P_i), so q_i/q_j = α_i/α_j in the initial year under any σ.
sigma_HH = 1.0
parameters["sigma_HH"] = sigma_HH

intensity = zeros(Float64, G)
# Carbon intensities (tCO2 / € of gross output), NL 2015, BeforeIT 62-sector ordering
# Source: Eurostat env_ac_ainah_r2 (CO2 emissions) / nama_10_a64 (gross output), base year 2015
intensity = [
    0.0002867,   #  1  A01     Crop and animal production
    0.0003368,   #  2  A02     Forestry and logging
    0.0006857,   #  3  A03     Fishing and aquaculture
    0.0001092,   #  4  B       Mining and quarrying
    0.0000591,   #  5  C10-C12 Food, beverages, tobacco
    0.0000536,   #  6  C13-C15 Textiles, apparel, leather
    0.000029,   #  7  C16     Wood
    0.0001199,   #  8  C17     Paper
    0.0000199,   #  9  C18     Printing
    0.0004426,   # 10  C19     Coke and refined petroleum
    0.0003718,   # 11  C20     Chemicals
    0.0000169,   # 12  C21     Pharmaceuticals
    0.0000358,   # 13  C22     Rubber and plastics
    0.0003641,   # 14  C23     Non-metallic minerals
    0.00094,   # 15  C24     Basic metals
    0.0000242,   # 16  C25     Fabricated metals
    0.0000009,   # 17  C26     Computer/electronic/optical
    0.0000306,   # 18  C27     Electrical equipment
    0.0000103,   # 19  C28     Machinery
    0.0000133,   # 20  C29     Motor vehicles
    0.0000103,   # 21  C30     Other transport equipment
    0.0000461,   # 22  C31_C32 Furniture/other manufacturing
    0.0000238,   # 23  C33     Repair and installation
    0.002993,   # 24  D       Electricity, gas, steam
    0.0000156,   # 25  E36     Water
    0.000365,   # 26  E37-E39 Sewerage, waste
    0.000039,   # 27  F       Construction
    0.0000255,   # 28  G45     Motor vehicle trade
    0.0000236,   # 29  G46     Wholesale
    0.000034,   # 30  G47     Retail
    0.0002,   # 31  H49     Land transport
    0.0008588,   # 32  H50     Water transport
    0.001198,   # 33  H51     Air transport
    0.0000278,   # 34  H52     Warehousing
    0.0000229,   # 35  H53     Postal/courier
    0.0000424,   # 36  I       Accommodation and food service
    0.0000051,   # 37  J58     Publishing
    0.0000033,   # 38  J59_J60 Film/broadcasting
    0.0000072,   # 39  J61     Telecommunications
    0.0000042,   # 40  J62_J63 Computer programming/IT
    0.0000044,   # 41  K64     Financial services
    0.0000054,   # 42  K65     Insurance/pension
    0.0000059,   # 43  K66     Auxiliary financial
    0.000008,   # 44  L       Real estate (excl. imputed)
    0.0000055,   # 45  M69_M70 Legal/accounting/consultancy
    0.0000084,   # 46  M71     Architecture/engineering
    0.000012,   # 47  M72     Scientific R&D
    0.0000086,   # 48  M73     Advertising/market research
    0.0000112,   # 49  M74_M75 Other professional
    0.0000318,   # 50  N77     Rental and leasing
    0.0000331,   # 51  N78     Employment activities
    0.0000291,   # 52  N79     Travel agency
    0.0000438,   # 53  N80-N82 Security/services to buildings
    0.0000137,   # 54  O       Public administration
    0.0000141,   # 55  P       Education
    0.0000149,   # 56  Q86     Human health
    0.0000257,   # 57  Q87_Q88 Social work
    0.0000267,   # 58  R90-R92 Creative/arts/cultural
    0.0000475,   # 59  R93     Sports/recreation
    0.000044,   # 60  S94     Membership organisations
    0.0000264,   # 61  S95     Repair of computers/household goods
    0.0000317,   # 62  S96     Other personal services
]
@assert length(intensity) == 62
# Tax per unit of tCO₂. The carbon run below uses an *incremental* tax that
# rises by `tau_carbon_increment` every quarter, starting from `tau_carbon_0`.
tau_carbon_0 = 30
tau_carbon_increment = 2.64
# Quarter in which the tax first switches on. Quarters before this are tax-free.
# e.g. `tau_carbon_start = 5` means no tax for the first 4 quarters, then the
# ramp begins (charging `tau_carbon_0` in quarter 5).
tau_carbon_start = 5
# Quarter at which the tax STOPS rising and holds flat (a plateau, not an end
# date — the tax is still charged after this). Set to `T` (or higher) for a tax
# that rises for the whole run; lower it to plateau earlier.
tau_carbon_final_time = 22
# Per-quarter tax path, for context/plotting: 0 before start, then rises and
# plateaus at final_time.
tau_carbon_path = [
    t < tau_carbon_start ? 0.0 :
        tau_carbon_0 + tau_carbon_increment * (min(t, tau_carbon_final_time) - tau_carbon_start)
        for t in 1:T
]

# --- Option A: split the electricity sector into a fossil and a renewable firm ---
# Electricity (NACE D, index 24) carries ~⅓ of all emissions but is a single firm
# in this calibration, so the tax has no cleaner competitor to shift demand to.
# We split it into a fossil firm (carries the sector's CO₂) and a renewable firm
# (≈0 intensity); the existing price-weighted matching then reallocates demand
# from fossil to renewable once the tax bites.
elec_sector = 24
renewable_share_0 = 0.11   # NL renewable electricity share, ~2015

# Total carbon emissions at the current state, using PER-FIRM intensities (fossil
# firms carry the CO₂, renewable firms ≈0). Must use carbon_intensity_i, not the
# per-sector vector, so the clean firm is correctly counted as zero-emission.
emissions(model) = sum(model.firms.carbon_intensity_i .* model.firms.Y_i)

# Lump-sum carbon dividend recycled to each household this quarter, in euros.
# Equals the carbon revenue collected (Σ tau_carbon · intensity · Y) divided
# equally over all H households — exactly what `set_gov_social_benefits!` pays out.
carbon_dividend(model) =
    sum(model.firms.tau_carbon .* model.firms.carbon_intensity_i .* model.firms.Y_i) / model.prop.H

# Unemployment rate over the active workforce: O_h == 0 means unemployed.
unemployment_rate(model) = count(==(0), model.w_act.O_h) / length(model.w_act.O_h)

# Build a split carbon model (shared constructor args). `tau` selects the run.
make_model(tau) = Bit.ModelCarbon(
    parameters, initial_conditions;
    tau_carbon = tau, carbon_intensity_s = intensity,
    split_sector = elec_sector, renewable_share = renewable_share_0,
)

# Baseline: the SAME split structure but with no tax, so the only difference
# versus the carbon run is the tax itself (isolates the policy effect).
Random.seed!(1)
base = make_model(0.0)
# Indices of the two electricity firms (fossil first, renewable second).
elec = findall(==(elec_sector), base.firms.G_i)
foss_i, ren_i = elec[1], elec[2]

carbon_base = Float64[]
unemp_base = Float64[]
for _ in 1:T
    Bit.step!(base; parallel = true)
    Bit.collect_data!(base)
    push!(carbon_base, emissions(base))
    push!(unemp_base, unemployment_rate(base))
end

# Carbon run: same seed. The `CarbonTransition` shock both ramps the tax AND
# reallocates electricity capacity (capital + demand) from the fossil firm to the
# renewable firm at a pace set by the tax-driven price gap — the "build new
# capacity where it is cheapest" channel the base investment rule lacks.
Random.seed!(1)
carbon = make_model(tau_carbon_0)
ramp = Bit.CarbonTaxRamp(
    tau_carbon_0, tau_carbon_increment;
    start_time = tau_carbon_start, final_time = tau_carbon_final_time,
)
transition = Bit.CarbonTransition(ramp, elec_sector; rate = 0.3, max_step = 0.1)
carbon_carbon = Float64[]
unemp_carbon = Float64[]
lump_carbon = Float64[]
foss_Y = Float64[]; ren_Y = Float64[]   # electricity output by technology
ren_share = Float64[]                    # renewable share of electricity output
for _ in 1:T
    Bit.step!(carbon; parallel = true, shock! = transition)
    Bit.collect_data!(carbon)
    push!(carbon_carbon, emissions(carbon))
    push!(unemp_carbon, unemployment_rate(carbon))
    push!(lump_carbon, carbon_dividend(carbon))
    yf, yr = carbon.firms.Y_i[foss_i], carbon.firms.Y_i[ren_i]
    push!(foss_Y, yf); push!(ren_Y, yr); push!(ren_share, yr / (yf + yr))
end

# Plot GDP deflator and government revenue, base vs carbon.
p1 = plot(base.data.gdp_deflator_growth_ea, label = "base (no tax)", title = "EA inflation")
plot!(p1, carbon.data.gdp_deflator_growth_ea, label = "carbon")

p2 = plot(base.data.taxes_production, label = "base (no tax)", title = "taxes_production")
plot!(p2, carbon.data.taxes_production, label = "carbon")

p3 = plot(
    1:T, carbon_base, label = "base (no tax)", title = "total carbon emissions",
    xlabel = "timestep", ylabel = "Σ intensity_i · Y_i",
)
plot!(p3, 1:T, carbon_carbon, label = "carbon")

p4 = plot(base.data.real_gdp, label = "base (no tax)", title = "real GDP", xlabel = "timestep")
plot!(p4, carbon.data.real_gdp, label = "carbon")

p5 = plot(
    1:T, unemp_base, label = "base (no tax)", title = "unemployment rate",
    xlabel = "timestep", ylabel = "share of active workers",
)
plot!(p5, 1:T, unemp_carbon, label = "carbon")

# Lump-sum carbon dividend paid to each household per quarter. Zero before the tax
# switches on, then rises with the tax ramp and plateaus at `tau_carbon_final_time`.
p6 = plot(
    1:T, lump_carbon, label = "carbon",
    title = "carbon dividend per household",
    xlabel = "timestep", ylabel = "€ per household / quarter",
)

# Electricity output by technology under the carbon run, plus renewable share.
# As the tax raises the fossil firm's price, the price-weighted matching shifts
# demand to the (untaxed) renewable firm — fossil output falls, renewable rises.
p7 = plot(1:T, foss_Y, label = "fossil Y", title = "electricity output (carbon run)", xlabel = "timestep")
plot!(p7, 1:T, ren_Y, label = "renewable Y")
plot!(twinx(), 1:T, ren_share, label = "renew. share", color = :black, ls = :dash, legend = :right)

println("base   gov.Y_G: ", base.gov.Y_G)
println("carbon gov.Y_G: ", carbon.gov.Y_G)
println("renewable share of electricity:  t=1 ", round(ren_share[1], digits = 3),
    "   t=$T ", round(ren_share[end], digits = 3))
println("total emissions Δ vs base (t=$T): ",
    round(100 * (carbon_carbon[end] / carbon_base[end] - 1), digits = 2), "%")

plot(p1, p2, p3, p4, p5, p6, p7, layout = (4, 2), size = (900, 1300))
