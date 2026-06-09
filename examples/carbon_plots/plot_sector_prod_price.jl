# Per-sector AVERAGE production (Y_i) and selling price (P_i): base vs carbon run.
#
# `simulate` tracks, every quarter, the cross-firm mean of production and selling
# price WITHIN each of the 62 sectors, for both the base and the carbon-tax run
# (`prod_*_sec` / `price_*_sec`, each `(T × G × n_sims)`). These functions average
# over the Monte-Carlo runs and show the biggest / most-affected sectors so you can
# see how the carbon tax shifts output and prices sector by sector.
#
# Both graphs draw one colour per sector with the BASE run solid and the CARBON run
# dashed, so a gap between a sector's two lines is the tax effect on that sector.

# --- shared internals ---------------------------------------------------------
# Cross-run mean `(T × G)` of a `(T × G × n_sims)` per-sector array.
_sector_mean(M) = dropdims(mean(M; dims = 3); dims = 3)

# Pick which sectors to show: the `top_n` largest by `rankby` at the final quarter.
# `:level`  → rank by base magnitude (biggest sectors).
# `:impact` → rank by |carbon/base − 1| (sectors the tax moves the most).
function _sector_rank(mb, mc; rankby, top_n)
    G = size(mb, 2)
    last = size(mb, 1)
    key = rankby === :impact ? abs.(mc[last, :] ./ mb[last, :] .- 1) : mb[last, :]
    return sortperm(key; rev = true)[1:min(top_n, G)]
end

# Multi-line base-vs-carbon plot for the selected sectors.
function _sector_lines(base_sec, carbon_sec, labels; rankby, top_n, title, ylabel)
    mb = _sector_mean(base_sec);  mc = _sector_mean(carbon_sec)
    T = size(mb, 1)
    keep = _sector_rank(mb, mc; rankby, top_n)
    p = plot(;
        title, xlabel = "quarter", ylabel,
        xticks = quarter_xticks(T; start_q0 = 0), xrotation = 45,
        legend = :outertopright,
    )
    for (k, g) in enumerate(keep)
        plot!(p, 1:T, mb[:, g]; color = k, linewidth = 2, label = labels[g])   # base = solid
        plot!(p, 1:T, mc[:, g]; color = k, linewidth = 2, linestyle = :dash, label = "")  # carbon = dashed
    end
    return p
end

# Ranked base-vs-carbon table at the final quarter, with the % change the tax causes.
function _sector_table(title, base_sec, carbon_sec, labels; rankby, top_n)
    mb = _sector_mean(base_sec);  mc = _sector_mean(carbon_sec)
    T, G = size(mb)
    b = mb[T, :];  c = mc[T, :]
    keep = _sector_rank(mb, mc; rankby, top_n)

    fmt(x) = string(round(x; sigdigits = 6))
    delta(bx, cx) = bx == 0 ? "—" : string(round(100 * (cx / bx - 1); digits = 2), "%")

    headers = ["#", "sector", "base", "carbon", "Δ%"]
    rows = Vector{String}[]
    for (r, g) in enumerate(keep)
        push!(rows, [string(r), labels[g], fmt(b[g]), fmt(c[g]), delta(b[g], c[g])])
    end
    if length(keep) < G
        rest = setdiff(1:G, keep)
        mbr = mean(b[rest]);  mcr = mean(c[rest])
        push!(rows, ["", "Other ($(length(rest)) sectors, mean)", fmt(mbr), fmt(mcr), delta(mbr, mcr)])
    end

    widths = [maximum(length, [headers[col]; [row[col] for row in rows]]) for col in eachindex(headers)]
    cell(s, col) = col == 2 ? rpad(s, widths[col]) : lpad(s, widths[col])
    line(cells) = join((cell(cells[col], col) for col in eachindex(widths)), "  ")

    println()
    println(title, "  (cross-run mean at t=$T: base vs carbon)")
    println(line(headers))
    println(join(("-"^w for w in widths), "  "))
    foreach(r -> println(line(r)), rows)
    return nothing
