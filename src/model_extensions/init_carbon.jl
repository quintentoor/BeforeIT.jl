"""
--------- Carbon-tax model extension ---------

`ModelCarbon` extends the base `Bit.Model` with a per-sector carbon tax that
firms pass through into their prices.

Two channels run simultaneously, mirroring the way `tau_K` (taxes on production)
already works in the base model:

1. Price channel  — a `carbon_costs` term enters `cost_push_inflation`, so firms
   in dirty sectors raise prices.
2. Tax-flow channel — firms pay `tau_carbon * carbon_intensity_i * Y_i` from
   their deposits and the government collects exactly the same amount as
   revenue, so the closed-loop accounting invariants are preserved.

The carbon tax is also routed through `operating_surplus` and `taxes_production`
in the data tracker so the GVA identity
   `nominal_gva == compensation_employees + operating_surplus + taxes_production`
continues to hold.

Revenue recycling
-----------------
The carbon-tax revenue collected by the government is recycled back to households
as an equal lump-sum dividend (every household — workers, unemployed, inactive,
firm owners and the bank owner — gets the same per-capita share). The dividend is
paid through the model's existing universal transfer `sb_other`, so it
automatically feeds household consumption/investment demand, realized income, and
the government budget. The (uniform, real) per-household top-up applied this
quarter is stored in `gov.sb_carbon` for tracking and to keep the baseline
`sb_other` from compounding (see `set_gov_social_benefits!` below). Because the
dividend equals the revenue and is paid the same quarter, the recycling is
budget-neutral and all accounting identities are preserved.
"""

# Carbon-aware firms carry a per-firm CO2-intensity and the (uniform) tax rate.
abstract type AbstractFirmsCarbon <: Bit.AbstractFirms end
Bit.@object mutable struct FirmsCarbon(Firms) <: AbstractFirmsCarbon
    carbon_intensity_i::Vector{Bit.typeFloat} # tCO₂ per unit of real output Y_i
    tau_carbon::Bit.typeFloat # euros tax per tCO₂
end

# Carbon-aware government carries the per-household carbon dividend recycled this
# quarter (real, i.e. the top-up added to `sb_other` before scaling by P_bar_HH).
abstract type AbstractGovernmentCarbon <: Bit.AbstractGovernment end
Bit.@object mutable struct GovernmentCarbon(Government) <: AbstractGovernmentCarbon
    sb_carbon::Bit.typeFloat # real per-household carbon dividend recycled this quarter
end

Bit.@object mutable struct ModelCarbon(Bit.Model) <: Bit.AbstractModel end


"""
    CarbonTaxRamp(tau_carbon_0, increment; start_time = 1, final_time = typemax(Int))

Linear carbon-tax escalator, applied as a `step!` shock. At quarter
`t = model.agg.t` the rate is set to

    tau_carbon = 0                                          if t < start_time
    tau_carbon = tau_carbon_0 + increment * (t - start_time) otherwise

so the tax is switched off until `start_time`, charges `tau_carbon_0` in the
`start_time` quarter, and adds `increment` every quarter after that. Once
`t > final_time` the rate is held flat at its `final_time` value (a plateau, not
an end date — the tax is still charged). Use `final_time ≥ start_time`.

The shock is invoked at the top of `step!` (before firms set prices and
decisions), so the updated rate feeds that quarter's cost-push pricing and all
downstream tax-flow/accounting reads consistently. Mirrors the `agg.t`-driven
pattern of `InterestRateShock`/`ConsumptionShock`.
"""
struct CarbonTaxRamp <: Bit.AbstractShock
    tau_carbon_0::Bit.typeFloat
    increment::Bit.typeFloat
    start_time::Int
    final_time::Int
end
CarbonTaxRamp(tau_carbon_0, increment; start_time = 1, final_time = typemax(Int)) =
    CarbonTaxRamp(Bit.typeFloat(tau_carbon_0), Bit.typeFloat(increment), start_time, final_time)

