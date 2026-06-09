# Real GDP (level): base vs carbon run. Matrices are (steps × n_sims).
# `real_gdp` carries the 2023Q4 initial condition as row 1; drop it so the panel
# starts at the first simulated quarter (2024Q1, `start_q0 = 0`), matching the
# hand-tracked series (e.g. emissions) which don't include the initial condition.
plot_real_gdp(gdp_base, gdp_carbon) =
    compare_panel(gdp_base[2:end, :], gdp_carbon[2:end, :]; start_q0 = 0, title = "real GDP")

# Same data as a mean-vs-time table. Drop row 1 (2023Q4 initial condition) too, so
# the table's `t = 1` lines up with the plot's first point (2024Q1).
table_real_gdp(gdp_base, gdp_carbon) =
    mean_table("real GDP", "base (no tax)" => gdp_base[2:end, :], "carbon" => gdp_carbon[2:end, :])
