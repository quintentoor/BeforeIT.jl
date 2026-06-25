# Carbon-tax effect on real consumer spending: the carbon run's real household
# consumption expressed as a percentage difference from the base (no-tax) run,
# quarter by quarter. A value of −2% means the tax has lowered consumer spending to
# 2% below the base case in that quarter; 0% means no difference.
#
# `cons_base`/`cons_carbon` are the built-in `real_household_consumption` series
# (T+1 × n_sims): row 1 is the 2023Q4 initial condition, so we drop it to start at
# the first simulated quarter (2024Q1, `start_q0 = 0`), matching the other graphs.
# Base and carbon within a repetition share the same RNG seed, so the paired
# difference isolates the tax effect cleanly. We report the paired ABSOLUTE difference
# per run divided by the cross-run mean base level (the shared `pct_diff_vs`
# convention — ratio-of-means), then show the cross-run mean ± 95% CI ribbon.
consumption_pct_diff(cons_base, cons_carbon) =
    pct_diff_vs(cons_carbon[2:end, :], cons_base[2:end, :])

function plot_consumption_diff(cons_base, cons_carbon)
    d = consumption_pct_diff(cons_base, cons_carbon)
    T = size(d, 1)
    m, s = confidence_band(d)
    p = plot(
        1:T, m; ribbon = s, fillalpha = 0.2, label = "carbon vs base",
        title = "real consumer spending Δ vs base", xlabel = "quarter",
        ylabel = "% vs base (no tax)",
        xticks = quarter_xticks(T), xrotation = 45,
    )
    hline!(p, [0]; linestyle = :dash, color = :gray, label = "")  # base = 0% reference
    return p
end

# Same data as a mean-vs-time table.
table_consumption_diff(cons_base, cons_carbon) =
    mean_table(
        "real consumer spending Δ vs base (% vs base)",
        "carbon vs base" => consumption_pct_diff(cons_base, cons_carbon),
    )