function (s::CarbonTaxRamp)(model::ModelCarbon)
    t = model.agg.t
    if t < s.start_time
        model.firms.tau_carbon = zero(Bit.typeFloat)
    else
        q = min(t, s.final_time)
        model.firms.tau_carbon = s.tau_carbon_0 + s.increment * (q - s.start_time)
    end
    return nothing
end


"""
    reallocate_green_capacity!(model, sector, rate, max_step)

Capacity-reallocation channel (fix B) for a split sector. This supplies the
"build new capacity where it is cheapest" behaviour the base investment rule
lacks (`I_d = (δ/κ)·min(Q_s, K·κ)` only ever *maintains* current capacity — a
fully-utilised firm can never expand past its ceiling, so a price signal alone
cannot move a capacity-capped sector's technology mix).

Within `sector`, the cleanest firm (lowest `carbon_intensity_i`) is the sink.
For every dirtier firm `f` we move a fraction `φ_f = clamp(rate · gap_f, 0, max_step)`
of *both* its capital `K_i` and its realised-demand signal `Q_d_i` to the clean
firm, where `gap_f = (P_f − P_clean) / P_clean ≥ 0` is the dirty firm's relative
price disadvantage (which the carbon tax creates and widens over time).

Moving capital **and** demand together is essential: capital alone would sit idle
(the clean firm's censored `Q_d_i` keeps its labour/output target small), and
demand alone would hit the clean firm's capacity ceiling. Moved together, the
clean firm scales up consistently — it hires the workers the shrinking fossil
firm sheds, invests into its larger demand, and raises output — while sector
totals (capital and demand) are conserved, matching a near-frozen-capacity
economy where the transition must be a *reallocation*, not net growth.

Runs at the top of `step!` (before firm decisions), so the moved `K_i`/`Q_d_i`
feed this quarter's expectations, employment, investment and production. With no
tax (prices equal ⇒ `gap ≤ 0`) it is a no-op, preserving the baseline.
"""
function reallocate_green_capacity!(model::ModelCarbon, sector::Int, rate::Bit.typeFloat, max_step::Bit.typeFloat)
    firms = model.firms
    idx = findall(==(sector), firms.G_i)
    length(idx) < 2 && return model

    # cleanest firm in the sector is the sink for reallocated capacity/demand
    c = idx[argmin(@view firms.carbon_intensity_i[idx])]
    P_clean = firms.P_i[c]
    P_clean > 0 || return model

    for f in idx
        f == c && continue
        gap = (firms.P_i[f] - P_clean) / P_clean
        gap <= 0 && continue
        phi = clamp(rate * gap, zero(Bit.typeFloat), max_step)
        dK = phi * firms.K_i[f]
        dQ = phi * firms.Q_d_i[f]
        firms.K_i[f] -= dK; firms.K_i[c] += dK
        firms.Q_d_i[f] -= dQ; firms.Q_d_i[c] += dQ
    end
    return model
end


"""
    CarbonTransition(ramp, sector; rate = 0.3, max_step = 0.1)

A composite `step!` shock that drives an energy-transition scenario: it applies
the `CarbonTaxRamp` `ramp` (setting `tau_carbon` for the quarter) and then runs
`reallocate_green_capacity!` on `sector`, shifting capital and demand from the
fossil firm to the renewable firm at a pace set by the tax-driven price gap.

- `rate`: reallocation speed — fraction of a dirty firm's capital/demand moved
  per unit of relative price gap, per quarter.
- `max_step`: per-quarter cap on the moved fraction (numerical safety).

Use with a sector-split `ModelCarbon` (see the `split_sector` constructor arg).
"""
struct CarbonTransition <: Bit.AbstractShock
    ramp::CarbonTaxRamp
    sector::Int
    rate::Bit.typeFloat
    max_step::Bit.typeFloat
