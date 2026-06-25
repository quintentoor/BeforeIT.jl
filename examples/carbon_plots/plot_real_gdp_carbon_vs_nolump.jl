# # carbon (lump) vs nolump — real GDP: does recycling the revenue matter?
#
# Both the carbon run and the `nolump` run (`Bit.ModelCarbonNoLump`) charge the SAME
# carbon tax on the SAME seed; the ONLY difference is that the carbon run recycles the
# revenue to households as a lump-sum dividend while nolump lets the government retain
# it. So this comparison nets out the tax's price pass-through (common to both) and
# isolates the lump-sum DIVIDEND's effect on real GDP — the carbon line above the
# nolump line is the recycling channel. Contrast with `plot_real_gdp_base_vs_nolump`,
# which keeps the tax in the gap by comparing against the tax-free base run.
#
# Exact mirror of the `base_vs_nolump` pair in `plot_real_gdp_nolump.jl`, but with the
# carbon run as the reference instead of base. Matrices are (T+1 × n_sims); row 1 (the
# 2023Q4 initial condition) is dropped so t = 1 is the first simulated quarter
# (2024Q1). Default is the OWN deflator (each run on its own prices, like
# `plot_real_gdp`); pass the two `_common` matrices and `common_deflator = true` for
# the base-price volume view (both runs valued at the base run's prices, so the gap
# is volume only).

# Real GDP (level): carbon (lump) vs nolump.
function plot_real_gdp_carbon_vs_nolump(gdp_carbon, gdp_nolump,
        gdp_carbon_common = gdp_carbon, gdp_nolump_common = gdp_nolump; common_deflator = false)
    c, nl = common_deflator ? (gdp_carbon_common, gdp_nolump_common) : (gdp_carbon, gdp_nolump)
    title = common_deflator ? "real GDP (common deflator)" : "real GDP"
    mc, sc = confidence_band(c[2:end, :])
    mnl, snl = confidence_band(nl[2:end, :])
    n = length(mc)
    p = plot(
        1:n, mc; ribbon = sc, fillalpha = 0.2, label = "carbon (lump-sum recycled)",
        title = title, xlabel = "quarter",
        xticks = quarter_xticks(n; start_q0 = 0), xrotation = 45,
    )
    plot!(p, 1:n, mnl; ribbon = snl, fillalpha = 0.2, label = "nolump (no recycling)")
    return p
end

# Same data as a mean-vs-time table: carbon vs nolump real GDP side by side.
function table_real_gdp_carbon_vs_nolump(gdp_carbon, gdp_nolump,
        gdp_carbon_common = gdp_carbon, gdp_nolump_common = gdp_nolump; common_deflator = false)
    c, nl = common_deflator ? (gdp_carbon_common, gdp_nolump_common) : (gdp_carbon, gdp_nolump)
    title = common_deflator ? "real GDP (common deflator)" : "real GDP"
    return mean_table(
        title, "carbon (lump)" => c[2:end, :], "nolump" => nl[2:end, :],
    )
end

# nolump real GDP as a % difference from the carbon (lump) run, quarter by quarter.
# Negative ⇒ withholding the dividend pulls real GDP BELOW the recycling run — i.e.
# the lump-sum transfer is expansionary. Paired difference per run scaled by the mean
# carbon level (shared `pct_diff_vs` — ratio-of-means), then cross-run mean ± 95% CI —
# same convention as `plot_real_gdp_diff`.
function plot_real_gdp_diff_carbon_vs_nolump(gdp_carbon, gdp_nolump,
        gdp_carbon_common = gdp_carbon, gdp_nolump_common = gdp_nolump; common_deflator = false)
    c, nl = common_deflator ? (gdp_carbon_common, gdp_nolump_common) : (gdp_carbon, gdp_nolump)
    d = pct_diff_vs(nl[2:end, :], c[2:end, :])
    T = size(d, 1)
    m, s = confidence_band(d)
    suffix = common_deflator ? " (common deflator)" : ""
    p = plot(
        1:T, m; ribbon = s, fillalpha = 0.2, label = "nolump vs carbon",
        title = "real GDP Δ vs carbon" * suffix, xlabel = "quarter",
        ylabel = "% vs carbon (lump)", xticks = quarter_xticks(T), xrotation = 45,
    )
    hline!(p, [0]; linestyle = :dash, color = :gray, label = "")  # carbon = 0% reference
    return p
end

# Same data as a mean-vs-time table.
function table_real_gdp_diff_carbon_vs_nolump(gdp_carbon, gdp_nolump,
        gdp_carbon_common = gdp_carbon, gdp_nolump_common = gdp_nolump; common_deflator = false)
    c, nl = common_deflator ? (gdp_carbon_common, gdp_nolump_common) : (gdp_carbon, gdp_nolump)
    suffix = common_deflator ? " (common deflator)" : ""
    return mean_table(
        "real GDP Δ vs carbon — nolump" * suffix * " (% vs carbon)",
        "nolump vs carbon" => pct_diff_vs(nl[2:end, :], c[2:end, :]),
    )
end
