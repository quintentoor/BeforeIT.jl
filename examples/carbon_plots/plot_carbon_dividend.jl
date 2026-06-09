# Lump-sum carbon dividend recycled to each household, € per quarter (carbon run
# only — the base run has no tax to recycle). `lump_carbon` is (T × n_sims); the
# x-axis length is read from the matrix.
function plot_carbon_dividend(lump_carbon)
    m, s = confidence_band(lump_carbon)
    T = length(m)
    return plot(
        1:T, m; ribbon = s, fillalpha = 0.2, label = "carbon",
        title = "carbon dividend per household",
        xlabel = "quarter", ylabel = "€ per household / quarter",
        xticks = quarter_xticks(T), xrotation = 45,
    )
end

# Same data as a mean-vs-time table (carbon run only).
table_carbon_dividend(lump_carbon) =
    mean_table("carbon dividend per household (€/quarter)", "carbon" => lump_carbon)