end
CarbonTransition(ramp::CarbonTaxRamp, sector::Integer; rate::Real = 0.3, max_step::Real = 0.1) =
    CarbonTransition(ramp, Int(sector), Bit.typeFloat(rate), Bit.typeFloat(max_step))

function (s::CarbonTransition)(model::ModelCarbon)
    s.ramp(model)
    reallocate_green_capacity!(model, s.sector, s.rate, s.max_step)
    return nothing
end


# 1. Price channel: extend cost-push inflation with a carbon term.
function Bit.cost_push_inflation(firms::FirmsCarbon, model::ModelCarbon)
    P_bar_HH, P_bar_CF, P_bar_g = model.agg.P_bar_HH, model.agg.P_bar_CF, model.agg.P_bar_g
    tau_SIF, a_sg = model.prop.tau_SIF, model.prop.a_sg

    term = vec(sum(a_sg[:, firms.G_i] .* P_bar_g, dims = 1))

    labour_costs = (1 + tau_SIF) .* firms.w_bar_i ./ firms.alpha_bar_i .* (P_bar_HH ./ firms.P_i .- 1)
    material_costs = 1 ./ firms.beta_i .* (term ./ firms.P_i .- 1)
    capital_costs = firms.delta_i ./ firms.kappa_i .* (P_bar_CF ./ firms.P_i .- 1)
    carbon_costs = firms.tau_carbon .* firms.carbon_intensity_i ./ firms.P_i

    return labour_costs .+ material_costs .+ capital_costs .+ carbon_costs
end


# 2. Tax-flow channel — profits side. Subtract the carbon tax from firm profits.
function Bit.firms_profits(model::ModelCarbon)
    firms = model.firms

    P_bar_HH, tau_SIF, r, r_bar = model.agg.P_bar_HH, model.prop.tau_SIF, model.bank.r, model.cb.r_bar

    in_sales = firms.P_i .* firms.Q_i .+ firms.P_i .* firms.DS_i
    in_deposits = r_bar .* Bit.pos(firms.D_i)
    out_wages = (1.0 + tau_SIF) .* firms.w_i .* firms.N_i .* P_bar_HH
    out_expenses = 1.0 ./ firms.beta_i .* firms.P_bar_i .* firms.Y_i
    out_depreciation = firms.delta_i ./ firms.kappa_i .* firms.P_CF_i .* firms.Y_i
    out_taxes_prods = firms.tau_Y_i .* firms.P_i .* firms.Y_i
    out_taxes_capital = firms.tau_K_i .* firms.P_i .* firms.Y_i
    out_taxes_carbon = firms.tau_carbon .* firms.carbon_intensity_i .* firms.Y_i
    out_loans = r .* (firms.L_i .+ Bit.pos(-firms.D_i))

    Pi_i =
        in_sales + in_deposits - out_wages - out_expenses - out_depreciation - out_taxes_prods -
        out_taxes_capital - out_taxes_carbon - out_loans

    return Pi_i
end


# 2. Tax-flow channel — deposits side. Drain the same amount from firm cash.
function Bit.firms_deposits(model::ModelCarbon)
    firms = model.firms

    tau_FIRM, tau_SIF, theta_DIV = model.prop.tau_FIRM, model.prop.tau_SIF, model.prop.theta_DIV
    theta, r, r_bar, P_bar_HH = model.prop.theta, model.bank.r, model.cb.r_bar, model.agg.P_bar_HH

    sales = firms.P_i .* firms.Q_i
    labour_cost = -(1 + tau_SIF) * firms.w_i .* firms.N_i * P_bar_HH
    material_cost = -firms.DM_i .* firms.P_bar_i
    taxes_products = -firms.tau_Y_i .* firms.P_i .* firms.Y_i
    taxes_production = -firms.tau_K_i .* firms.P_i .* firms.Y_i
    taxes_carbon = -firms.tau_carbon .* firms.carbon_intensity_i .* firms.Y_i
    corporate_tax = -tau_FIRM .* Bit.pos.(firms.Pi_i)
    dividend_payments = -theta_DIV .* (1 - tau_FIRM) .* Bit.pos.(firms.Pi_i)
    interest_payments = -r .* (firms.L_i .+ Bit.pos.(-firms.D_i))
    interest_received = r_bar .* Bit.pos.(firms.D_i)
    investment_cost = -firms.P_CF_i .* firms.I_i
    new_credit = firms.DL_i
    debt_installment = -theta .* firms.L_i

    DD_i =
        sales + labour_cost + material_cost + taxes_products + taxes_production + taxes_carbon +
        corporate_tax + dividend_payments + interest_payments + interest_received +
        investment_cost + new_credit + debt_installment

    return firms.D_i .+ DD_i
