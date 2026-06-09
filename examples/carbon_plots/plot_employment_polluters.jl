# --- carbon-run employment: top polluters grouped vs rest grouped, INDEXED ------
# Employment analogue of `plot_production_polluters` (in plot_sector_prod_price.jl):
# CARBON RUN ONLY and INDEXED to 2024Q1 = 1. `simulate` tracks `emp_carbon_sec`
# (T × G × n_sims) — the number of persons employed (`firms.N_i`) summed within each
# of the 62 sectors, per quarter and per Monte-Carlo run. This groups those sectors
# into the `top_n` most-POLLUTING (ranked by base-case emissions `emis_base_sec`, the
# SAME ranking the price/production polluter plots use, via `_polluter_groups`) versus
# all the rest, and draws each group's TOTAL employment as one line, rebased to its
# own 2024Q1 level (= 1.0). The gap shows whether the carbon tax shifts jobs out of
# the dirty sectors relative to the rest of the economy.
#
# Indexing makes summing vs unweighted-averaging across a group's sectors identical
# (each group's sector count is fixed over time), so the line reads the same either
# way; we sum so the raw quantity is "total jobs in the group". Reuses `_sector_mean`
# and `_polluter_groups` from plot_sector_prod_price.jl.
#
# Pass `sim.emp_carbon_sec` and `sim.emis_base_sec`; `top_n` sets the group size.
function _polluter_emp_index(emp_carbon_sec, emis_base_sec, top_n)
    me = _sector_mean(emp_carbon_sec)               # (T × G) cross-run mean carbon employment / sector
    polluters, rest = _polluter_groups(emis_base_sec, top_n)
    grp(idx) = vec(sum(me[:, idx]; dims = 2))       # total persons employed in the group, per quarter
    poll = grp(polluters);  oth = grp(rest)
    return (polluters, rest, poll ./ poll[1], oth ./ oth[1])  # each rebased to its own t=1
end

function plot_employment_polluters(emp_carbon_sec, emis_base_sec; top_n = 8)
    polluters, rest, poll_idx, rest_idx = _polluter_emp_index(emp_carbon_sec, emis_base_sec, top_n)
    T = length(poll_idx)
    p = plot(
        1:T, poll_idx;
        label = "top $(length(polluters)) polluters", linewidth = 2, color = :firebrick,
        title = "carbon-run employment, indexed (2024Q1 = 1)",
        xlabel = "quarter", ylabel = "employment (2024Q1 = 1)",
        xticks = quarter_xticks(T; start_q0 = 0), xrotation = 45, legend = :topleft,
    )
    plot!(p, 1:T, rest_idx; label = "other $(length(rest)) sectors", linewidth = 2, color = :steelblue)
    return p
end

# Companion table: names the polluters group, then the two indexed lines as a
# cross-run-mean-vs-quarter table — the exact numbers behind the plot. Each line is
# already a single indexed vector, so it goes through `mean_table` as a one-column
# "matrix" (its mean is itself), mirroring `table_production_polluters`.
function table_employment_polluters(emp_carbon_sec, emis_base_sec, labels; top_n = 8)
    polluters, rest, poll_idx, rest_idx = _polluter_emp_index(emp_carbon_sec, emis_base_sec, top_n)
    println()
    println("carbon-run employment, indexed (2024Q1 = 1) — top $(length(polluters)) polluters vs other $(length(rest)) sectors")
    println("  polluters: ", join(labels[polluters], ", "))
    mean_table(
        "carbon-run employment (indexed, 2024Q1 = 1)",
        "top $(length(polluters)) polluters" => reshape(poll_idx, :, 1),
        "other $(length(rest)) sectors" => reshape(rest_idx, :, 1),
    )
    return nothing
end
