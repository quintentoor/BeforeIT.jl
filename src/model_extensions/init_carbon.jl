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
"""

# Carbon-aware firms carry a per-firm CO2-intensity and the (uniform) tax rate.
abstract type AbstractFirmsCarbon <: Bit.AbstractFirms end
Bit.@object mutable struct FirmsCarbon(Firms) <: AbstractFirmsCarbon
    carbon_intensity_i::Vector{Bit.typeFloat} # carbon output per Y_i (euros of production)
    tau_carbon::Bit.typeFloat # tax per carbon output
end

Bit.@object mutable struct ModelCarbon(Bit.Model) <: Bit.AbstractModel end


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
    ModelCarbon(parameters, initial_conditions; tau_carbon, carbon_intensity_s)

Initialise a carbon-tax model variant.

Keyword arguments:
- `tau_carbon`: tax rate (money per unit CO2). Defaults to 0.05.
- `carbon_intensity_s`: per-sector CO2 emitted per unit of real output, length `G`.
   Defaults to a vector of ones (every sector taxed identically). Replace this
   with real per-sector emissions intensities when available.

With `tau_carbon == 0` the model is observationally equivalent to the base
`Bit.Model` (regression test guard).
"""
function ModelCarbon(
        parameters::Dict{String, Any},
        initial_conditions::Dict{String, Any};
        tau_carbon::Real = 0.05,
        carbon_intensity_s::AbstractVector{<:Real} = ones(Bit.typeFloat, Int(parameters["G"])),
    )
    p, ic = parameters, initial_conditions

    G = Int(p["G"])
    length(carbon_intensity_s) == G ||
        error("carbon_intensity_s must have length G = $G, got $(length(carbon_intensity_s))")

    # Carbon-aware firms: map per-sector intensity onto each firm via G_i.
    firms_st = Bit.Firms(p, ic)
    carbon_intensity_i = Vector{Bit.typeFloat}(carbon_intensity_s[firms_st.G_i])
    firms = FirmsCarbon(Bit.fields(firms_st)..., carbon_intensity_i, Bit.typeFloat(tau_carbon))

    # Standard initialisations for everything else.
    workers_act, workers_inact = Bit.Workers(p, ic)
    bank = Bit.Bank(p, ic)
    central_bank = Bit.CentralBank(p, ic)
    rotw = Bit.RestOfTheWorld(p, ic)
    agg = Bit.Aggregates(p, ic)
    government = Bit.Government(p, ic)
    properties = Bit.Properties(p, ic)
    data = Bit.Data()

    return ModelCarbon(
        (
            workers_act, workers_inact, firms, bank, central_bank, government, rotw, agg, properties, data,
        )
    )
end
