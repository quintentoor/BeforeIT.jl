# Quarterly unemployment rate (%): base vs carbon run.
#
# `unemp_base`/`unemp_carbon` are (T × n_sims), already one row per simulated
# quarter (2024Q1..2028Q4), so we just scale the share to a percentage and plot
# both runs on the same per-quarter axis used by the other quarterly graphs.
function plot_unemployment(unemp_base, unemp_carbon)
    T = size(unemp_base, 1)
    mb, sb = confidence_band(unemp_base)
    mc, sc = confidence_band(unemp_carbon)
    p = plot(
        1:T, 100 .* mb; ribbon = 100 .* sb, fillalpha = 0.2, label = "base (no tax)",
        title = "unemployment rate per quarter", xlabel = "quarter", ylabel = "%",
        xticks = quarter_xticks(T), xrotation = 45,
    )
    plot!(p, 1:T, 100 .* mc; ribbon = 100 .* sc, fillalpha = 0.2, label = "carbon")
    return p
end

# Same data as a mean-vs-time table (base vs carbon), expressed as a percentage.
table_unemployment(unemp_base, unemp_carbon) =
    mean_table(
        "unemployment rate per quarter (%)",
        "base (no tax)" => 100 .* unemp_base,
        "carbon" => 100 .* unemp_carbon,
    )