end


# 2. Tax-flow channel — government side. Government revenue grows by the same amount.
function Bit.gov_revenues(model::ModelCarbon)
    Y_G_base = @invoke Bit.gov_revenues(model::Bit.AbstractModel)
    firms = model.firms
    carbon = sum(firms.tau_carbon .* firms.carbon_intensity_i .* firms.Y_i)
    return Y_G_base + carbon
end


# Revenue-recycling channel — pay the carbon revenue back as an equal lump-sum
# dividend through the universal transfer `sb_other`. This is the only behavioural
# seam needed: every household income function and the government budget already
# read `gov.sb_other`, so the dividend reaches demand, realized income and
# `gov_loans` automatically and budget-neutrally.
#
# `tau_carbon` (set by the shock) and `Y_i` (set by production) are both fixed
# before this runs in `step!`, so the dividend computed here equals the revenue
# collected later by `gov_revenues` in the same quarter.
#
# We store the exact real top-up in `gov.sb_carbon` and subtract it back out
# before the base method grows the baseline, so the dividend never compounds into
# next quarter's `sb_other`.
function Bit.set_gov_social_benefits!(model::ModelCarbon)
    gov = model.gov
    gov.sb_other -= gov.sb_carbon # de-compound the previous quarter's dividend
    @invoke Bit.set_gov_social_benefits!(model::Bit.AbstractModel) # grow clean baseline
    firms = model.firms
    carbon = sum(firms.tau_carbon .* firms.carbon_intensity_i .* firms.Y_i)
    gov.sb_carbon = carbon / model.prop.H / model.agg.P_bar_HH # real, per household
    gov.sb_other += gov.sb_carbon
    return model
end


# Data tracker overrides — keep the GVA identity intact by routing the carbon
# tax through both `operating_surplus` (firm pays) and `taxes_production`
# (government collects), exactly as `tau_K` is already routed.
function Bit.update_data_init!(m::ModelCarbon)
    @invoke Bit.update_data_init!(m::Bit.AbstractModel)
    firms = m.firms
    carbon = sum(firms.tau_carbon .* firms.carbon_intensity_i .* firms.Y_i)
    m.data.operating_surplus[1] -= carbon
    m.data.taxes_production[1] += carbon
    return m
end

function Bit.update_data_step!(m::ModelCarbon)
    @invoke Bit.update_data_step!(m::Bit.AbstractModel)
    t = length(m.data.collection_time)
    firms = m.firms
    carbon = sum(firms.tau_carbon .* firms.carbon_intensity_i .* firms.Y_i)
    m.data.operating_surplus[t] -= carbon
    m.data.taxes_production[t] += carbon
    return m
end


