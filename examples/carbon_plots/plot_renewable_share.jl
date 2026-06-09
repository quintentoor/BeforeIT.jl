# Renewable share of output for each split sector (carbon run, abatement only).
# As the tax raises the fossil firms' price, the price-weighted matching shifts
# demand to the (untaxed) renewable firm — the renewable share rises.
#
# `ren_share` is a vector of (T × n_sims) matrices, one per split sector; `split`
# is the matching vector of sector indices, used only for the legend labels.
function plot_renewable_share(ren_share, split)
    T = isempty(ren_share) ? 0 : size(ren_share[1], 1)
    p = plot(
        title = "renewable output share (carbon run)",
        xlabel = "quarter", ylabel = "renewable / sector output", legend = :topleft,
        xticks = quarter_xticks(T), xrotation = 45,
    )
    for (k, s) in enumerate(split)
        mr, sr = confidence_band(ren_share[k])
        plot!(p, 1:length(mr), mr; ribbon = sr, fillalpha = 0.2, label = "sector $s")
    end
    return p
end

# Same data as a mean-vs-time table — one column per split sector.
table_renewable_share(ren_share, split) = mean_table(
    "renewable output share (carbon run)",
    ["sector $s" => ren_share[k] for (k, s) in enumerate(split)]...,
)
