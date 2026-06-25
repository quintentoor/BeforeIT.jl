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
# A two-sided paired p-value column (carbon ≠ base) is appended: unlike emissions there
# is no a priori sign for the tax's real-GDP effect (the lump-sum dividend can push it
# either way), so the two-sided test is the appropriate one. Computed on the same
# row-1-dropped matrices the table prints. "—" marks quarters with no variation.
function table_real_gdp(gdp_base, gdp_carbon,
        gdp_base_common = gdp_base, gdp_carbon_common = gdp_carbon; common_deflator = false)
    b, c = common_deflator ? (gdp_base_common, gdp_carbon_common) : (gdp_base, gdp_carbon)
    title = common_deflator ? "real GDP (common deflator)" : "real GDP"
    return mean_table(
        title, "base (no tax)" => b[2:end, :], "carbon" => c[2:end, :];
        extra = ["p (2-sided)" => paired_pvalue(b[2:end, :], c[2:end, :]; tail = :two)],
    )
end

# Index-number robustness check for the carbon-vs-base real-GDP gap. Prints, per
# quarter (cross-run mean), the gap % under four deflator conventions side by side,
# so you can read at a glance whether the gap is a volume effect or an artefact of
# which price path was fixed on:
#   own       — each run on its OWN prices (model.data.real_gdp; mixes price + volume)
#   Laspeyres — both runs on the base run's prices  (base-scenario weights)
#   Paasche   — both runs on the carbon run's prices (carbon-scenario weights)
#   Fisher    — geometric mean of the Laspeyres and Paasche gap ratios
# Each gap is the paired difference scaled by the mean base level (the shared
# `pct_diff_vs` convention — ratio-of-means, matching `table_real_gdp_diff` and the
# `run_comparison` printout). Fisher is the geometric mean of the Laspeyres and Paasche
# ratio-of-means gaps, so all four columns use one estimator (the per-run
# `gdp_fisher_ratio` from `simulate` is retained only for call-site compatibility and
# is no longer used here). Row 1 (2023Q4 init) is dropped so t = 1 is the first sim quarter.
function table_real_gdp_index_compare(
        gdp_base, gdp_carbon,         # own deflator
        gdp_base_L, gdp_carbon_L,     # Laspeyres (base-run prices)
        gdp_base_P, gdp_carbon_P,     # Paasche (carbon-run prices)
        _gdp_fisher_ratio,            # (unused) per-run Fisher carbon/base ratio
    )
    pct(num, den) = pct_diff_vs(num[2:end, :], den[2:end, :])
    # Fisher gap = √(Laspeyres gap-ratio × Paasche gap-ratio), each a ratio-of-means.
    rL = vec(mean(gdp_carbon_L[2:end, :]; dims = 2)) ./ vec(mean(gdp_base_L[2:end, :]; dims = 2))
    rP = vec(mean(gdp_carbon_P[2:end, :]; dims = 2)) ./ vec(mean(gdp_base_P[2:end, :]; dims = 2))
    fisher = reshape(100 .* (sqrt.(rL .* rP) .- 1), :, 1)
    return mean_table(
        "real GDP gap carbon vs base — index comparison (% vs base)",
        "own"       => pct(gdp_carbon, gdp_base),
        "Laspeyres" => pct(gdp_carbon_L, gdp_base_L),
        "Paasche"   => pct(gdp_carbon_P, gdp_base_P),
        "Fisher"    => fisher,
    )
end

# Significance counterpart of `table_real_gdp_index_compare`: same four deflator
# conventions, but each column is the per-quarter paired p-value for "carbon ≠ base"
# instead of the gap %. Two-sided, because (as in `table_real_gdp`) the tax has no a
# priori sign on real GDP — the lump-sum dividend can push it either way. Use it to
# read whether the carbon-vs-base gap shown by `table_real_gdp_index_compare` is
# statistically distinguishable from zero under each index choice.
#
# own/Laspeyres/Paasche are paired tests on the matched-seed LEVEL pairs (mean of the
# per-run carbon − base difference vs 0), identical to the p-column in `table_real_gdp`
# but applied to each deflator's level matrices. Fisher has no separate base/carbon
# level series (it's defined as a ratio), so its column is a one-sample test of the
# per-run Fisher carbon/base ratio against 1 — i.e. is the per-run Fisher gap ≠ 0.
# "—" marks quarters with no variation (e.g. the first quarter before the tax bites).
# Row 1 (2023Q4 init) is dropped so t = 1 is the first sim quarter.
function table_real_gdp_index_compare_pvalues(
        gdp_base, gdp_carbon,         # own deflator
        gdp_base_L, gdp_carbon_L,     # Laspeyres (base-run prices)
        gdp_base_P, gdp_carbon_P,     # Paasche (carbon-run prices)
        gdp_fisher_ratio,             # per-run Fisher carbon/base ratio
    )
    pv(b, c) = paired_pvalue(b[2:end, :], c[2:end, :]; tail = :two)
    fr = gdp_fisher_ratio[2:end, :]
    fisher_p = paired_pvalue(ones(size(fr)), fr; tail = :two)  # ratio vs 1 (one-sample)
    return mean_table(
        "real GDP gap carbon vs base — index comparison (paired p-value, 2-sided)";
        extra = [
            "own"       => pv(gdp_base, gdp_carbon),
            "Laspeyres" => pv(gdp_base_L, gdp_carbon_L),
            "Paasche"   => pv(gdp_base_P, gdp_carbon_P),
            "Fisher"    => fisher_p,
        ],
    )
end
