# Base-case carbon emissions, decomposed BY SECTOR as a stacked area chart.
#
# The top edge of the stack is total emissions (Σ_all-firms intensity_i·Y_i) — the
# same quantity `plot_emissions` draws — but here it is built up band-by-band from
# the 62 sectors, so you can read off how much each industry contributes to the
# total and which ones dominate. The biggest `top_n` emitters get their own band;
# every remaining (small) sector is rolled into a single grey "Other" band at the
# top, so the chart stays legible without losing any emissions (the bands still sum
# to the true total).
#
# `emis_base_sec` is the `(T × G × n_sims)` array from `simulate` (base run only).
# We average over the Monte-Carlo runs (dim 3) to get a mean `(T × G)` path, rank
# sectors by their mean emissions over the horizon, keep the top `top_n`, and sum
# the rest into "Other". `labels` is the 62-entry `sector_labels` vector (sector
# index → name); pass `top_n` to trade legend length against detail.
function plot_emissions_stacked(emis_base_sec, labels; top_n = 8)
    T, G, _ = size(emis_base_sec)
    mean_sec = dropdims(mean(emis_base_sec; dims = 3); dims = 3)  # (T × G) cross-run mean

    # Rank sectors by mean emissions over the whole horizon (biggest first).
    rank = sortperm(vec(mean(mean_sec; dims = 1)); rev = true)
    nkeep = min(top_n, G)
    keep = rank[1:nkeep]
    rest = rank[(nkeep + 1):end]

    # Columns to stack: each kept sector, then a single rolled-up "Other".
    other = isempty(rest) ? zeros(T) : vec(sum(@view(mean_sec[:, rest]); dims = 2))
    Y = hcat(mean_sec[:, keep], other)  # (T × (nkeep+1)), largest sector first → drawn at the bottom

    band_labels = reshape(
        [labels[keep]; "Other ($(length(rest)) sectors)"], 1, :,
    )
    # Distinct colours for the kept sectors; neutral grey for the catch-all band.
    band_colors = reshape([(1:nkeep)...; :gray70], 1, :)

    p = areaplot(
        1:T, Y;
        label = band_labels, color = band_colors,
        fillalpha = 0.85, linewidth = 0, legend = :outertopright,
        title = "base-case carbon emissions by sector",
        xlabel = "quarter", ylabel = "Σ intensity_i · Y_i",
        xticks = quarter_xticks(T; start_q0 = 0), xrotation = 45,
    )
    # Emphasise the total (the stack's top edge) with a solid line so it reads as a
    # line graph of total emissions as well as a per-sector decomposition.
    plot!(p, 1:T, vec(sum(mean_sec; dims = 2)); color = :black, linewidth = 2, label = "total")
    return p
end

# Numeric counterpart: which sectors emit the most, on average over the run? Prints
# every sector's mean emissions (cross-run AND cross-time mean), its share of the
# total and a running cumulative share, ranked biggest-first. Shows all `top_n`
# rows individually and folds the remainder into an "Other" line, mirroring the
# graph. Dependency-free, same hand-aligned style as `mean_table`.
function table_emissions_stacked(emis_base_sec, labels; top_n = 15)
    G = size(emis_base_sec, 2)
    per_sector = vec(mean(emis_base_sec; dims = (1, 3)))  # mean over time AND runs → (G,)
    total = sum(per_sector)
    rank = sortperm(per_sector; rev = true)
    nkeep = min(top_n, G)

    fmt(x) = string(round(x; sigdigits = 6))
    pct(x) = string(round(100 * x / total; digits = 2), "%")

    headers = ["#", "sector", "mean emis", "share", "cum"]
    rows = Vector{String}[]
    cum = 0.0
    for (r, g) in enumerate(rank[1:nkeep])
        cum += per_sector[g]
        push!(rows, [string(r), labels[g], fmt(per_sector[g]), pct(per_sector[g]), pct(cum)])
    end
    if nkeep < G
        rest = sum(per_sector[rank[(nkeep + 1):end]])
        push!(rows, ["", "Other ($(G - nkeep) sectors)", fmt(rest), pct(rest), "100.0%"])
    end
    push!(rows, ["", "TOTAL", fmt(total), "100.0%", ""])

    # Left-align the label column, right-align the rest, like the other tables.
    widths = [maximum(length, [headers[c]; [row[c] for row in rows]]) for c in eachindex(headers)]
    cell(s, c) = c == 2 ? rpad(s, widths[c]) : lpad(s, widths[c])
    line(cells) = join((cell(cells[c], c) for c in eachindex(widths)), "  ")

    println()
    println("base-case emissions by sector  (cross-run & cross-time mean, ranked)")
    println(line(headers))
    println(join(("-"^w for w in widths), "  "))
    foreach(r -> println(line(r)), rows)
    return nothing
end
