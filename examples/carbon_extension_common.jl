# # Carbon-tax extension — shared setup
#
# Shared data, configuration and the `run_comparison(; abatement)` driver used by
# both `carbon_extension_ab.jl` (abatement firms enabled) and
# `carbon_extension_nab.jl` (disabled). Keeping it here means the carbon-intensity
# data, the tax path and the list of abatement strategies live in exactly one
# place. `include("carbon_extension_common.jl")` then call `run_comparison`.

import BeforeIT as Bit
using Plots, JLD2, Random, Statistics

# Per-graph plotting functions. Each file in `carbon_plots/` defines ONE graph as
# a function (e.g. `plot_real_gdp`, `plot_unemployment`); `plot_helpers.jl` holds
# the shared `confidence_band`/`compare_panel`/`quarter_xticks` helpers they use.
# To add a graph: drop a new file in that folder, `include` it here, and add a
# call to the `panels = [...]` list in `run_comparison`.
const CARBON_PLOT_DIR = joinpath(@__DIR__, "carbon_plots")
include(joinpath(CARBON_PLOT_DIR, "plot_helpers.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_inflation.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_taxes_production.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_emissions.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_real_gdp.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_unemployment.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_carbon_dividend.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_renewable_share.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_gdp_growth_quarterly.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_unemployment_quarterly.jl"))

# Load NL/2015Q1 calibration (matches `examples/basic_example.jl`).
data = load("data/020_calibration_output/NL/2023Q4_parameters_initial_conditions.jld2")
parameters = data["parameters"]
initial_conditions = data["initial_conditions"]

T = 20  # 37 quarters: t=1 → 2024Q1, t=37 → 2033Q1 (initial conditions are 2023Q4)
G = Int(parameters["G"])

# Trend labour-productivity growth, in % per YEAR (the model steps quarterly).
# With a fixed workforce, real output is capped at ∑ N_i·alpha_i; once
# unemployment hits 0% the only way output can keep growing is for productivity
# `alpha_bar_i` to rise. Applied to BOTH the base and carbon runs (same trend) so
# the comparison stays clean. Set to 0.0 to recover the original flat-productivity
# behaviour.
alpha_growth_annual = 0.0154  # +1.54%/year

# CES elasticity of substitution across consumption sectors. Applied to BOTH
# `Bit.Model` and `Bit.ModelCarbon` below via the shared `parameters` dict.
# 0 → Leontief (original behavior); 1 → Cobb-Douglas; >1 → strong substitution.
# No α rescaling is needed: all model prices are initialised to 1
# (agg.P_bar_g, firms.P_i), so q_i/q_j = α_i/α_j in the initial year under any σ.
sigma_HH = 1.0
parameters["sigma_HH"] = sigma_HH

# Carbon intensities (tCO2 / € of gross output), NL 2015, BeforeIT 62-sector ordering
# Source: Eurostat env_ac_ainah_r2 (CO2 emissions) / nama_10_a64 (gross output), base year 2015
intensity = [
    0.000413,   #  1  A01     Crop and animal production
    0.000311,   #  2  A02     Forestry and logging
    0.001230,   #  3  A03     Fishing and aquaculture
    0.000201,   #  4  B       Mining and quarrying
    0.000199,   #  5  C10-C12 Food, beverages, tobacco
    0.000116,   #  6  C13-C15 Textiles, apparel, leather
    0.000045,   #  7  C16     Wood
    0.000170,   #  8  C17     Paper
    0.000042,   #  9  C18     Printing
    0.003826,   # 10  C19     Coke and refined petroleum
    0.002116,   # 11  C20     Chemicals
    0.000010,   # 12  C21     Pharmaceuticals
    0.000068,   # 13  C22     Rubber and plastics
    0.000498,   # 14  C23     Non-metallic minerals
    0.002518,   # 15  C24     Basic metals
    0.000049,   # 16  C25     Fabricated metals
    0.000007,   # 17  C26     Computer/electronic/optical
    0.000029,   # 18  C27     Electrical equipment
    0.000012,   # 19  C28     Machinery
    0.000036,   # 20  C29     Motor vehicles
    0.000043,   # 21  C30     Other transport equipment
    0.000070,   # 22  C31_C32 Furniture/other manufacturing
    0.000037,   # 23  C33     Repair and installation
    0.001099,   # 24  D       Electricity, gas, steam
    0.000017,   # 25  E36     Water
    0.000661,   # 26  E37-E39 Sewerage, waste
    0.000069,   # 27  F       Construction
    0.000032,   # 28  G45     Motor vehicle trade
    0.000024,   # 29  G46     Wholesale
    0.000028,   # 30  G47     Retail
    0.000344,   # 31  H49     Land transport
    0.002055,   # 32  H50     Water transport
    0.002531,   # 33  H51     Air transport
    0.000033,   # 34  H52     Warehousing
    0.000051,   # 35  H53     Postal/courier
    0.000044,   # 36  I       Accommodation and food service
    0.000005,   # 37  J58     Publishing
    0.000003,   # 38  J59_J60 Film/broadcasting
    0.000007,   # 39  J61     Telecommunications
    0.000002,   # 40  J62_J63 Computer programming/IT
    0.000004,   # 41  K64     Financial services
    0.000005,   # 42  K65     Insurance/pension
    0.000005,   # 43  K66     Auxiliary financial
    0.000003,   # 44  L       Real estate (excl. imputed)
    0.000005,   # 45  M69_M70 Legal/accounting/consultancy
    0.000008,   # 46  M71     Architecture/engineering
    0.000011,   # 47  M72     Scientific R&D
    0.000023,   # 48  M73     Advertising/market research
    0.000017,   # 49  M74_M75 Other professional
    0.000031,   # 50  N77     Rental and leasing
    0.000031,   # 51  N78     Employment activities
    0.000050,   # 52  N79     Travel agency
    0.000040,   # 53  N80-N82 Security/services to buildings
    0.000013,   # 54  O       Public administration
    0.000011,   # 55  P       Education
    0.000011,   # 56  Q86     Human health
    0.000016,   # 57  Q87_Q88 Social work
    0.000026,   # 58  R90-R92 Creative/arts/cultural
    0.000061,   # 59  R93     Sports/recreation
    0.000044,   # 60  S94     Membership organisations
    0.000031,   # 61  S95     Repair of computers/household goods
    0.000024,   # 62  S96     Other personal services
]
@assert length(intensity) == 62

