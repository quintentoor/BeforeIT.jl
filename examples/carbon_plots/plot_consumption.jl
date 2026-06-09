# Real consumer spending (level): base vs carbon run. Matrices are (steps × n_sims).
# These come from the built-in `real_household_consumption` series (VAT-inclusive
# household consumption deflated by the household CPI `P_bar_h`), which carries the
# 2023Q4 initial condition as row 1; drop it so the panel starts at the first
# simulated quarter (2024Q1, `start_q0 = 0`), matching the other graphs.
plot_consumption(cons_base, cons_carbon) =
    compare_panel(cons_base[2:end, :], cons_carbon[2:end, :]; start_q0 = 0, title = "real consumer spending")

# Same data as a mean-vs-time table. Drop row 1 (2023Q4 initial condition) too, so
# the table's `t = 1` lines up with the plot's first point (2024Q1).
table_consumption(cons_base, cons_carbon) =
    mean_table("real consumer spending", "base (no tax)" => cons_base[2:end, :], "carbon" => cons_carbon[2:end, :])
