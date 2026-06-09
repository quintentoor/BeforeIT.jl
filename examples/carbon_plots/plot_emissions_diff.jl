# Carbon-tax effect on emissions: the carbon run's total emissions expressed as a
# percentage difference from the base (no-tax) run, quarter by quarter. A value of
# −10% means the tax has cut emissions to 10% below the base case in that quarter;
# 0% means no difference.
#
# `emis_base`/`emis_carbon` are (T × n_sims), one row per simulated quarter
# (2024Q1..2028Q4). Base and carbon within a repetition share the same RNG seed, so
# the per-run ratio `carbon/base − 1` isolates the tax effect cleanly; we take that
# paired difference per run, then show the cross-run mean ± 95% CI ribbon (the same
# band style as the other panels). This matches the single "emissions Δ vs base"
# number printed by `run_comparison`, but resolved over the whole path.
emissions_pct_diff(emis_base, emis_carbon) = 100 .* (emis_carbon ./ emis_base .- 1)

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