"""
    ModelCarbon(parameters, initial_conditions; tau_carbon, carbon_intensity_s,
                split_sector, renewable_share, renewable_intensity)

Initialise a carbon-tax model variant.

Keyword arguments:
- `tau_carbon`: tax rate (money per unit CO2). Defaults to 0.05.
- `carbon_intensity_s`: per-sector CO2 emitted per unit of real output `Y_i`,
   length `G`. Defaults to a vector of ones (every sector taxed identically). Replace
   this with real per-sector emissions intensities when available.

Dirty/clean split (Option A — within-sector firm heterogeneity)
---------------------------------------------------------------
- `split_sector`: a sector index (e.g. the electricity sector) to split into a
  *fossil* firm and a *renewable* firm. `nothing` (default) disables the split
  and reproduces the plain carbon model exactly.
- `renewable_share`: the fraction of that sector's initial size (output, capital,
  employment, …) assigned to the clean firm. The remaining `1 - renewable_share`
  goes to the fossil firm.
- `renewable_intensity`: CO₂ intensity of the clean firm (defaults to 0).

When a sector is split, an extra firm is added to the economy (so one active
worker becomes its owner — `I_s[split_sector]` is bumped by 1 and every
sub-object is rebuilt consistently). The two firms together reproduce the
sector's calibrated aggregates, and the fossil firm's intensity is scaled to
`carbon_intensity_s[split_sector] / (1 - renewable_share)` so that *initial*
total emissions are unchanged. The split is meaningful only with a price signal:
the carbon tax raises the fossil firm's price via `cost_push_inflation`, and the
existing price-weighted matching then shifts both intermediate (firm) and final
(household) demand toward the cheaper renewable firm.

With `tau_carbon == 0` and `split_sector === nothing` the model is observationally
equivalent to the base `Bit.Model` (regression test guard).
"""
function ModelCarbon(
        parameters::Dict{String, Any},
        initial_conditions::Dict{String, Any};
        tau_carbon::Real = 0.05,
        carbon_intensity_s::AbstractVector{<:Real} = ones(Bit.typeFloat, Int(parameters["G"])),
        split_sector::Union{Nothing, Integer} = nothing,
        renewable_share::Real = 0.0,
        renewable_intensity::Real = 0.0,
    )
    p, ic = parameters, initial_conditions

    G = Int(p["G"])
    length(carbon_intensity_s) == G ||
        error("carbon_intensity_s must have length G = $G, got $(length(carbon_intensity_s))")

    # When splitting a sector, add one firm to it and rebuild every sub-object
    # from the *same* modified parameters so that firm count, the active
    # workforce (`H_W = H_act - I - 1`) and the owner-household accounting all
    # stay consistent. `p` is a shallow copy with a fresh `I_s`, so the caller's
    # dict is never mutated.
    if split_sector !== nothing
        1 <= split_sector <= G || error("split_sector must be in 1:G = 1:$G")
        0 < renewable_share < 1 || error("renewable_share must be in (0, 1)")
        p = copy(parameters)
        I_s_new = Vector{Int}(vec(parameters["I_s"]))
        I_s_new[split_sector] += 1
        p["I_s"] = I_s_new
    end

    # Carbon-aware firms: map per-sector intensity onto each firm via G_i.
    firms_st = Bit.Firms(p, ic)
    carbon_intensity_i = Vector{Bit.typeFloat}(carbon_intensity_s[firms_st.G_i])
    firms = FirmsCarbon(Bit.fields(firms_st)..., carbon_intensity_i, Bit.typeFloat(tau_carbon))

    # Re-apportion the two firms of the split sector into fossil + renewable and
    # set their per-firm intensities. Done before model assembly so the
    # worker→firm assignment (which reads `V_i`) sees the apportioned sizes.
    if split_sector !== nothing
        split_sector_into_fossil_renewable!(
            firms, Int(split_sector), Bit.typeFloat(renewable_share),
            Bit.typeFloat(carbon_intensity_s[split_sector]), Bit.typeFloat(renewable_intensity), p, ic,
        )
    end

    # Standard initialisations for everything else.
    workers_act, workers_inact = Bit.Workers(p, ic)
    bank = Bit.Bank(p, ic)
    central_bank = Bit.CentralBank(p, ic)
    rotw = Bit.RestOfTheWorld(p, ic)
    agg = Bit.Aggregates(p, ic)
    government = GovernmentCarbon(Bit.fields(Bit.Government(p, ic))..., zero(Bit.typeFloat))
    properties = Bit.Properties(p, ic)
    data = Bit.Data()

    return ModelCarbon(
        (
            workers_act, workers_inact, firms, bank, central_bank, government, rotw, agg, properties, data,
        )
    )
