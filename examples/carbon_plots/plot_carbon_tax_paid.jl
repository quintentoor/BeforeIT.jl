# # Carbon tax paid — carbon vs alt_tax
#
# Total carbon tax PAID by firms each quarter, in euros (`tax_carbon`/`tax_alt`,
# both T × n_sims). By the model's budget-neutral recycling this equals the TOTAL
# lump-sum dividend handed back to households that quarter; dividing by the number
# of households `H` gives the per-household figure (`lump_carbon`/`lump_alt`).
#
# This is the panel to read when matching the two runs' tax burden: `intensity_alt`
# is set to the OUTPUT-WEIGHTED mean intensity precisely so the alt_tax run pays the
# same total tax (and recycles the same dividend) as the carbon run at baseline, so
# the two lines should sit on top of each other early on and only drift as the
# simulated output mixes diverge. Hand-tracked series start at the first simulated
# quarter (2024Q1, `start_q0 = 0`), so there is no initial row to drop.

function plot_carbon_tax_paid(tax_carbon, tax_alt)
    mc, sc = confidence_band(tax_carbon)
    ma, sa = confidence_band(tax_alt)
    n = length(mc)
    p = plot(
        1:n, mc; ribbon = sc, fillalpha = 0.2, label = "carbon",
        title = "carbon tax paid (= total lump-sum recycled)",
        xlabel = "quarter", ylabel = "€ per quarter",
        xticks = quarter_xticks(n; start_q0 = 0), xrotation = 45,
    )
    plot!(p, 1:length(ma), ma; ribbon = sa, fillalpha = 0.2, label = "alt_tax (uniform)")
    return p
end

# Mean-vs-time table: total carbon tax paid (= total lump-sum recycled) AND the
# per-household lump-sum dividend, carbon vs alt_tax side by side. The first two
# columns are what you match on; the last two show the same thing per household.
function table_carbon_tax_paid(tax_carbon, tax_alt, lump_carbon, lump_alt)
    return mean_table(
        "carbon tax paid / lump-sum recycled — carbon vs alt_tax",
        "tax total carbon (€)"  => tax_carbon,
        "tax total alt (€)"     => tax_alt,
        "lump/hh carbon (€)"    => lump_carbon,
        "lump/hh alt (€)"       => lump_alt,
    )
end

# alt_tax carbon tax paid as a % difference from the carbon run, quarter by quarter.
# 0% ⇒ the two runs pay (and recycle) exactly the same — the target when matching
# `intensity_alt`. Paired difference per run scaled by the mean carbon level (shared
# `pct_diff_vs` — ratio-of-means), then cross-run mean ± 95% CI.
function plot_carbon_tax_paid_diff(tax_carbon, tax_alt)
    d = pct_diff_vs(tax_alt, tax_carbon)
    T = size(d, 1)
    m, s = confidence_band(d)
    p = plot(
        1:T, m; ribbon = s, fillalpha = 0.2, label = "alt_tax vs carbon",
        title = "carbon tax paid Δ: alt_tax vs carbon", xlabel = "quarter",
        ylabel = "% vs carbon", xticks = quarter_xticks(T; start_q0 = 0), xrotation = 45,
    )
    hline!(p, [0]; linestyle = :dash, color = :gray, label = "")  # matched = 0%
    return p
end

# Same data as a mean-vs-time table.
table_carbon_tax_paid_diff(tax_carbon, tax_alt) =
    mean_table(
        "carbon tax paid Δ: alt_tax vs carbon (% vs carbon)",
        "alt_tax vs carbon" => pct_diff_vs(tax_alt, tax_carbon),
    )
