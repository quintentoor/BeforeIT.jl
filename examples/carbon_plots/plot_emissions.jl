# Total carbon emissions (Σ intensity_i · Y_i): base vs carbon run.
plot_emissions(emis_base, emis_carbon) = compare_panel(
    emis_base, emis_carbon;
    title = "total carbon emissions", xlabel = "timestep", ylabel = "Σ intensity_i · Y_i",
)

# Same data as a mean-vs-time table.
table_emissions(emis_base, emis_carbon) =
    mean_table("total carbon emissions", "base (no tax)" => emis_base, "carbon" => emis_carbon)
