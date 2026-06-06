# Quarterly unemployment rate (%), BASE case only. `unemp_base` is (T × n_sims),
# already one row per simulated quarter (2024Q1..2028Q4), so no transform is
# needed beyond scaling the share to a percentage.
function plot_unemployment_quarterly(unemp_base)
    T = size(unemp_base, 1)
    m, s = confidence_band(unemp_base)
    return plot(
        1:T, 100 .* m; ribbon = 100 .* s, fillalpha = 0.2, label = "base (no tax)",
        title = "unemployment rate per quarter", xlabel = "quarter", ylabel = "%",
        xticks = quarter_xticks(T), xrotation = 45,
    )
end

# Same data as a mean-vs-time table (base case only), expressed as a percentage.
table_unemployment_quarterly(unemp_base) =
    mean_table("unemployment rate per quarter (%)", "base (no tax)" => 100 .* unemp_base)
