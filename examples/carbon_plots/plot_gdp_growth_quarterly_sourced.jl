# Quarter-over-quarter real GDP growth, in %, BASE case only — with an overlaid
# line of externally SOURCED QoQ growth points for comparison.
#
# Identical to `plot_gdp_growth_quarterly` (same base mean ± 95% CI ribbon, same
# axes/ticks), plus a second "Sourced data" series of hand-entered QoQ growth
# figures (%), one per quarter 2024Q1..2028Q4. In the source the `**` quarters
# were marked as projected/forecast; here they are plotted the same as the rest.
# Reuses `gdp_growth_quarterly`, `confidence_band` and `quarter_xticks`, which are
# already `include`d into this scope from the sibling plot/helper files.
const GDP_GROWTH_SOURCED = [
    0.10,  # 2024Q1
    1.10,  # 2024Q2
    0.50,  # 2024Q3
    0.30,  # 2024Q4
    0.40,  # 2025Q1
    0.30,  # 2025Q2
    0.50,  # 2025Q3
    0.40,  # 2025Q4
    0.30,  # 2026Q1 **
    0.30,  # 2026Q2 **
    0.30,  # 2026Q3 **
    0.30,  # 2026Q4 **
    0.35,  # 2027Q1 **
    0.35,  # 2027Q2 **
    0.35,  # 2027Q3 **
    0.35,  # 2027Q4 **
    0.35,  # 2028Q1 **
    0.35,  # 2028Q2 **
    0.35,  # 2028Q3 **
    0.35,  # 2028Q4 **
]

function plot_gdp_growth_quarterly_sourced(gdp_base)
    T = size(gdp_base, 1) - 1
    m, s = confidence_band(gdp_growth_quarterly(gdp_base))
    p = plot(
        1:T, m; ribbon = s, fillalpha = 0.2, label = "base (no tax)",
        title = "real GDP growth per quarter", xlabel = "quarter", ylabel = "% (QoQ)",
        xticks = quarter_xticks(T), xrotation = 45,
    )
    # Overlay the externally sourced QoQ growth points. `min` guards the length so
    # the series still aligns if `T` ever differs from the 20 quarters entered above.
    n = min(T, length(GDP_GROWTH_SOURCED))
    plot!(p, 1:n, GDP_GROWTH_SOURCED[1:n]; label = "Sourced data", marker = :circle, markersize = 3)
    return p
end

# Same data as a mean-vs-time table: sourced vs modelled QoQ growth side by side,
# with the RMSE between the model's cross-run mean and the sourced path in the title.
function table_gdp_growth_quarterly_sourced(gdp_base)
    T = size(gdp_base, 1) - 1
    n = min(T, length(GDP_GROWTH_SOURCED))
    model = gdp_growth_quarterly(gdp_base)
    r = rmse_vs_sourced(model, GDP_GROWTH_SOURCED)
    return mean_table(
        "real GDP growth per quarter (%) — RMSE vs sourced = $(round(r, digits = 3))",
        "Sourced data" => reshape(GDP_GROWTH_SOURCED[1:n], :, 1),
        "base (no tax)" => model,
    )
end
