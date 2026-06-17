# # Carbon-tax extension — shared setup
#
# Shared data, configuration and the `run_comparison(; abatement)` driver used by
# both `carbon_extension_ab.jl` (abatement firms enabled) and
# `carbon_extension_nab.jl` (disabled). Keeping it here means the carbon-intensity
# data, the tax path and the list of abatement strategies live in exactly one
# place. `include("carbon_extension_common.jl")` then call `run_comparison`.
#=
Run:

julia --project=examples

include("examples/carbon_extension_common.jl")

sim = simulate(; abatement = false)

And then whichever graphs you want

For example: table_gdp_growth_quarterly(sim.gdp_base)
(make sure to put sim. in front)
=#
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
include(joinpath(CARBON_PLOT_DIR, "plot_total_inflation.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_taxes_production.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_emissions.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_emissions_diff.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_emissions_stacked.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_sector_prod_price.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_employment_polluters.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_profit_polluters.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_deposits_polluters.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_real_gdp.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_real_gdp_diff.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_consumption.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_consumption_diff.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_unemployment.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_unemployment_diff.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_carbon_dividend.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_dividend_vs_consumption.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_cpi.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_cpi_diff.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_renewable_share.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_gdp_growth_quarterly.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_gdp_growth_quarterly_sourced.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_unemployment_quarterly.jl"))
include(joinpath(CARBON_PLOT_DIR, "plot_unemployment_quarterly_sourced.jl"))

# Load NL/2023Q4 calibration 
data = load("data/020_calibration_output/NL/2023Q4_parameters_initial_conditions.jld2")
parameters = data["parameters"]
initial_conditions = data["initial_conditions"]

T = 20  # 20 quarters: t=1 → 2024Q1, t=20 → 2028Q4 (initial conditions are 2023Q4)
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

# Markup gap-closing speed in the firm price rule (supervisor's rule, replaces the
# old average-cost growth rule + agg.P_bar deflation):
#   π^c_i = kappa_cp * (mu_i * AC_i / P_i − 1),  mu_i = 1 / AC_i⁰
# Each quarter the firm closes fraction kappa_cp of the gap between its current
# cost/price ratio and the calibrated one. General inflation moves AC_i and P_i
# together so the gap is trend-neutral — no deflation needed. (pi_e is pinned to a
# constant anchor separately; see growth_inflation_expectations.) kappa_cp = 1 → fastest
# pass-through; lower → slower. Sensitivity range [0.5, 1.0]. Applied to BOTH base and
# carbon runs via the shared `parameters` dict.
kappa_cp = 0.5
parameters["kappa_cp"] = kappa_cp

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

# Human-readable label per sector, in the SAME 62-sector ordering as `intensity`
# above (NACE code + short name). Used to label the stacked per-sector emissions
# graph; the index into this vector is the model's sector index `G_i`.
sector_labels = [
    "A01 Crop & animal prod.",          #  1
    "A02 Forestry & logging",           #  2
    "A03 Fishing & aquaculture",        #  3
    "B Mining & quarrying",             #  4
    "C10-12 Food/bev/tobacco",          #  5
    "C13-15 Textiles/apparel",          #  6
    "C16 Wood",                         #  7
    "C17 Paper",                        #  8
    "C18 Printing",                     #  9
    "C19 Coke & refined petrol.",       # 10
    "C20 Chemicals",                    # 11
    "C21 Pharmaceuticals",              # 12
    "C22 Rubber & plastics",            # 13
    "C23 Non-metallic minerals",        # 14
    "C24 Basic metals",                 # 15
    "C25 Fabricated metals",            # 16
    "C26 Computer/electronic",          # 17
    "C27 Electrical equipment",         # 18
    "C28 Machinery",                    # 19
    "C29 Motor vehicles",               # 20
    "C30 Other transport equip.",       # 21
    "C31-32 Furniture/other mfg",       # 22
    "C33 Repair & installation",        # 23
    "D Electricity, gas, steam",        # 24
    "E36 Water",                        # 25
    "E37-39 Sewerage, waste",           # 26
    "F Construction",                   # 27
    "G45 Motor vehicle trade",          # 28
    "G46 Wholesale",                    # 29
    "G47 Retail",                       # 30
    "H49 Land transport",               # 31
    "H50 Water transport",              # 32
    "H51 Air transport",                # 33
    "H52 Warehousing",                  # 34
    "H53 Postal/courier",               # 35
    "I Accommodation & food",           # 36
    "J58 Publishing",                   # 37
    "J59-60 Film/broadcasting",         # 38
    "J61 Telecommunications",           # 39
    "J62-63 IT/programming",            # 40
    "K64 Financial services",           # 41
    "K65 Insurance/pension",            # 42
    "K66 Auxiliary financial",          # 43
    "L Real estate",                    # 44
    "M69-70 Legal/consultancy",         # 45
    "M71 Architecture/eng.",            # 46
    "M72 Scientific R&D",               # 47
    "M73 Advertising/mkt res.",         # 48
    "M74-75 Other professional",        # 49
    "N77 Rental & leasing",             # 50
    "N78 Employment activities",        # 51
    "N79 Travel agency",                # 52
    "N80-82 Security/bldg svc.",        # 53
    "O Public administration",          # 54
    "P Education",                      # 55
    "Q86 Human health",                 # 56
    "Q87-88 Social work",               # 57
    "R90-92 Creative/arts",             # 58
    "R93 Sports/recreation",            # 59
    "S94 Membership orgs",              # 60
    "S95 Repair comp./household",       # 61
    "S96 Other personal svc.",          # 62
]
@assert length(sector_labels) == 62

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

