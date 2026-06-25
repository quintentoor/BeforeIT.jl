# Carbon-tax effect on real GDP: the carbon run's real GDP expressed as a
# percentage difference from the base (no-tax) run, quarter by quarter. A value of
# −2% means the tax has lowered real GDP to 2% below the base case in that quarter;
# 0% means no difference.
#
# `gdp_base`/`gdp_carbon` are the built-in `real_gdp` series (T+1 × n_sims): row 1 is
# the 2023Q4 initial condition, so we drop it to start at the first simulated quarter
# (2024Q1, `start_q0 = 0`), matching the other graphs. Base and carbon within a
# repetition share the same RNG seed, so the per-run ratio `carbon/base − 1` isolates
# the tax effect cleanly. We report the paired ABSOLUTE difference per run divided by
# the cross-run mean base level (the shared `pct_diff_vs` convention — ratio-of-means,
# matching `run_comparison`), then show the cross-run mean ± 95% CI ribbon.
real_gdp_pct_diff(gdp_base, gdp_carbon) =
    pct_diff_vs(gdp_carbon[2:end, :], gdp_base[2:end, :])

function plot_real_gdp_diff(gdp_base, gdp_carbon)
    d = real_gdp_pct_diff(gdp_base, gdp_carbon)
    T = size(d, 1)
    m, s = confidence_band(d)
    p = plot(
        1:T, m; ribbon = s, fillalpha = 0.2, label = "carbon vs base",
        title = "real GDP Δ vs base", xlabel = "quarter",
        ylabel = "% vs base (no tax)",
        xticks = quarter_xticks(T), xrotation = 45,
    )
    hline!(p, [0]; linestyle = :dash, color = :gray, label = "")  # base = 0% reference
    return p
end

# Same data as a mean-vs-time table.
table_real_gdp_diff(gdp_base, gdp_carbon) =
    mean_table(
        "real GDP Δ vs base (% vs base)",
        "carbon vs base" => real_gdp_pct_diff(gdp_base, gdp_carbon),
    )
