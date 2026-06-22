# # base vs nolump — real GDP when the carbon revenue is NOT recycled
#
# The `nolump` run (see `Bit.ModelCarbonNoLump` in src/model_extensions/init_carbon.jl
# and the nolump leg in `simulate`) charges the SAME carbon tax as the carbon run but
# does NOT hand the revenue back to households as a lump-sum dividend — the government
# retains it (lowering its deficit). So households feel the tax's price pass-through
# WITHOUT the offsetting transfer, isolating the pure contractionary side of the tax.
#
# Exact mirrors of `plot_real_gdp`/`table_real_gdp` and `plot_real_gdp_diff`/
# `table_real_gdp_diff` (and of the `base_vs_alt` pair in `plot_real_gdp_alt.jl`),
# comparing the nolump run against base. Matrices are (T+1 × n_sims); row 1 (the
# 2023Q4 initial condition) is dropped so t = 1 is the first simulated quarter
# (2024Q1). Default is the OWN deflator (each run on its own prices, like
# `plot_real_gdp`); pass the two `_common` matrices and `common_deflator = true` for
# the base-price volume view (both runs valued at the base run's prices, so the gap
# is volume only).

# Real GDP (level): base vs nolump.
function plot_real_gdp_base_vs_nolump(gdp_base, gdp_nolump,
        gdp_base_common = gdp_base, gdp_nolump_common = gdp_nolump; common_deflator = false)
    b, nl = common_deflator ? (gdp_base_common, gdp_nolump_common) : (gdp_base, gdp_nolump)
    title = common_deflator ? "real GDP (common deflator)" : "real GDP"
    mb, sb = confidence_band(b[2:end, :])
    mnl, snl = confidence_band(nl[2:end, :])
    n = length(mb)
    p = plot(
        1:n, mb; ribbon = sb, fillalpha = 0.2, label = "base (no tax)",
        title = title, xlabel = "quarter",
        xticks = quarter_xticks(n; start_q0 = 0), xrotation = 45,
    )
    plot!(p, 1:n, mnl; ribbon = snl, fillalpha = 0.2, label = "nolump (no recycling)")
    return p
end

# Same data as a mean-vs-time table: base vs nolump real GDP side by side.
function table_real_gdp_base_vs_nolump(gdp_base, gdp_nolump,
        gdp_base_common = gdp_base, gdp_nolump_common = gdp_nolump; common_deflator = false)
    b, nl = common_deflator ? (gdp_base_common, gdp_nolump_common) : (gdp_base, gdp_nolump)
    title = common_deflator ? "real GDP (common deflator)" : "real GDP"
    return mean_table(
        title, "base (no tax)" => b[2:end, :], "nolump" => nl[2:end, :],
    )
end

# nolump real GDP as a % difference from base, quarter by quarter. Negative ⇒ the
# no-recycling run's real GDP is BELOW base. Per-run paired ratio nolump/base − 1
# (same seed), then cross-run mean ± 95% CI — the same convention as
# `plot_real_gdp_diff`.
function plot_real_gdp_diff_base_vs_nolump(gdp_base, gdp_nolump,
        gdp_base_common = gdp_base, gdp_nolump_common = gdp_nolump; common_deflator = false)
    b, nl = common_deflator ? (gdp_base_common, gdp_nolump_common) : (gdp_base, gdp_nolump)
    d = 100 .* (nl[2:end, :] ./ b[2:end, :] .- 1)
    T = size(d, 1)
    m, s = confidence_band(d)
    suffix = common_deflator ? " (common deflator)" : ""
    p = plot(
        1:T, m; ribbon = s, fillalpha = 0.2, label = "nolump vs base",
        title = "real GDP Δ vs base" * suffix, xlabel = "quarter",
        ylabel = "% vs base (no tax)", xticks = quarter_xticks(T), xrotation = 45,
    )
    hline!(p, [0]; linestyle = :dash, color = :gray, label = "")  # base = 0% reference
    return p
end

# Same data as a mean-vs-time table.
function table_real_gdp_diff_base_vs_nolump(gdp_base, gdp_nolump,
        gdp_base_common = gdp_base, gdp_nolump_common = gdp_nolump; common_deflator = false)
    b, nl = common_deflator ? (gdp_base_common, gdp_nolump_common) : (gdp_base, gdp_nolump)
    suffix = common_deflator ? " (common deflator)" : ""
    return mean_table(
        "real GDP Δ vs base — nolump" * suffix * " (% vs base)",
        "nolump vs base" => 100 .* (nl[2:end, :] ./ b[2:end, :] .- 1),
    )
end
