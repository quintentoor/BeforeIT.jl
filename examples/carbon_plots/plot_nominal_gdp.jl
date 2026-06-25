# Nominal (current-price) GDP (level): base vs carbon run. Matrices are (steps × n_sims).
# `nominal_gdp` carries the 2023Q4 initial condition as row 1; drop it so the panel
# starts at the first simulated quarter (2024Q1, `start_q0 = 0`), matching the
# real-GDP panel (`plot_real_gdp`) and the hand-tracked series.
#
# Nominal GDP is undeflated, so the carbon-vs-base gap here mixes BOTH the volume
# effect (also seen in real GDP) and the price effect the carbon tax pushes through
# the deflator — comparing this panel with `plot_real_gdp` separates the two.
function plot_nominal_gdp(nomgdp_base, nomgdp_carbon)
    return compare_panel(nomgdp_base[2:end, :], nomgdp_carbon[2:end, :];
        start_q0 = 0, title = "nominal GDP")
end

# Same data as a mean-vs-time table. Drop row 1 (2023Q4 initial condition) too, so
# the table's `t = 1` lines up with the plot's first point (2024Q1).
function table_nominal_gdp(nomgdp_base, nomgdp_carbon)
    return mean_table("nominal GDP",
        "base (no tax)" => nomgdp_base[2:end, :], "carbon" => nomgdp_carbon[2:end, :])
end