# Tax per unit of tCO₂. The carbon run below uses an *incremental* tax that
# rises by `tau_carbon_increment` every quarter, starting from `tau_carbon_0`.
tau_carbon_0 = 30
tau_carbon_increment = (128 - 30) / 18  # ≈5.444 €/q: ramps 30€→128€ over 4.5y (18 quarters), reaching 128€ at t=19 (2028Q3)
# Quarter in which the tax first switches on. Quarters before this are tax-free.
tau_carbon_start = 1
# Quarter at which the tax STOPS rising and holds flat (a plateau, not an end
# date — the tax is still charged after this). Set to `T` for a tax that rises
# for the whole run; lower it to plateau earlier.
tau_carbon_final_time = 19  # plateau at 128€ from t=19 (2028Q3) onward; ramp spans 4.5y starting 2024Q1
# Per-quarter tax path, for context/plotting: 0 before start, then rises and
# plateaus at final_time.
tau_carbon_path = [
    t < tau_carbon_start ? 0.0 :
        tau_carbon_0 + tau_carbon_increment * (min(t, tau_carbon_final_time) - tau_carbon_start)
        for t in 1:T
]

# --- Abatement strategies: one "green firm" per row ----------------------------
# Each row splits a sector into its existing fossil firm(s) plus one renewable
# firm (≈0 intensity); under the carbon tax the price-weighted matching then
# reallocates demand from fossil to renewable. These are only active in the
# `abatement = true` run (carbon_extension_ab.jl); the `nab` run leaves every
# sector whole, so the tax can only cut emissions by destroying demand.
#
# To add an abatement strategy in another industry, append a row:
#     (sector = <index>, renewable_share = <0..1>, renewable_intensity = <tCO2/€>)
# e.g. land transport (31), water transport (32), air transport (33), basic
# metals (15), chemicals (11). renewable_share is the clean firm's initial share
# of that sector's size; renewable_intensity is its CO₂ intensity (usually 0).
abatement_sectors = [
    (sector = 24, renewable_share = 0.172, renewable_intensity = 0.0),  # electricity (NACE D), NL ~2023
]

# --- Tracking helpers ----------------------------------------------------------
# Total carbon emissions, using PER-FIRM intensities (fossil firms carry the CO₂,
# renewable firms ≈0). Works for both runs: with no split every firm just carries
# its sector intensity.
emissions(model) = sum(model.firms.carbon_intensity_i .* model.firms.Y_i)

# Lump-sum carbon dividend recycled to each household this quarter, in euros.
carbon_dividend(model) =
    sum(model.firms.tau_carbon .* model.firms.carbon_intensity_i .* model.firms.Y_i) / model.prop.H

# Unemployment rate over the active workforce: O_h == 0 means unemployed.
unemployment_rate(model) = count(==(0), model.w_act.O_h) / length(model.w_act.O_h)


