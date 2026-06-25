# Cumulative real GDP growth (compounded), in %, BASE case only — with an overlaid
# line of the externally SOURCED quarterly growth points, compounded the same way.
#
# The quarter-over-quarter counterpart is `plot_gdp_growth_quarterly_sourced`; this
# version COMPOUNDS the per-quarter growth so the curve reads as cumulative growth
# since the 2023Q4 starting point. If the QoQ growth rates are g_1, g_2, … (in %), the
# cumulative index at quarter t is
#     100 · (∏_{k=1}^{t} (1 + g_k/100) − 1).
# e.g. two consecutive +20% quarters (g = 0.20 as a fraction) give 1.2² − 1 = 44%.
# For the model this equals the level ratio gdp[t]/gdp[2023Q4] − 1 exactly (compounding
# the QoQ growths just telescopes the level ratios), so the model curve is cumulative
# real-GDP growth since the 2023Q4 initial point. The sourced line compounds
# `GDP_GROWTH_SOURCED` (defined in plot_gdp_growth_quarterly_sourced.jl) identically, so
# the two are directly comparable. Reuses `gdp_growth_quarterly`, `confidence_band`,
# `quarter_xticks` and `mean_table`, already `include`d into this scope.

# Compound a QoQ growth series (in %) into a cumulative-growth index (in %):
# 100·(∏(1 + g/100) − 1). Works on a (steps × n_sims) matrix (compounds DOWN each
# column independently via `dims = 1`) and on a length-`steps` vector.
cumulative_growth_pct(g) = 100 .* (cumprod(1 .+ g ./ 100; dims = 1) .- 1)

function plot_gdp_growth_cumulative_sourced(gdp_base)
    T = size(gdp_base, 1) - 1
    m, s = confidence_band(cumulative_growth_pct(gdp_growth_quarterly(gdp_base)))
    p = plot(
        1:T, m; ribbon = s, fillalpha = 0.2, label = "base (no tax)",
        title = "cumulative real GDP growth", xlabel = "quarter",
        ylabel = "% (cumulative since 2023Q4)",
        xticks = quarter_xticks(T), xrotation = 45,
    )
    # Overlay the externally sourced QoQ growth points, compounded the same way.
    # `min` guards the length so the series still aligns if `T` ever differs from the
    # 20 quarters entered in `GDP_GROWTH_SOURCED`.
    n = min(T, length(GDP_GROWTH_SOURCED))
    plot!(
        p, 1:n, cumulative_growth_pct(GDP_GROWTH_SOURCED)[1:n];
        label = "Sourced data", marker = :circle, markersize = 3,
    )
    return p
end

# Same data as a mean-vs-time table: sourced vs modelled cumulative growth side by
# side. The sourced column is a single deterministic path (reshaped to one "run" so
# `mean_table` can mean it trivially); the model column is the cross-run mean.
function table_gdp_growth_cumulative_sourced(gdp_base)
    T = size(gdp_base, 1) - 1
    n = min(T, length(GDP_GROWTH_SOURCED))
    model = cumulative_growth_pct(gdp_growth_quarterly(gdp_base))
    sourced = cumulative_growth_pct(GDP_GROWTH_SOURCED)
    r = rmse_vs_sourced(model, sourced)
    return mean_table(
        "cumulative real GDP growth (%) since 2023Q4 — RMSE vs sourced = $(round(r, digits = 3))",
        "Sourced data" => reshape(sourced[1:n], :, 1),
        "base (no tax)" => model,
    )
end
