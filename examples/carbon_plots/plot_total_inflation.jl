# Total inflation: base vs carbon run. The model's "total inflation" is the
# period-over-period growth of the GDP deflator (`nominal_gdp / real_gdp`) — the
# economy-wide price change implied by the firm pricing rule. This is the domestic
# inflation the carbon tax actually moves, as opposed to "EA inflation" (an
# exogenous euro-area process, see `plot_inflation`) or the household-only CPI
# (`plot_cpi`). The gap between the two lines is the carbon tax's pass-through into
# aggregate inflation.
#
# `model.data.nominal_gdp` / `real_gdp` carry an initial 2023Q4 point as row 1, so
# the deflator has length T+1 and its growth series has length T, starting at the
# first simulated quarter (2024Q1) → use `start_q0 = 0`.
function total_inflation(model)
    deflator = model.data.nominal_gdp ./ model.data.real_gdp
    return deflator[2:end] ./ deflator[1:(end - 1)] .- 1
end

# `ti_base`/`ti_carbon` are (steps × n_sims) matrices of total inflation.
plot_total_inflation(ti_base, ti_carbon) = compare_panel(
    ti_base, ti_carbon;
    start_q0 = 0,  # deflator growth starts at the first simulated quarter (2024Q1)
    title = "total inflation (GDP deflator)", ylabel = "inflation (q/q)",
)

# Same data as a mean-vs-time table.
table_total_inflation(ti_base, ti_carbon) =
    mean_table("total inflation (GDP deflator)", "base (no tax)" => ti_base, "carbon" => ti_carbon)
