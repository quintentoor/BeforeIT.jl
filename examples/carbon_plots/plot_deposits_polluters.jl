# --- carbon-run firm deposits: top polluters grouped vs rest grouped, RAW € ------
# Deposit analogue of `plot_profit_polluters` / `plot_employment_polluters`, but
# CARBON RUN ONLY and in RAW EURO LEVELS (not indexed). `simulate` tracks
# `dep_carbon_sec` (T × G × n_sims) — the total firm bank deposits (`firms.D_i`)
# summed within each of the 62 sectors, per quarter and per Monte-Carlo run. This
# groups those sectors into the `top_n` most-POLLUTING (ranked by base-case emissions
# `emis_base_sec`, the SAME ranking the price/production/employment/profit polluter
# plots use, via `_polluter_groups`) versus all the rest, and draws each group's TOTAL
# deposits in euros as one line. The gap shows whether the carbon tax drains cash
# balances from the dirty sectors relative to the rest of the economy.
#
# Why RAW €, not indexed like the other polluter plots: firm deposits CROSS ZERO over
# the run (firms run their cash down into net overdraft/loan positions), so rebasing
# to 2024Q1 = 1 produces meaningless negative "index" values once the line passes
# through zero. Raw euros keep the sign — and the crossing into overdraft — readable.
# A zero reference line is drawn so the sign change is obvious. Reuses `_sector_mean`
# and `_polluter_groups` from plot_sector_prod_price.jl.
#
# Pass `sim.dep_carbon_sec` and `sim.emis_base_sec`; `top_n` sets the group size.
function _polluter_dep_levels(dep_carbon_sec, emis_base_sec, top_n)
    md = _sector_mean(dep_carbon_sec)               # (T × G) cross-run mean carbon deposits / sector
    polluters, rest = _polluter_groups(emis_base_sec, top_n)
    grp(idx) = vec(sum(md[:, idx]; dims = 2))       # total deposits (€) in the group, per quarter
    return (polluters, rest, grp(polluters), grp(rest))
end

function plot_deposits_polluters(dep_carbon_sec, emis_base_sec; top_n = 8)
    polluters, rest, poll_lvl, rest_lvl = _polluter_dep_levels(dep_carbon_sec, emis_base_sec, top_n)
    T = length(poll_lvl)
    p = plot(
        1:T, poll_lvl;
        label = "top $(length(polluters)) polluters", linewidth = 2, color = :firebrick,
        title = "carbon-run firm deposits (€)",
        xlabel = "quarter", ylabel = "total deposits (€)",
        xticks = quarter_xticks(T; start_q0 = 0), xrotation = 45, legend = :topleft,
    )
    plot!(p, 1:T, rest_lvl; label = "other $(length(rest)) sectors", linewidth = 2, color = :steelblue)
    hline!(p, [0.0]; color = :black, linestyle = :dot, linewidth = 1, label = "")  # zero / overdraft line
    return p
end

# Companion table: names the polluters group, then the two raw-€ lines as a
# cross-run-mean-vs-quarter table — the exact numbers behind the plot. Each line is
# already a single vector, so it goes through `mean_table` as a one-column "matrix"
# (its mean is itself), mirroring `table_profit_polluters`.
function table_deposits_polluters(dep_carbon_sec, emis_base_sec, labels; top_n = 8)
    polluters, rest, poll_lvl, rest_lvl = _polluter_dep_levels(dep_carbon_sec, emis_base_sec, top_n)
    println()
    println("carbon-run firm deposits (€) — top $(length(polluters)) polluters vs other $(length(rest)) sectors")
    println("  polluters: ", join(labels[polluters], ", "))
    mean_table(
        "carbon-run firm deposits (€)",
        "top $(length(polluters)) polluters" => reshape(poll_lvl, :, 1),
        "other $(length(rest)) sectors" => reshape(rest_lvl, :, 1),
    )
    return nothing
end

# --- BASE-run counterparts -----------------------------------------------------
# Same raw-€ polluters-vs-rest deposit view, but for the BASE (no-tax) run. The
# polluter ranking still comes from base-case emissions `emis_base_sec` (identical
# split), so this is the carbon plot's control: how firm cash balances evolve with
# no carbon tax. The shared `_polluter_dep_levels` is run-agnostic — it just sums
# whatever per-sector deposit array it's handed — so pass `sim.dep_base_sec` here.
function plot_deposits_polluters_base(dep_base_sec, emis_base_sec; top_n = 8)
    polluters, rest, poll_lvl, rest_lvl = _polluter_dep_levels(dep_base_sec, emis_base_sec, top_n)
    T = length(poll_lvl)
    p = plot(
        1:T, poll_lvl;
        label = "top $(length(polluters)) polluters", linewidth = 2, color = :firebrick,
        title = "base-run firm deposits (€)",
        xlabel = "quarter", ylabel = "total deposits (€)",
        xticks = quarter_xticks(T; start_q0 = 0), xrotation = 45, legend = :topleft,
    )
    plot!(p, 1:T, rest_lvl; label = "other $(length(rest)) sectors", linewidth = 2, color = :steelblue)
    hline!(p, [0.0]; color = :black, linestyle = :dot, linewidth = 1, label = "")  # zero / overdraft line
    return p
end

function table_deposits_polluters_base(dep_base_sec, emis_base_sec, labels; top_n = 8)
    polluters, rest, poll_lvl, rest_lvl = _polluter_dep_levels(dep_base_sec, emis_base_sec, top_n)
    println()
    println("base-run firm deposits (€) — top $(length(polluters)) polluters vs other $(length(rest)) sectors")
    println("  polluters: ", join(labels[polluters], ", "))
    mean_table(
        "base-run firm deposits (€)",
        "top $(length(polluters)) polluters" => reshape(poll_lvl, :, 1),
        "other $(length(rest)) sectors" => reshape(rest_lvl, :, 1),
    )
    return nothing
end
