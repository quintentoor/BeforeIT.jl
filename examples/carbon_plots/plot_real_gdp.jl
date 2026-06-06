# Real GDP (level): base vs carbon run. Matrices are (steps × n_sims).
plot_real_gdp(gdp_base, gdp_carbon) =
    compare_panel(gdp_base, gdp_carbon; title = "real GDP", xlabel = "timestep")

# Same data as a mean-vs-time table.
table_real_gdp(gdp_base, gdp_carbon) =
    mean_table("real GDP", "base (no tax)" => gdp_base, "carbon" => gdp_carbon)