end


"""
    split_sector_into_fossil_renewable!(firms, sector, renewable_share,
                                        sector_intensity, renewable_intensity, p, ic)

Turn the two firms the constructor created in `sector` into a fossil firm
(index `idx[1]`) and a renewable firm (index `idx[2]`), re-apportioning their
calibrated state so the pair reproduces the sector total and the renewable firm
holds `renewable_share` of it. The fossil intensity is scaled so that initial
total emissions are unchanged; the renewable firm gets `renewable_intensity`.

All extensive (size-proportional) fields are split by the *realised* employment
share `N_renew / N_total`, which keeps `Y_i = α·N_i` exactly consistent. Intensive
sector-level fields (`alpha_bar_i`, `beta_i`, …) are already identical for both
firms and are left untouched. Owner-household income/wealth (`Y_h`, `K_h`, `D_h`)
is recomputed per firm exactly as in `Bit.Firms`.
"""
function split_sector_into_fossil_renewable!(
        firms::FirmsCarbon, sector::Int, renewable_share::Bit.typeFloat,
        sector_intensity::Bit.typeFloat, renewable_intensity::Bit.typeFloat, p, ic,
    )
    idx = findall(==(sector), firms.G_i)
    length(idx) == 2 ||
        error("expected exactly 2 firms in split sector $sector, found $(length(idx))")
    ff, fr = idx[1], idx[2]   # fossil, renewable

    # Split integer employment first; clamp so each firm keeps at least 1 worker.
    N_tot = firms.N_i[ff] + firms.N_i[fr]
    N_tot >= 2 || error("split sector $sector has too little employment ($N_tot) to split")
    N_fr = clamp(round(Bit.typeInt, renewable_share * N_tot), 1, N_tot - 1)
    N_ff = N_tot - N_fr
    firms.N_i[fr] = N_fr; firms.N_i[ff] = N_ff
    firms.V_i[fr] = N_fr; firms.V_i[ff] = N_ff

    # Apportion every continuous extensive field by the realised employment share
    # `sr`, so Y_i = α·N_i stays exact (Y_tot = α·N_tot ⇒ sr·Y_tot = α·N_fr).
    sr = N_fr / N_tot
    for field in (:Y_i, :Q_d_i, :K_i, :M_i, :L_i, :D_i, :S_i)
        v = getfield(firms, field)
        tot = v[ff] + v[fr]
        v[fr] = sr * tot
        v[ff] = tot - v[fr]
    end

    # Recompute profits and owner-household income/wealth per firm, exactly as
    # `Bit.Firms` does, from the apportioned state.
    r = ic["r_bar"] + p["mu"]
    r_bar = ic["r_bar"]
    P_bar_HH = one(Bit.typeFloat)
    for f in (ff, fr)
        firms.Pi_i[f] = firms.pi_bar_i[f] * firms.Y_i[f] - r * firms.L_i[f] + r_bar * max(0, firms.D_i[f])
        firms.Y_h[f] = p["theta_DIV"] * (1 - p["tau_INC"]) * (1 - p["tau_FIRM"]) * max(0, firms.Pi_i[f]) +
            ic["sb_other"] * P_bar_HH
        firms.K_h[f] = ic["K_H"] * firms.Y_h[f]
        firms.D_h[f] = ic["D_H"] * firms.Y_h[f]
    end

    # Per-firm carbon intensities: fossil carries all the sector's emissions
    # (scaled so initial totals are preserved), renewable is (near) clean.
    firms.carbon_intensity_i[ff] = sector_intensity / (1 - renewable_share)
    firms.carbon_intensity_i[fr] = renewable_intensity
    return firms
end
