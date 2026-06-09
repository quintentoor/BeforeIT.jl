# Consumer price index (CPI): base vs carbon run. The model's CPI is
# `agg.P_bar_HH`, the household consumption-basket price index
# (`sum(b_HH_g · P_bar_g)` — sector prices weighted by the household consumption
# basket). All model prices start at 1, so the index reads as a level relative to
# 2023Q4 ≈ 1.0; multiply by 100 if you want the conventional "base = 100" form.
# The gap between the two lines is the carbon tax's pure price-level effect — the
# domestic inflation channel that "EA inflation" (an exogenous euro-area process)
# cannot show. `cpi_base`/`cpi_carbon` are (steps × n_sims).
plot_cpi(cpi_base, cpi_carbon) = compare_panel(
    cpi_base, cpi_carbon;
    start_q0 = 0,  # CPI is hand-tracked, so row 1 is the first simulated quarter (2024Q1)
    title = "consumer price index (P_bar_HH)", ylabel = "CPI (2023Q4 ≈ 1.0)",
)

# Same data as a mean-vs-time table.
table_cpi(cpi_base, cpi_carbon) =
    mean_table("consumer price index (P_bar_HH)", "base (no tax)" => cpi_base, "carbon" => cpi_carbon)
