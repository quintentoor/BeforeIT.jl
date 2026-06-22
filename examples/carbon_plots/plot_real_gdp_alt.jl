# # alt_tax robustness check — real GDP, three-way (base / carbon / alt_tax)
#
# The `alt_tax` run (see `intensity_alt` in carbon_extension_common.jl) is the
# carbon model with every sector given the SAME (mean) carbon intensity, so its tax
# is a uniform levy on output that cannot tilt relative prices across sectors. The
# only channel left to lift real GDP is the lump-sum carbon dividend. Overlaying it
# on the base-vs-carbon real-GDP comparison answers the robustness question: if
# alt_tax tracks the carbon run (both above base), the dividend — not the sectoral
# reallocation — explains why real GDP rises under the tax.
#
# Same conventions as `plot_real_gdp`: matrices are (T+1 × n_sims), row 1 is the
# 2023Q4 initial condition (dropped so t = 1 is 2024Q1), and `common_deflator =
# true` swaps in the common-deflator matrices (all three runs valued at the base
# run's prices, so the gap is volume only). The common matrices default to the
# own-deflator ones, so a 3-argument call keeps the own-deflator behaviour.

# Pick the (base, carbon, alt) matrix triple for the requested deflator, plus the title.
_gdp_alt_triple(b, c, a, bc, cc, ac, common) =
    common ? (bc, cc, ac, "real GDP (common deflator)") : (b, c, a, "real GDP")

function plot_real_gdp_alt(gdp_base, gdp_carbon, gdp_alt,
        gdp_base_common = gdp_base, gdp_carbon_common = gdp_carbon, gdp_alt_common = gdp_alt;
        common_deflator = false)
    b, c, a, title = _gdp_alt_triple(
        gdp_base, gdp_carbon, gdp_alt,
        gdp_base_common, gdp_carbon_common, gdp_alt_common, common_deflator,
    )
    mb, sb = confidence_band(b[2:end, :])
    mc, sc = confidence_band(c[2:end, :])
    ma, sa = confidence_band(a[2:end, :])
    n = length(mb)
    p = plot(
        1:n, mb; ribbon = sb, fillalpha = 0.2, label = "base (no tax)",
        title = title, xlabel = "quarter",
        xticks = quarter_xticks(n; start_q0 = 0), xrotation = 45,
    )
    plot!(p, 1:n, mc; ribbon = sc, fillalpha = 0.2, label = "carbon")
    plot!(p, 1:n, ma; ribbon = sa, fillalpha = 0.2, label = "alt_tax (uniform)")
    return p
end

# Same data as a mean-vs-time table: base / carbon / alt_tax real GDP side by side.
function table_real_gdp_alt(gdp_base, gdp_carbon, gdp_alt,
        gdp_base_common = gdp_base, gdp_carbon_common = gdp_carbon, gdp_alt_common = gdp_alt;
        common_deflator = false)
    b, c, a, title = _gdp_alt_triple(
        gdp_base, gdp_carbon, gdp_alt,
        gdp_base_common, gdp_carbon_common, gdp_alt_common, common_deflator,
    )
    return mean_table(
        title,
        "base (no tax)" => b[2:end, :], "carbon" => c[2:end, :], "alt_tax" => a[2:end, :],
    )
end

# The direct read on the robustness question: carbon-vs-base and alt_tax-vs-base
# real-GDP gaps side by side (% vs base). Does the uniform-tax (lump-sum-only) run
# lift real GDP as much as the carbon run? Each gap is the paired per-run ratio
# (carbon/base − 1, alt/base − 1; same seed pairing), then the cross-run mean — the
# same run-level-then-average convention as `table_real_gdp_diff`. Row 1 (2023Q4
# init) is dropped so t = 1 is the first sim quarter. `common_deflator = true` uses
# the volume (base-price) matrices.
function table_real_gdp_diff_alt(gdp_base, gdp_carbon, gdp_alt,
        gdp_base_common = gdp_base, gdp_carbon_common = gdp_carbon, gdp_alt_common = gdp_alt;
        common_deflator = false)
    b, c, a, _ = _gdp_alt_triple(
        gdp_base, gdp_carbon, gdp_alt,
        gdp_base_common, gdp_carbon_common, gdp_alt_common, common_deflator,
    )
    pct(num, den) = 100 .* (num[2:end, :] ./ den[2:end, :] .- 1)
    suffix = common_deflator ? " (common deflator)" : ""
    return mean_table(
        "real GDP Δ vs base — carbon vs alt_tax" * suffix * " (% vs base)",
        "carbon vs base" => pct(c, b),
        "alt_tax vs base" => pct(a, b),
    )
