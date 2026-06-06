# Quarterly unemployment rate (%), BASE case only — with an overlaid line of
# externally SOURCED unemployment-rate points for comparison.
#
# Identical to `plot_unemployment_quarterly` (same base mean ± 95% CI ribbon,
# same axes/ticks), plus a second "Sourced data" series of hand-entered
# unemployment rates (%), one per quarter 2024Q1..2028Q4. In the source the `*`
# quarters were marked as estimates and the `**` quarters as projected/forecast;
# here they are all plotted the same as the rest. Reuses `confidence_band` and
# `quarter_xticks`, already `include`d into this scope from the sibling
# plot/helper files.
const UNEMPLOYMENT_SOURCED = [
    3.65,  # 2024Q1 *
    3.71,  # 2024Q2 *
    3.70,  # 2024Q3 *
    3.69,  # 2024Q4 *
    3.85,  # 2025Q1 *
    3.82,  # 2025Q2 *
    3.92,  # 2025Q3 *
    4.00,  # 2025Q4 *
    4.05,  # 2026Q1 **
    4.05,  # 2026Q2 **
    4.05,  # 2026Q3 **
    4.05,  # 2026Q4 **
    4.19,  # 2027Q1 **
    4.19,  # 2027Q2 **
    4.19,  # 2027Q3 **
    4.19,  # 2027Q4 **
    4.33,  # 2028Q1 **
    4.33,  # 2028Q2 **
    4.33,  # 2028Q3 **
    4.33,  # 2028Q4 **
]

function plot_unemployment_quarterly_sourced(unemp_base)
    T = size(unemp_base, 1)
    m, s = confidence_band(unemp_base)
    p = plot(
        1:T, 100 .* m; ribbon = 100 .* s, fillalpha = 0.2, label = "base (no tax)",
        title = "unemployment rate per quarter", xlabel = "quarter", ylabel = "%",
        xticks = quarter_xticks(T), xrotation = 45,
    )
    # Overlay the externally sourced unemployment points. `min` guards the length
    # so the series still aligns if `T` ever differs from the 20 quarters above.
    n = min(T, length(UNEMPLOYMENT_SOURCED))
    plot!(p, 1:n, UNEMPLOYMENT_SOURCED[1:n]; label = "Sourced data", marker = :circle, markersize = 3)
    return p
end
