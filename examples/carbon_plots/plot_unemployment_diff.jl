# Carbon-tax effect on the unemployment rate: the carbon run's unemployment minus
# the base (no-tax) run's, quarter by quarter, in PERCENTAGE POINTS. A value of
# +0.5 means the tax has raised unemployment to 0.5pp above the base case in that
# quarter; 0 means no difference. Percentage points (not a relative % change) are
# used because unemployment is itself a rate and can hit 0% under the productivity
# trend, which would make a `carbon/base − 1` ratio blow up.
#
# `unemp_base`/`unemp_carbon` are (T × n_sims), already one row per simulated quarter
# (2024Q1..2028Q4) — hand-tracked, so no initial-condition row to drop. Base and
# carbon within a repetition share the same RNG seed, so the per-run difference
# isolates the tax effect cleanly; we take that paired difference per run, then show
# the cross-run mean ± 95% CI ribbon (the same band style as the other panels).
unemployment_pp_diff(unemp_base, unemp_carbon) = 100 .* (unemp_carbon .- unemp_base)

function plot_unemployment_diff(unemp_base, unemp_carbon)
    d = unemployment_pp_diff(unemp_base, unemp_carbon)
    T = size(d, 1)
    m, s = confidence_band(d)
    p = plot(
        1:T, m; ribbon = s, fillalpha = 0.2, label = "carbon vs base",
        title = "unemployment rate Δ vs base", xlabel = "quarter",
        ylabel = "pp vs base (no tax)",
        xticks = quarter_xticks(T), xrotation = 45,
    )
    hline!(p, [0]; linestyle = :dash, color = :gray, label = "")  # base = 0pp reference
    return p
end

# Same data as a mean-vs-time table.
table_unemployment_diff(unemp_base, unemp_carbon) =
    mean_table(
        "unemployment rate Δ vs base (pp vs base)",
        "carbon vs base" => unemployment_pp_diff(unemp_base, unemp_carbon),
    )