end

# Lump-sum dividend per household, carbon vs alt_tax (€/quarter, both T × n_sims).
# Confirms the two runs recycle a COMPARABLE amount, so any real-GDP difference
# between them is about HOW the tax falls (sectoral vs uniform), not how much cash is
# handed back to households.
table_carbon_dividend_alt(lump_carbon, lump_alt) =
    mean_table(
        "carbon dividend per household (€/quarter) — carbon vs alt_tax",
        "carbon" => lump_carbon, "alt_tax" => lump_alt,
    )


# ---------------------------------------------------------------------------------
# # base vs alt_tax (two-series) — the direct "baseline vs alt instead of carbon" view
#
# Exact mirrors of `plot_real_gdp`/`table_real_gdp` and `plot_real_gdp_diff`/
# `table_real_gdp_diff`, but comparing the flat-intensity (uniform-tax) `alt_tax`
# run against base instead of the carbon run — no carbon line. Default is the
# OWN deflator (each run on its own prices, like `plot_real_gdp`); pass the two
# `_common` matrices and `common_deflator = true` for the base-price volume view.

# Real GDP (level): base vs alt_tax. Matrices are (T+1 × n_sims); row 1 (2023Q4
# initial condition) is dropped so t = 1 is the first simulated quarter (2024Q1).
function plot_real_gdp_base_vs_alt(gdp_base, gdp_alt,
        gdp_base_common = gdp_base, gdp_alt_common = gdp_alt; common_deflator = false)
    b, a = common_deflator ? (gdp_base_common, gdp_alt_common) : (gdp_base, gdp_alt)
    title = common_deflator ? "real GDP (common deflator)" : "real GDP"
    mb, sb = confidence_band(b[2:end, :])
    ma, sa = confidence_band(a[2:end, :])
    n = length(mb)
    p = plot(
        1:n, mb; ribbon = sb, fillalpha = 0.2, label = "base (no tax)",
        title = title, xlabel = "quarter",
        xticks = quarter_xticks(n; start_q0 = 0), xrotation = 45,
    )
    plot!(p, 1:n, ma; ribbon = sa, fillalpha = 0.2, label = "alt_tax (uniform)")
    return p
end

# Same data as a mean-vs-time table: base vs alt_tax real GDP side by side.
function table_real_gdp_base_vs_alt(gdp_base, gdp_alt,
        gdp_base_common = gdp_base, gdp_alt_common = gdp_alt; common_deflator = false)
    b, a = common_deflator ? (gdp_base_common, gdp_alt_common) : (gdp_base, gdp_alt)
    title = common_deflator ? "real GDP (common deflator)" : "real GDP"
    return mean_table(
        title, "base (no tax)" => b[2:end, :], "alt_tax" => a[2:end, :],
    )
end

# alt_tax real GDP as a % difference from base, quarter by quarter. Positive ⇒ the
# uniform-tax (lump-sum-only) run's real GDP is ABOVE base. Per-run paired ratio
# alt/base − 1 (same seed), then cross-run mean ± 95% CI — the same convention as
# `plot_real_gdp_diff`.
function plot_real_gdp_diff_base_vs_alt(gdp_base, gdp_alt,
        gdp_base_common = gdp_base, gdp_alt_common = gdp_alt; common_deflator = false)
    b, a = common_deflator ? (gdp_base_common, gdp_alt_common) : (gdp_base, gdp_alt)
    d = 100 .* (a[2:end, :] ./ b[2:end, :] .- 1)
    T = size(d, 1)
    m, s = confidence_band(d)
    suffix = common_deflator ? " (common deflator)" : ""
    p = plot(
        1:T, m; ribbon = s, fillalpha = 0.2, label = "alt_tax vs base",
        title = "real GDP Δ vs base" * suffix, xlabel = "quarter",
        ylabel = "% vs base (no tax)", xticks = quarter_xticks(T), xrotation = 45,
    )
    hline!(p, [0]; linestyle = :dash, color = :gray, label = "")  # base = 0% reference
    return p
end

# Same data as a mean-vs-time table.
function table_real_gdp_diff_base_vs_alt(gdp_base, gdp_alt,
        gdp_base_common = gdp_base, gdp_alt_common = gdp_alt; common_deflator = false)
    b, a = common_deflator ? (gdp_base_common, gdp_alt_common) : (gdp_base, gdp_alt)
    suffix = common_deflator ? " (common deflator)" : ""
    return mean_table(
        "real GDP Δ vs base — alt_tax" * suffix * " (% vs base)",
        "alt_tax vs base" => 100 .* (a[2:end, :] ./ b[2:end, :] .- 1),
    )
end
