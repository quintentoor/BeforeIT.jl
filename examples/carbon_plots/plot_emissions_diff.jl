# Carbon-tax effect on emissions: the carbon run's total emissions expressed as a
# percentage difference from the base (no-tax) run, quarter by quarter. A value of
# −10% means the tax has cut emissions to 10% below the base case in that quarter;
# 0% means no difference.
#
# `emis_base`/`emis_carbon` are (T × n_sims), one row per simulated quarter
# (2024Q1..2028Q4). Base and carbon within a repetition share the same RNG seed.
#
# We report the PAIRED ABSOLUTE difference (carbon − base) per run, then divide the
# cross-run mean AND its CI by the cross-run mean base level at that quarter:
#     100 · mean_s(carbon_s − base_s) / mean_s(base_s).
# This is deliberately NOT the mean of the per-run ratios `carbon/base − 1`. Over a
# long horizon the same-seed pairing decorrelates (the tax pushes the carbon economy
# onto a different path), so by the final quarters corr(base, carbon) across runs is
# small. Dividing run-by-run then injects large division noise AND biases the centre
# (E[c/b] ≠ E[c]/E[b] when b is noisy), so the ratio version reads as far less precise
# than it really is and its mean drifts away from the headline figure. Dividing the
# paired difference by a SINGLE (mean) denominator avoids both problems: the centre is
# exactly the ratio-of-means, so it matches the single "emissions Δ vs base" number
# printed by `run_comparison`, and the CI reflects the genuine paired spread. This is
# the shared `pct_diff_vs` convention used by every "X vs base" percentage panel.
emissions_pct_diff(emis_base, emis_carbon) = pct_diff_vs(emis_carbon, emis_base)

function plot_emissions_diff(emis_base, emis_carbon)
    T = size(emis_base, 1)
    m, s = confidence_band(emissions_pct_diff(emis_base, emis_carbon))
    p = plot(
        1:T, m; ribbon = s, fillalpha = 0.2, label = "carbon vs base",
        title = "total emissions Δ vs base", xlabel = "quarter",
        ylabel = "% vs base (no tax)",
        xticks = quarter_xticks(T), xrotation = 45,
    )
    hline!(p, [0]; linestyle = :dash, color = :gray, label = "")  # base = 0% reference
    return p
end

# Same data as a mean-vs-time table.
table_emissions_diff(emis_base, emis_carbon) =
    mean_table(
        "total emissions Δ vs base (% vs base)",
        "carbon vs base" => emissions_pct_diff(emis_base, emis_carbon),
    )
