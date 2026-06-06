# Production taxes: base vs carbon run. Matrices are (steps × n_sims).
plot_taxes_production(taxprod_base, taxprod_carbon) =
    compare_panel(taxprod_base, taxprod_carbon; title = "taxes_production", xlabel = "timestep")

# Same data as a mean-vs-time table.
table_taxes_production(taxprod_base, taxprod_carbon) =
    mean_table("taxes_production", "base (no tax)" => taxprod_base, "carbon" => taxprod_carbon)