end

# --- average production per sector --------------------------------------------
# Biggest sectors by output first (rankby = :level).
plot_production_sector(prod_base_sec, prod_carbon_sec, labels; top_n = 8) = _sector_lines(
    prod_base_sec, prod_carbon_sec, labels;
    rankby = :level, top_n,
    title = "avg production / sector (solid=base, dashed=carbon)",
    ylabel = "mean Y_i (real output)",
)

table_production_sector(prod_base_sec, prod_carbon_sec, labels; top_n = 20) = _sector_table(
    "average production by sector", prod_base_sec, prod_carbon_sec, labels;
    rankby = :level, top_n,
)

# --- average selling price per sector -----------------------------------------
# Sectors the tax moves the most first (rankby = :impact); prices start at 1.
plot_price_sector(price_base_sec, price_carbon_sec, labels; top_n = 8) = _sector_lines(
    price_base_sec, price_carbon_sec, labels;
    rankby = :impact, top_n,
    title = "avg selling price / sector (solid=base, dashed=carbon)",
    ylabel = "mean P_i (price)",
)

table_price_sector(price_base_sec, price_carbon_sec, labels; top_n = 20) = _sector_table(
    "average selling price by sector", price_base_sec, price_carbon_sec, labels;
    rankby = :impact, top_n,
)

# --- carbon-run price: top polluters grouped vs all other sectors grouped ------
# Two-line summary of the CARBON run's average selling price (base run not shown):
#   • one line = mean price across the `top_n` most-POLLUTING sectors,
#   • the other = mean price across every remaining sector.
# "Polluting" is ranked by BASE-CASE emissions (`emis_base_sec`, mean over time &
# runs) — the same ranking the stacked emissions graph uses — so the split reflects
# each sector's inherent carbon footprint, not the tax-distorted one. Each line is
# an UNWEIGHTED mean of the per-sector average prices across the sectors in its
# group (every sector counts equally, regardless of size). The gap between the two
# lines is how much harder the carbon tax pushes up prices in the dirty sectors.
#
# Pass `sim.price_carbon_sec` and `sim.emis_base_sec`; `top_n` sets the group size.
function _polluter_groups(emis_base_sec, top_n)
    G = size(emis_base_sec, 2)
    emis = vec(mean(emis_base_sec; dims = (1, 3)))      # (G,) base-case mean emissions / sector
    polluters = sortperm(emis; rev = true)[1:min(top_n, G)]
    return polluters, setdiff(1:G, polluters)
end

function plot_price_polluters(price_carbon_sec, emis_base_sec; top_n = 8)
    mp = _sector_mean(price_carbon_sec)                 # (T × G) cross-run mean carbon price
    T = size(mp, 1)
    polluters, rest = _polluter_groups(emis_base_sec, top_n)

    top_line = vec(mean(@view(mp[:, polluters]); dims = 2))   # group avg price, per quarter
    rest_line = vec(mean(@view(mp[:, rest]); dims = 2))

    p = plot(
        1:T, top_line;
        label = "top $(length(polluters)) polluters", linewidth = 2, color = :firebrick,
        title = "carbon-run avg selling price: polluters vs rest",
        xlabel = "quarter", ylabel = "mean P_i (price)",
        xticks = quarter_xticks(T; start_q0 = 0), xrotation = 45, legend = :topleft,
    )
    plot!(p, 1:T, rest_line; label = "other $(length(rest)) sectors", linewidth = 2, color = :steelblue)
    return p
end