"""
    run_comparison(; abatement::Bool, n_sims::Int = 5, show_tables::Bool = false)

Run the base (no-tax) vs carbon-tax comparison and return the assembled plot.

Pass `show_tables = true` to also print, for every series, a table of its
cross-run mean against time (the numbers behind the graphs) to the console.

`abatement = true`  → both runs split every sector in `abatement_sectors` into a
fossil + renewable firm, and the carbon run uses a `CarbonTransition` shock that
ramps the tax AND reallocates capacity from fossil to renewable. Emissions can
fall both by switching technology and by reduced demand.

`abatement = false` → no sector is split. The carbon run uses a plain
`CarbonTaxRamp` (tax only, no cleaner alternative to switch to), so emissions can
fall only through reduced output/demand. This isolates the pure tax effect and is
the cleaner control for judging how much the abatement channel is doing.

Runs `n_sims` Monte-Carlo repetitions. Each repetition `s` uses a distinct RNG
seed, so the model's stochasticity shows up as run-to-run variability. Within a
repetition the base and carbon runs share the SAME seed, so the only difference
between them is the carbon tax itself — the comparison stays clean per run while
the band across runs shows estimation uncertainty. Every panel plots the cross-run
mean as a line with a 95% confidence-interval ribbon (mean ± 1.96·std/√n).
"""
function run_comparison(; abatement::Bool, n_sims::Int = 100, show_tables::Bool = false)
    split = [s.sector for s in abatement_sectors]
    shares = [s.renewable_share for s in abatement_sectors]
    rints = [s.renewable_intensity for s in abatement_sectors]

    # Build a model at tax rate `tau`. With abatement we split the configured
    # sectors; without, we leave every sector whole.
    make_model(tau) =
        abatement ?
        Bit.ModelCarbon(
            parameters, initial_conditions;
            tau_carbon = tau, carbon_intensity_s = intensity,
            split_sector = split, renewable_share = shares, renewable_intensity = rints,
        ) :
        Bit.ModelCarbon(
            parameters, initial_conditions;
            tau_carbon = tau, carbon_intensity_s = intensity,
        )

    # Baseline: the SAME structure but no tax, so the only difference versus the
    # carbon run is the tax itself (isolates the policy effect).
    # Trend productivity growth, applied identically to both runs.
    growth = Bit.ProductivityGrowth(alpha_growth_annual)

    ramp = Bit.CarbonTaxRamp(
        tau_carbon_0, tau_carbon_increment;
        start_time = tau_carbon_start, final_time = tau_carbon_final_time,
    )
    # With abatement, the transition shock also reallocates capacity toward the
    # renewable firms; without, the tax just ramps. Either way, combine it with the
    # same productivity-growth trend used in the base run.
    carbon_shock = abatement ? Bit.CarbonTransition(ramp, split; rate = 0.3, max_step = 0.1) : ramp
    shock! = Bit.CombinedShock(growth, carbon_shock)

    # Monte-Carlo storage: one column per repetition, one row per timestep. The
    # hand-tracked series (emissions/unemployment/dividend/renewable share) are
    # length T (one push per simulated step). The built-in `model.data` series are
    # length T+1 (they carry an initial point), so collect those as vectors per
    # repetition and hcat afterwards — their own length is used on the x-axis.
    emis_base = zeros(T, n_sims);    emis_carbon = zeros(T, n_sims)
    unemp_base = zeros(T, n_sims);   unemp_carbon = zeros(T, n_sims)
    lump_carbon = zeros(T, n_sims)
    ren_share = [zeros(T, n_sims) for _ in split]  # renewable share of each split sector's output
    infl_base_v = Vector{Float64}[];    infl_carbon_v = Vector{Float64}[]
    taxprod_base_v = Vector{Float64}[]; taxprod_carbon_v = Vector{Float64}[]
    gdp_base_v = Vector{Float64}[];     gdp_carbon_v = Vector{Float64}[]
    yg_base = zeros(n_sims);         yg_carbon = zeros(n_sims)

    for s in 1:n_sims
        # Progress indicator so a long Monte-Carlo run shows how far it has got.
        # `\r` rewrites the same line; `flush` forces it out before the heavy step loop.
        print("\rRun $s/$n_sims"); flush(stdout)
        # Distinct seed per repetition → run-to-run variability. Base and carbon
        # within a repetition share the seed, so only the tax differs between them.
        Random.seed!(s)
        base = make_model(0.0)
        for t in 1:T
            Bit.step!(base; parallel = true, shock! = growth)
            Bit.collect_data!(base)
            emis_base[t, s] = emissions(base)
            unemp_base[t, s] = unemployment_rate(base)
        end
        push!(infl_base_v, copy(base.data.gdp_deflator_growth_ea))
        push!(taxprod_base_v, copy(base.data.taxes_production))
        push!(gdp_base_v, copy(base.data.real_gdp))
        yg_base[s] = base.gov.Y_G

        # Carbon run: same seed. Construct tax-free — the shock sets `tau_carbon`
        # every step (zero before `tau_carbon_start`), so the initial rate is
        # irrelevant for the simulated steps and no carbon slug leaks into the
        # initial data point.
        Random.seed!(s)
        carbon = make_model(0.0)
        # Firm indices per split sector, for the technology-mix panel (abatement only).
        sector_idx = abatement ? [findall(==(sec), carbon.firms.G_i) for sec in split] : Vector{Int}[]
        for t in 1:T
            Bit.step!(carbon; parallel = true, shock! = shock!)
            Bit.collect_data!(carbon)
            emis_carbon[t, s] = emissions(carbon)
            unemp_carbon[t, s] = unemployment_rate(carbon)
            lump_carbon[t, s] = carbon_dividend(carbon)
            for (k, idx) in enumerate(sector_idx)
                yr = carbon.firms.Y_i[idx[end]]
                ren_share[k][t, s] = yr / sum(@view carbon.firms.Y_i[idx])
            end
        end
        push!(infl_carbon_v, copy(carbon.data.gdp_deflator_growth_ea))
        push!(taxprod_carbon_v, copy(carbon.data.taxes_production))
        push!(gdp_carbon_v, copy(carbon.data.real_gdp))
        yg_carbon[s] = carbon.gov.Y_G
    end
    println("\rRun $n_sims/$n_sims — done.")

    # Assemble the built-in series into (Td × n_sims) matrices (Td = T+1).
    infl_base = reduce(hcat, infl_base_v);       infl_carbon = reduce(hcat, infl_carbon_v)
    taxprod_base = reduce(hcat, taxprod_base_v); taxprod_carbon = reduce(hcat, taxprod_carbon_v)
    gdp_base = reduce(hcat, gdp_base_v);         gdp_carbon = reduce(hcat, gdp_carbon_v)

    mode = abatement ? "WITH abatement" : "WITHOUT abatement"

    # --- Graphs ----------------------------------------------------------------
    # Each entry calls one plotting function from `carbon_plots/` (one file per
    # graph). Comment a line out to hide that graph; uncomment one to show it. The
    # base-case-only quarterly graphs are commented out by default.
    panels = [
        plot_inflation(infl_base, infl_carbon),
        plot_taxes_production(taxprod_base, taxprod_carbon),
        plot_emissions(emis_base, emis_carbon),
        plot_real_gdp(gdp_base, gdp_carbon),
        plot_unemployment(unemp_base, unemp_carbon),
        plot_carbon_dividend(lump_carbon),
        # plot_gdp_growth_quarterly(gdp_base),       # base case only
        # plot_unemployment_quarterly(unemp_base),   # base case only
    ]

    # Renewable-share panel (abatement runs only).
    if abatement
        push!(panels, plot_renewable_share(ren_share, split))
    end
    

    println("--- $mode ($n_sims runs) ---")
    println("base   mean gov.Y_G: ", mean(yg_base))
    println("carbon mean gov.Y_G: ", mean(yg_carbon))
    if abatement
        for (k, s) in enumerate(split)
            mr, _ = confidence_band(ren_share[k])
            println(
                "mean renewable share of sector $s:  t=1 ", round(mr[1], digits = 3),
                "   t=$T ", round(mr[end], digits = 3)
            )
        end
    end
    mb_emis, _ = confidence_band(emis_base)
    mc_emis, _ = confidence_band(emis_carbon)
    println(
        "mean total emissions Δ vs base (t=$T): ",
        round(100 * (mc_emis[end] / mb_emis[end] - 1), digits = 2), "%"
    )

    # --- Tables ----------------------------------------------------------------
    # Optional: print each series' cross-run mean against time (the numbers behind
    # the graphs). Each `table_*` mirrors a `plot_*` from `carbon_plots/`. Pass
    # `show_tables = true` to enable; comment a line to drop that table.
    if show_tables
        println("\n=== Tables — cross-run mean vs timestep ($mode) ===")
        table_inflation(infl_base, infl_carbon)
        table_taxes_production(taxprod_base, taxprod_carbon)
        table_emissions(emis_base, emis_carbon)
        table_real_gdp(gdp_base, gdp_carbon)
        table_unemployment(unemp_base, unemp_carbon)
        table_carbon_dividend(lump_carbon)
        # table_gdp_growth_quarterly(gdp_base)        # base case only
        # table_unemployment_quarterly(unemp_base)    # base case only
        abatement && table_renewable_share(ren_share, split)
    end

    n = length(panels)
    rows = cld(n, 2)
    return plot(panels...; layout = (rows, 2), size = (900, 300 + 250 * rows), plot_title = mode)
end
