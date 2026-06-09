# Carbon-tax effect on the consumer price level: the carbon run's CPI
# (`agg.P_bar_HH`) expressed as a percentage difference from the base (no-tax) run,
# quarter by quarter. A value of +3% means the tax has pushed the household
# price level 3% above the base case in that quarter; 0% means no difference. This
# isolates the domestic inflation channel of the carbon tax — the price-level gap
# that the exogenous "EA inflation" series cannot show.
#
# `cpi_base`/`cpi_carbon` are (T × n_sims), one row per simulated quarter
# (2024Q1..2028Q4) — hand-tracked, so row 1 is already the first simulated quarter
# (no initial condition to drop, `start_q0 = 0`). Base and carbon within a
# repetition share the same RNG seed, so the per-run ratio `carbon/base − 1`
# isolates the tax effect cleanly; we take that paired difference per run, then show
# the cross-run mean ± 95% CI ribbon (the same band style as the other panels).
cpi_pct_diff(cpi_base, cpi_carbon) = 100 .* (cpi_carbon ./ cpi_base .- 1)

function plot_cpi_diff(cpi_base, cpi_carbon)
    T = size(cpi_base, 1)
    m, s = confidence_band(cpi_pct_diff(cpi_base, cpi_carbon))
    p = plot(
        1:T, m; ribbon = s, fillalpha = 0.2, label = "carbon vs base",
        title = "consumer price index Δ vs base", xlabel = "quarter",
        ylabel = "% vs base (no tax)",
        xticks = quarter_xticks(T), xrotation = 45,
    )
    hline!(p, [0]; linestyle = :dash, color = :gray, label = "")  # base = 0% reference
    return p
end

# Same data as a mean-vs-time table.
table_cpi_diff(cpi_base, cpi_carbon) =
    mean_table(
        "consumer price index Δ vs base (% vs base)",
        "carbon vs base" => cpi_pct_diff(cpi_base, cpi_carbon),
    )