# Same emissions, broken down BY SECTOR: returns a length-`ng` vector where entry
# `g` is Σ_{firms i in sector g} intensity_i·Y_i. `model.firms.G_i[i]` is firm i's
# sector index (1..ng), so we just scatter-add each firm's emissions into its
# sector's bucket. Summing this vector reproduces `emissions(model)` exactly. With
# abatement, a split sector's renewable firm keeps the original sector index, so it
# folds back into the same bucket — the breakdown still has `ng` entries.
function emissions_by_sector(model, ng)
    e = zeros(ng)
    @inbounds for i in eachindex(model.firms.Y_i)
        e[model.firms.G_i[i]] += model.firms.carbon_intensity_i[i] * model.firms.Y_i[i]
    end
    return e
end

# Per-sector cross-firm AVERAGES, returned as a `(mean_production, mean_price)`
# pair of length-`ng` vectors: entry `g` averages firm production `Y_i` and firm
# selling price `P_i` over the firms in sector `g` (`firms.G_i == g`). Every sector
# has ≥1 firm so the counts are never zero; with abatement a split sector's fossil
# + renewable firms share the index, so the average spans both. (The model also
# keeps a sales-weighted sector price index `agg.P_bar_g` that folds in import
# prices — use that instead if you want the official producer-price index rather
# than the plain average of domestic firms' selling prices.)
function sector_averages(model, ng)
    sumY = zeros(ng); sumP = zeros(ng); cnt = zeros(Int, ng)
    G_i = model.firms.G_i
    @inbounds for i in eachindex(G_i)
        g = G_i[i]
        sumY[g] += model.firms.Y_i[i]
        sumP[g] += model.firms.P_i[i]
        cnt[g] += 1
    end
    return (sumY ./ cnt, sumP ./ cnt)
end

# Employment BY SECTOR: returns a length-`ng` vector where entry `g` is the total
# number of persons employed across the firms in sector `g`. `model.firms.N_i[i]` is
# firm i's headcount and `model.firms.G_i[i]` its sector index (1..ng), so we just
# scatter-add each firm's headcount into its sector's bucket — exactly mirroring
# `emissions_by_sector`. Summing this vector gives the economy-wide number of
# employed persons. With abatement a split sector's fossil + renewable firms share
# the index, so they fold back into the same bucket.
function employment_by_sector(model, ng)
    n = zeros(ng)
    @inbounds for i in eachindex(model.firms.N_i)
        n[model.firms.G_i[i]] += model.firms.N_i[i]
    end
    return n
end

