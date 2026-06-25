# Total carbon emissions (Σ intensity_i · Y_i): base vs carbon run.
plot_emissions(emis_base, emis_carbon) = compare_panel(
    emis_base, emis_carbon;
    start_q0 = 0,  # emissions are hand-tracked, so row 1 is the first simulated quarter (2024Q1)
    title = "total carbon emissions", ylabel = "Σ intensity_i · Y_i",
)

# Same data as a mean-vs-time table, plus paired p-value columns for the carbon-vs-base
# emissions difference: a one-sided test for a REDUCTION (carbon < base; direction
# justified a priori by demand-side substitution — see `paired_pvalue_reduction`) and
# the two-sided test (carbon ≠ base). Small p ⇒ significant in that quarter; "—" marks
# quarters where the two runs are identical (no variation, test undefined, e.g. t = 1).
table_emissions(emis_base, emis_carbon) =
    mean_table(
        "total carbon emissions", "base (no tax)" => emis_base, "carbon" => emis_carbon;
        extra = [
            "p (1-sided, carbon<base)" => paired_pvalue_reduction(emis_base, emis_carbon),
            "p (2-sided)" => paired_pvalue(emis_base, emis_carbon; tail = :two),
        ],
    )
