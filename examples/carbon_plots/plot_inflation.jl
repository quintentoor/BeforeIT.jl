# EA inflation: base vs carbon run. `infl_base`/`infl_carbon` are (steps × n_sims).
plot_inflation(infl_base, infl_carbon) =
    compare_panel(infl_base, infl_carbon; title = "EA inflation")

# Same data as a mean-vs-time table.
table_inflation(infl_base, infl_carbon) =
    mean_table("EA inflation", "base (no tax)" => infl_base, "carbon" => infl_carbon)