# Firm PROFITS BY SECTOR: returns a length-`ng` vector where entry `g` is the total
# realised firm profit across the firms in sector `g`. `model.firms.Pi_i[i]` is firm
# i's realised profit this quarter (sales + deposit interest − wages − intermediate
# goods − depreciation − product/capital/carbon taxes − loan interest; see
# `set_firms_profits!`) and `model.firms.G_i[i]` its sector index (1..ng), so we
# scatter-add each firm's profit into its sector's bucket — exactly mirroring
# `employment_by_sector`. Summing this vector gives economy-wide firm profits. With
# abatement a split sector's fossil + renewable firms share the index, so they fold
# back into the same bucket.
function profit_by_sector(model, ng)
    pi = zeros(ng)
    @inbounds for i in eachindex(model.firms.Pi_i)
        pi[model.firms.G_i[i]] += model.firms.Pi_i[i]
    end
    return pi
end

# Firm DEPOSITS BY SECTOR: returns a length-`ng` vector where entry `g` is the total
# bank deposits held by the firms in sector `g`. `model.firms.D_i[i]` is firm i's
# deposit balance (can go negative — an overdraft/loan position) and
# `model.firms.G_i[i]` its sector index (1..ng), so we scatter-add each firm's
# deposits into its sector's bucket — exactly mirroring `profit_by_sector`. Summing
# this vector gives economy-wide firm deposits. With abatement a split sector's
# fossil + renewable firms share the index, so they fold back into the same bucket.
function deposits_by_sector(model, ng)
    d = zeros(ng)
    @inbounds for i in eachindex(model.firms.D_i)
        d[model.firms.G_i[i]] += model.firms.D_i[i]
    end
    return d
end

# Lump-sum carbon dividend recycled to each household this quarter, in euros.
carbon_dividend(model) =
    sum(model.firms.tau_carbon .* model.firms.carbon_intensity_i .* model.firms.Y_i) / model.prop.H

# Unemployment rate over the active workforce: O_h == 0 means unemployed.
unemployment_rate(model) = count(==(0), model.w_act.O_h) / length(model.w_act.O_h)


