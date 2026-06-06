# Unemployment rate (share of active workers): base vs carbon run.
plot_unemployment(unemp_base, unemp_carbon) = compare_panel(
    unemp_base, unemp_carbon;
    title = "unemployment rate", xlabel = "timestep", ylabel = "share of active workers",
)

# Same data as a mean-vs-time table.
table_unemployment(unemp_base, unemp_carbon) =
    mean_table("unemployment rate", "base (no tax)" => unemp_base, "carbon" => unemp_carbon)