# Companion table for `plot_price_polluters`: first names the sectors in the
# polluters group, then prints the two grouped lines (carbon-run average price of
# the top polluters vs of all other sectors) as a cross-run mean against time — the
# exact numbers behind the plot. Each group column is the per-run mean price across
# the sectors in that group → a `(T × n_sims)` matrix, so it folds straight into
# the standard `mean_table` (cross-run mean vs timestep) used by every other table
# here. (Averaging over sectors then runs, or runs then sectors, gives the same
# unweighted mean, so this matches the plot exactly.)
function table_price_polluters(price_carbon_sec, emis_base_sec, labels; top_n = 8)
    polluters, rest = _polluter_groups(emis_base_sec, top_n)
    # Per-run group-average price: mean over the sectors in the group → (T × n_sims).
    grp_avg(idx) = dropdims(mean(price_carbon_sec[:, idx, :]; dims = 2); dims = 2)
    println()
    println("carbon-run avg selling price — top $(length(polluters)) polluters vs other $(length(rest)) sectors")
    println("  polluters: ", join(labels[polluters], ", "))
    mean_table(
        "carbon-run avg selling price (grouped, cross-run mean)",
        "top $(length(polluters)) polluters" => grp_avg(polluters),
        "other $(length(rest)) sectors" => grp_avg(rest),
    )
    return nothing
end

# --- carbon-run production: top polluters grouped vs rest grouped, INDEXED ------
# Production analogue of `plot_price_polluters`, but CARBON RUN ONLY and INDEXED.
# The 8 polluters include the biggest-output sectors (chemicals, coke, …), so their
# group's average production is several times larger than the rest's — plotting raw
# levels would squash the rest line. Instead each group line is its cross-run mean
# average production rebased to its own 2024Q1 level (= 1.0), so the two trajectories
# sit on a comparable scale and you read off relative growth/contraction. "Polluting"
# is the SAME base-case-emissions ranking the price plot uses (`emis_base_sec`), so
# the two charts split on an identical set of sectors.
#
# Pass `sim.prod_carbon_sec` and `sim.emis_base_sec`; `top_n` sets the group size.
function _polluter_prod_index(prod_carbon_sec, emis_base_sec, top_n)
    mp = _sector_mean(prod_carbon_sec)              # (T × G) cross-run mean carbon production
    polluters, rest = _polluter_groups(emis_base_sec, top_n)
    grp(idx) = vec(mean(mp[:, idx]; dims = 2))      # group avg production per quarter
    poll = grp(polluters);  oth = grp(rest)
    return (polluters, rest, poll ./ poll[1], oth ./ oth[1])  # each rebased to its own t=1
end

function plot_production_polluters(prod_carbon_sec, emis_base_sec; top_n = 8)
    polluters, rest, poll_idx, rest_idx = _polluter_prod_index(prod_carbon_sec, emis_base_sec, top_n)
    T = length(poll_idx)
    p = plot(
        1:T, poll_idx;
        label = "top $(length(polluters)) polluters", linewidth = 2, color = :firebrick,
        title = "carbon-run avg production, indexed (2024Q1 = 1)",
        xlabel = "quarter", ylabel = "avg production (2024Q1 = 1)",
        xticks = quarter_xticks(T; start_q0 = 0), xrotation = 45, legend = :topleft,
    )
    plot!(p, 1:T, rest_idx; label = "other $(length(rest)) sectors", linewidth = 2, color = :steelblue)
    return p
end

# Companion table: names the polluters group, then the two indexed lines as a
# cross-run-mean-vs-quarter table — the exact numbers behind the plot. Each line is
# already a single indexed vector, so it goes through `mean_table` as a one-column
# "matrix" (its mean is itself).
function table_production_polluters(prod_carbon_sec, emis_base_sec, labels; top_n = 8)
    polluters, rest, poll_idx, rest_idx = _polluter_prod_index(prod_carbon_sec, emis_base_sec, top_n)
    println()
    println("carbon-run avg production, indexed (2024Q1 = 1) — top $(length(polluters)) polluters vs other $(length(rest)) sectors")
    println("  polluters: ", join(labels[polluters], ", "))
    mean_table(
        "carbon-run avg production (indexed, 2024Q1 = 1)",
        "top $(length(polluters)) polluters" => reshape(poll_idx, :, 1),
        "other $(length(rest)) sectors" => reshape(rest_idx, :, 1),
    )
    return nothing
end