"""
    simulate(; abatement::Bool, n_sims::Int = 100, carbon_efficiency_annual::Real = 0.0)

Run the base (no-tax) vs carbon-tax Monte-Carlo and return the collected data as a
`NamedTuple`. This is the expensive step — it does NOT plot or print anything.

Hold onto the result and feed its fields to the `plot_*` / `table_*` functions as
often as you like, WITHOUT re-simulating:

    data = simulate(; abatement = false)              # run the model once (slow)
    display(plot_real_gdp(data.gdp_base, data.gdp_carbon))   # cheap, repeat freely
    table_unemployment(data.unemp_base, data.unemp_carbon)

The fields are the `(steps × n_sims)` matrices behind each graph: `infl_*`,
`taxprod_*`, `emis_*`, `gdp_*`, `unemp_*` (each a `_base`/`_carbon` pair),
`lump_carbon`, `ren_share` (a vector, one matrix per split sector), `split`,
`yg_base`/`yg_carbon`, and the bookkeeping `abatement`/`n_sims`/`mode`.

A few extra fields are `(steps × G × n_sims)` per-sector arrays (`G = 62`):
`emis_base_sec` (base-case emissions split by sector — summing over the sector
dimension recovers `emis_base`; feeds `plot_emissions_stacked` /
`table_emissions_stacked`), `prod_*_sec` / `price_*_sec` (each a `_base`/
`_carbon` pair) holding the cross-firm AVERAGE production `Y_i` and selling price
`P_i` per sector, feeding `table_production_sector` / `table_price_sector`, and
`emp_*_sec` (a `_base`/`_carbon` pair) holding the number of persons employed
(`firms.N_i`) per sector — summing over the sector dimension gives total
economy-wide employment.

`abatement = true`  → both runs split every sector in `abatement_sectors` into a
fossil + renewable firm, and the carbon run uses a `CarbonTransition` shock that
ramps the tax AND reallocates capacity from fossil to renewable. Emissions can
fall both by switching technology and by reduced demand.

`abatement = false` → no sector is split. The carbon run uses a plain
`CarbonTaxRamp` (tax only, no cleaner alternative to switch to), so emissions can
fall only through reduced output/demand. This isolates the pure tax effect and is
the cleaner control for judging how much the abatement channel is doing.

`carbon_efficiency_annual` (OPTIONAL robustness knob, default `0.0` = off) sets a
trend decline in every sector's CO₂ intensity, in % per YEAR (applied in quarterly
steps via `Bit.CarbonEfficiency`). Empirically Dutch total emissions fall over time
even as output grows, because industries get cleaner per unit of output; the base
model holds intensities fixed, so set this > 0 (e.g. `0.04` → −4%/year) to steer
the base-case emission path down toward that observed decline. It is applied
identically to BOTH the base and carbon runs, so the carbon-vs-base comparison
still isolates the tax. The main comparison uses `0.0`; this is purely a
robustness check.

Runs `n_sims` Monte-Carlo repetitions. Each repetition `s` uses a distinct RNG
seed, so the model's stochasticity shows up as run-to-run variability. Within a
repetition the base and carbon runs share the SAME seed, so the only difference
between them is the carbon tax itself — the comparison stays clean per run while
the band across runs shows estimation uncertainty. Each `plot_*` shows the cross-run
mean as a line with a 95% confidence-interval ribbon (mean ± 1.96·std/√n).
"""
function simulate(; abatement::Bool, n_sims::Int = 100, carbon_efficiency_annual::Real = 0.0)
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
    # OPTIONAL carbon-efficiency trend (robustness knob). With rate 0.0 this is a
    # no-op; > 0 makes every sector's CO₂ intensity decline by that fraction per
    # year (quarterly steps), steering the base-case emissions down toward the
    # observed Dutch decline. Applied to BOTH runs so the tax comparison stays clean.
    efficiency = Bit.CarbonEfficiency(carbon_efficiency_annual)
    # The trend shocks every run shares (productivity + efficiency); the base run
    # gets exactly these, the carbon run adds the tax on top.
    base_shock! = Bit.CombinedShock(growth, efficiency)

    ramp = Bit.CarbonTaxRamp(
        tau_carbon_0, tau_carbon_increment;
        start_time = tau_carbon_start, final_time = tau_carbon_final_time,
    )
    # With abatement, the transition shock also reallocates capacity toward the
    # renewable firms; without, the tax just ramps. Either way, combine it with the
    # same productivity-growth and efficiency trends used in the base run.
    carbon_shock = abatement ? Bit.CarbonTransition(ramp, split; rate = 0.3, max_step = 0.1) : ramp
    shock! = Bit.CombinedShock(growth, efficiency, carbon_shock)

    # Monte-Carlo storage: one column per repetition, one row per timestep. The
    # hand-tracked series (emissions/unemployment/dividend/renewable share) are
    # length T (one push per simulated step). The built-in `model.data` series are
    # length T+1 (they carry an initial point), so collect those as vectors per
    # repetition and hcat afterwards — their own length is used on the x-axis.
    emis_base = zeros(T, n_sims);    emis_carbon = zeros(T, n_sims)
    emis_base_sec = zeros(T, G, n_sims)  # base-case per-sector emissions, for the stacked graph
    # Per-sector cross-firm averages of production (Y_i) and selling price (P_i),
    # tracked for both runs so the carbon tax's per-sector effect can be compared.
    prod_base_sec = zeros(T, G, n_sims);  prod_carbon_sec = zeros(T, G, n_sims)
    price_base_sec = zeros(T, G, n_sims); price_carbon_sec = zeros(T, G, n_sims)
    # Per-sector employment (number of persons employed), tracked for both runs so
    # the carbon tax's effect on the sectoral distribution of jobs can be compared.
    emp_base_sec = zeros(T, G, n_sims);   emp_carbon_sec = zeros(T, G, n_sims)
    # Per-sector total firm profits (Pi_i), tracked for both runs so the carbon tax's
    # effect on the sectoral distribution of profits can be compared.
    prof_base_sec = zeros(T, G, n_sims);  prof_carbon_sec = zeros(T, G, n_sims)
    # Per-sector total firm deposits (D_i), tracked for both runs so the carbon tax's
    # effect on the sectoral distribution of firm cash balances can be compared.
    dep_base_sec = zeros(T, G, n_sims);   dep_carbon_sec = zeros(T, G, n_sims)
    unemp_base = zeros(T, n_sims);   unemp_carbon = zeros(T, n_sims)
    cpi_base = zeros(T, n_sims);     cpi_carbon = zeros(T, n_sims)  # household CPI = agg.P_bar_HH
    lump_carbon = zeros(T, n_sims)
    ren_share = [zeros(T, n_sims) for _ in split]  # renewable share of each split sector's output
    infl_base_v = Vector{Float64}[];    infl_carbon_v = Vector{Float64}[]
    totinfl_base_v = Vector{Float64}[]; totinfl_carbon_v = Vector{Float64}[]  # domestic total inflation (GDP deflator)
    taxprod_base_v = Vector{Float64}[]; taxprod_carbon_v = Vector{Float64}[]
    gdp_base_v = Vector{Float64}[];     gdp_carbon_v = Vector{Float64}[]
    cons_base_v = Vector{Float64}[];    cons_carbon_v = Vector{Float64}[]
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
            Bit.step!(base; parallel = true, shock! = base_shock!)
            Bit.collect_data!(base)
            emis_base[t, s] = emissions(base)
            emis_base_sec[t, :, s] = emissions_by_sector(base, G)
            prod_base_sec[t, :, s], price_base_sec[t, :, s] = sector_averages(base, G)
            emp_base_sec[t, :, s] = employment_by_sector(base, G)
            prof_base_sec[t, :, s] = profit_by_sector(base, G)
            dep_base_sec[t, :, s] = deposits_by_sector(base, G)
            unemp_base[t, s] = unemployment_rate(base)
            cpi_base[t, s] = base.agg.P_bar_HH
        end
        push!(infl_base_v, copy(base.data.gdp_deflator_growth_ea))
        push!(totinfl_base_v, total_inflation(base))
        push!(taxprod_base_v, copy(base.data.taxes_production))
        push!(gdp_base_v, copy(base.data.real_gdp))
        push!(cons_base_v, copy(base.data.real_household_consumption))
        yg_base[s] = base.gov.Y_G

        # Carbon run: same seed. Construct tax-free — the shock sets `tau_carbon`
        # every step (zero before `tau_carbon_start`), so no carbon slug leaks into
        # the initial data point.
        Random.seed!(s)
        carbon = make_model(0.0)
        # Firm indices per split sector, for the technology-mix panel (abatement only).
        sector_idx = abatement ? [findall(==(sec), carbon.firms.G_i) for sec in split] : Vector{Int}[]
        for t in 1:T
            Bit.step!(carbon; parallel = true, shock! = shock!)
            Bit.collect_data!(carbon)
            emis_carbon[t, s] = emissions(carbon)
            prod_carbon_sec[t, :, s], price_carbon_sec[t, :, s] = sector_averages(carbon, G)
            emp_carbon_sec[t, :, s] = employment_by_sector(carbon, G)
            prof_carbon_sec[t, :, s] = profit_by_sector(carbon, G)
            dep_carbon_sec[t, :, s] = deposits_by_sector(carbon, G)
            unemp_carbon[t, s] = unemployment_rate(carbon)
            cpi_carbon[t, s] = carbon.agg.P_bar_HH
            lump_carbon[t, s] = carbon_dividend(carbon)
            for (k, idx) in enumerate(sector_idx)
                yr = carbon.firms.Y_i[idx[end]]
                ren_share[k][t, s] = yr / sum(@view carbon.firms.Y_i[idx])
            end
        end
        push!(infl_carbon_v, copy(carbon.data.gdp_deflator_growth_ea))
        push!(totinfl_carbon_v, total_inflation(carbon))
        push!(taxprod_carbon_v, copy(carbon.data.taxes_production))
        push!(gdp_carbon_v, copy(carbon.data.real_gdp))
        push!(cons_carbon_v, copy(carbon.data.real_household_consumption))
        yg_carbon[s] = carbon.gov.Y_G
    end
    println("\rRun $n_sims/$n_sims — done.")

    # Assemble the built-in series into (Td × n_sims) matrices (Td = T+1).
    infl_base = reduce(hcat, infl_base_v);       infl_carbon = reduce(hcat, infl_carbon_v)
    totinfl_base = reduce(hcat, totinfl_base_v); totinfl_carbon = reduce(hcat, totinfl_carbon_v)
    taxprod_base = reduce(hcat, taxprod_base_v); taxprod_carbon = reduce(hcat, taxprod_carbon_v)
    gdp_base = reduce(hcat, gdp_base_v);         gdp_carbon = reduce(hcat, gdp_carbon_v)
    cons_base = reduce(hcat, cons_base_v);       cons_carbon = reduce(hcat, cons_carbon_v)

    mode = abatement ? "WITH abatement" : "WITHOUT abatement"

    # Everything a `plot_*` / `table_*` needs, so callers can re-render without
    # re-simulating. Extra fields are harmless — destructure only what you use.
    return (;
        abatement, n_sims, mode, split, sector_labels,
        infl_base, infl_carbon,
        totinfl_base, totinfl_carbon,
        taxprod_base, taxprod_carbon,
        emis_base, emis_carbon, emis_base_sec,
        prod_base_sec, prod_carbon_sec, price_base_sec, price_carbon_sec,
        emp_base_sec, emp_carbon_sec,
        prof_base_sec, prof_carbon_sec,
        dep_base_sec, dep_carbon_sec,
        gdp_base, gdp_carbon,
        cons_base, cons_carbon,
        unemp_base, unemp_carbon,
        cpi_base, cpi_carbon,
        lump_carbon, ren_share,
        yg_base, yg_carbon,
    )
