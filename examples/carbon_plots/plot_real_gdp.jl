# Real GDP (level): base vs carbon run. Matrices are (steps × n_sims).
# `real_gdp` carries the 2023Q4 initial condition as row 1; drop it so the panel
# starts at the first simulated quarter (2024Q1, `start_q0 = 0`), matching the
# hand-tracked series (e.g. emissions) which don't include the initial condition.
#
# `common_deflator = true` swaps in the common-deflator matrices (both runs
# deflated by the matching base run's price path; see `gdp_components` in
# carbon_extension_common.jl), so the base-vs-carbon gap reflects volume only. The
# common matrices default to the own-deflator ones, so the plain 2-argument call
# `plot_real_gdp(gdp_base, gdp_carbon)` keeps its original behaviour.
function plot_real_gdp(gdp_base, gdp_carbon,
        gdp_base_common = gdp_base, gdp_carbon_common = gdp_carbon; common_deflator = false)
    b, c = common_deflator ? (gdp_base_common, gdp_carbon_common) : (gdp_base, gdp_carbon)
    title = common_deflator ? "real GDP (common deflator)" : "real GDP"
    return compare_panel(b[2:end, :], c[2:end, :]; start_q0 = 0, title = title)
end

# Same data as a mean-vs-time table. Drop row 1 (2023Q4 initial condition) too, so
# the table's `t = 1` lines up with the plot's first point (2024Q1). Same
# `common_deflator` flag as `plot_real_gdp`.
function table_real_gdp(gdp_base, gdp_carbon,
        gdp_base_common = gdp_base, gdp_carbon_common = gdp_carbon; common_deflator = false)
    b, c = common_deflator ? (gdp_base_common, gdp_carbon_common) : (gdp_base, gdp_carbon)
    title = common_deflator ? "real GDP (common deflator)" : "real GDP"
    return mean_table(title, "base (no tax)" => b[2:end, :], "carbon" => c[2:end, :])
end

# Index-number robustness check for the carbon-vs-base real-GDP gap. Prints, per
# quarter (cross-run mean), the gap % under four deflator conventions side by side,
# so you can read at a glance whether the gap is a volume effect or an artefact of
# which price path was fixed on:
#   own       — each run on its OWN prices (model.data.real_gdp; mixes price + volume)
#   Laspeyres — both runs on the base run's prices  (base-scenario weights)
#   Paasche   — both runs on the carbon run's prices (carbon-scenario weights)
#   Fisher    — geometric mean of the Laspeyres and Paasche gap ratios
# Each gap is the paired per-run ratio carbon/base − 1 (in %), then averaged across
# runs — the same run-level-then-average convention as `table_real_gdp_diff`. The
# Fisher ratio is supplied already geometric-meaned at the run level (`gdp_fisher_ratio`
# from `simulate`). Row 1 (2023Q4 init) is dropped so t = 1 is the first sim quarter.
function table_real_gdp_index_compare(
        gdp_base, gdp_carbon,         # own deflator
        gdp_base_L, gdp_carbon_L,     # Laspeyres (base-run prices)
        gdp_base_P, gdp_carbon_P,     # Paasche (carbon-run prices)
        gdp_fisher_ratio,             # Fisher carbon/base ratio, per run, per quarter
    )
    pct(num, den) = 100 .* (num[2:end, :] ./ den[2:end, :] .- 1)
    return mean_table(
        "real GDP gap carbon vs base — index comparison (% vs base)",
        "own"       => pct(gdp_carbon, gdp_base),
        "Laspeyres" => pct(gdp_carbon_L, gdp_base_L),
        "Paasche"   => pct(gdp_carbon_P, gdp_base_P),
        "Fisher"    => 100 .* (gdp_fisher_ratio[2:end, :] .- 1),
    )
end