end

"""
    run_comparison(; abatement::Bool, n_sims::Int = 100, show_tables::Bool = false,
                   carbon_efficiency_annual::Real = 0.0)

Convenience wrapper around [`simulate`](@ref): run the model, assemble the combined
plot, optionally print the tables, and return the plot (so `display(...)` works).

Pass `show_tables = true` to also print, for every series, a table of its cross-run
mean against time (the numbers behind the graphs) to the console.

Pass `carbon_efficiency_annual > 0` to enable the optional carbon-efficiency trend
(see [`simulate`](@ref)) — a robustness check that bends the base-case emissions
path down toward the observed Dutch decline. Defaults to `0.0` (off).

To explore different graphs/tables WITHOUT re-running the model, call `simulate`
yourself once and reuse its returned data — see the `simulate` docstring.
"""
function run_comparison(;
        abatement::Bool, n_sims::Int = 100, show_tables::Bool = false,
        carbon_efficiency_annual::Real = 0.0,
    )
    data = simulate(; abatement, n_sims, carbon_efficiency_annual)
    (;
        infl_base, infl_carbon, totinfl_base, totinfl_carbon, taxprod_base, taxprod_carbon,
        emis_base, emis_carbon, emis_base_sec,
        prod_base_sec, prod_carbon_sec, price_base_sec, price_carbon_sec,
        emp_carbon_sec, prof_carbon_sec, dep_base_sec, dep_carbon_sec,
        gdp_base, gdp_carbon,
        cons_base, cons_carbon,
        unemp_base, unemp_carbon, cpi_base, cpi_carbon, lump_carbon, ren_share,
        split, mode, yg_base, yg_carbon,
    ) = data

    # --- Graphs ----------------------------------------------------------------
    # Each entry calls one plotting function from `carbon_plots/` (one file per
    # graph). Comment a line out to hide that graph; uncomment one to show it. The
    # base-case-only quarterly graphs are commented out by default.
    panels = [
        # plot_inflation(infl_base, infl_carbon),  # EA (euro-area) inflation — exogenous process
        # plot_total_inflation(totinfl_base, totinfl_carbon),  # domestic total inflation (GDP deflator)
        # plot_taxes_production(taxprod_base, taxprod_carbon),
        # plot_emissions(emis_base, emis_carbon),
        # plot_emissions_diff(emis_base, emis_carbon),  # carbon emissions as % vs base
        # plot_emissions_stacked(emis_base_sec, sector_labels),  # base-case total, stacked by sector
        # plot_production_sector(prod_base_sec, prod_carbon_sec, sector_labels),  # avg output/sector, base vs carbon
        # plot_price_sector(price_base_sec, price_carbon_sec, sector_labels),     # avg price/sector, base vs carbon
        # plot_price_polluters(price_carbon_sec, emis_base_sec),  # carbon price: top-8 polluters vs rest (grouped)
        # plot_production_polluters(prod_carbon_sec, emis_base_sec),  # carbon production, indexed: top-8 polluters vs rest
        # plot_employment_polluters(emp_carbon_sec, emis_base_sec),  # carbon employment, indexed: top-8 polluters vs rest
        # plot_profit_polluters(prof_carbon_sec, emis_base_sec),  # carbon firm profits, indexed: top-8 polluters vs rest
        # plot_deposits_polluters(dep_carbon_sec, emis_base_sec),  # carbon firm deposits (€): top-8 polluters vs rest
        # plot_deposits_polluters_base(dep_base_sec, emis_base_sec),  # base firm deposits (€): top-8 polluters vs rest

        # plot_real_gdp(gdp_base, gdp_carbon),
        # plot_real_gdp_diff(gdp_base, gdp_carbon),  # real GDP as % vs base
        # plot_consumption(cons_base, cons_carbon),  # real consumer spending: base vs carbon
        # plot_consumption_diff(cons_base, cons_carbon),  # real consumer spending as % vs base
        # plot_unemployment(unemp_base, unemp_carbon),
        # plot_unemployment_diff(unemp_base, unemp_carbon),  # unemployment rate as pp vs base
        # plot_cpi(cpi_base, cpi_carbon),  # household CPI (P_bar_HH): base vs carbon
        # plot_cpi_diff(cpi_base, cpi_carbon),  # household CPI as % vs base
        # plot_carbon_dividend(lump_carbon),
        # plot_dividend_vs_consumption(lump_carbon, cons_base, cons_carbon),  # rebate (€) vs real-consumption uplift (%)
        # plot_gdp_growth_quarterly_sourced(gdp_base),  # base case + overlaid "Sourced data" line
        # plot_gdp_growth_quarterly(gdp_base),       # base case only
        # plot_unemployment_quarterly(unemp_base),   # base case only
        # plot_unemployment_quarterly_sourced(unemp_base),  # base case + overlaid "Sourced data" line
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
        table_total_inflation(totinfl_base, totinfl_carbon)
        table_taxes_production(taxprod_base, taxprod_carbon)
        table_emissions(emis_base, emis_carbon)
        table_emissions_diff(emis_base, emis_carbon)
        table_emissions_stacked(emis_base_sec, sector_labels)  # which sectors emit the most
        table_production_sector(prod_base_sec, prod_carbon_sec, sector_labels)  # avg output/sector, base vs carbon
        table_price_sector(price_base_sec, price_carbon_sec, sector_labels)     # avg price/sector, base vs carbon
        table_price_polluters(price_carbon_sec, emis_base_sec, sector_labels)   # carbon price: top-8 polluters vs rest (grouped)
        table_production_polluters(prod_carbon_sec, emis_base_sec, sector_labels)  # carbon production, indexed: polluters vs rest
        table_employment_polluters(emp_carbon_sec, emis_base_sec, sector_labels)   # carbon employment, indexed: polluters vs rest
        table_profit_polluters(prof_carbon_sec, emis_base_sec, sector_labels)      # carbon firm profits, indexed: polluters vs rest
        table_deposits_polluters(dep_carbon_sec, emis_base_sec, sector_labels)     # carbon firm deposits (€): polluters vs rest
        table_deposits_polluters_base(dep_base_sec, emis_base_sec, sector_labels)  # base firm deposits (€): polluters vs rest
        table_real_gdp(gdp_base, gdp_carbon)
        table_real_gdp_diff(gdp_base, gdp_carbon)  # real GDP as % vs base
        table_consumption(cons_base, cons_carbon)  # real consumer spending: base vs carbon
        table_consumption_diff(cons_base, cons_carbon)  # real consumer spending as % vs base
        table_unemployment(unemp_base, unemp_carbon)
        table_unemployment_diff(unemp_base, unemp_carbon)  # unemployment rate as pp vs base
        table_cpi(cpi_base, cpi_carbon)  # household CPI (P_bar_HH): base vs carbon
        table_cpi_diff(cpi_base, cpi_carbon)  # household CPI as % vs base
        table_carbon_dividend(lump_carbon)
        table_dividend_vs_consumption(lump_carbon, cons_base, cons_carbon)  # rebate (€) vs real-consumption uplift (%)
        # table_gdp_growth_quarterly(gdp_base)        # base case only
        # table_unemployment_quarterly(unemp_base)    # base case only
        abatement && table_renewable_share(ren_share, split)
    end

    n = length(panels)
    rows = cld(n, 2)
    return plot(panels...; layout = (rows, 2), size = (900, 300 + 250 * rows), plot_title = mode)
end
