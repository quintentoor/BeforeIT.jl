# # Carbon-tax plots — shared helpers
#
# Small building blocks used by every per-graph file in this folder. They are
# `include`d once from `carbon_extension_common.jl` (along with each plot file),
# so they share the same global scope and can use `Plots`/`Statistics`.

# Cross-run mean and 95% confidence-interval half-width for a (steps × n_sims)
# matrix `M` (one column per Monte-Carlo repetition). The half-width is
# 1.96·SE = 1.96·std/√n (normal approximation; with n_sims = 100 the
# t-correction is <1%). Unlike a raw std ribbon, this shrinks as runs are added
# and shows how precisely the mean is known. With a single run the interval is
# undefined, so fall back to a zero ribbon. `n_sims` is just `size(M, 2)`, so the
# helper is fully self-contained — callers pass only the data matrix.
function confidence_band(M)
    n = size(M, 2)
    return (
        vec(mean(M; dims = 2)),
        n > 1 ? 1.96 .* vec(std(M; dims = 2)) ./ sqrt(n) : zeros(size(M, 1)),
    )
end

# Overlay base (mean ± ribbon) and carbon (mean ± ribbon) on one panel, on the
# shared per-quarter x-axis. Each argument is a (steps × n_sims) matrix; extra
# `kwargs` (title, ylabel, …) are forwarded to the underlying `plot` call and
# override the quarter-axis defaults if a caller passes them.
#
# `start_q0` is the calendar quarter at x = 1, counted in quarters from 2024Q1.
# The built-in model series (inflation, taxes_production, real GDP) carry an
# initial 2023Q4 point as row 1, so they use the default `-1`; hand-tracked series
# that already start at 2024Q1 (e.g. emissions) pass `start_q0 = 0`.
function compare_panel(Mbase, Mcarbon; start_q0 = -1, kwargs...)
    mb, sb = confidence_band(Mbase)
    mc, sc = confidence_band(Mcarbon)
    n = length(mb)
    defaults = (; xlabel = "quarter", xticks = quarter_xticks(n; start_q0), xrotation = 45)
    p = plot(1:n, mb; ribbon = sb, fillalpha = 0.2, label = "base (no tax)", defaults..., kwargs...)
    plot!(p, 1:length(mc), mc; ribbon = sc, fillalpha = 0.2, label = "carbon")
    return p
end

# x-axis ticks for an `n`-point quarterly series, showing one tick per year on the
# year-end quarter (e.g. 2024Q4, 2025Q4, …) so the axis stays readable and the
# final simulated quarter (2028Q4 in the standard 20-quarter run) lands exactly on
# a tick. Returns a value suitable for `xticks =`. Pair with `xrotation = 45` so
# the labels don't overlap.
#
# `start_q0` is the calendar quarter at x = 1, counted in quarters from 2024Q1:
# `0` → 2024Q1 (the default; series that start at the first simulated quarter),
# `-1` → 2023Q4 (series that carry an initial point as row 1). Ticks are placed on
# every Q4 regardless of the offset.
function quarter_xticks(n; start_q0 = 0)
    label(t) = (o = start_q0 + (t - 1); string(2024 + fld(o, 4), "Q", mod(o, 4) + 1))
    idx = (mod(3 - start_q0, 4) + 1):4:n  # first Q4 on the axis, then one per year
    return (collect(idx), [label(t) for t in idx])
end

# Pretty-print a table of cross-run MEANS against time — the numeric counterpart
# of a graph. `pairs` is an ordered list of `column_name => matrix`, each matrix
# (steps × n_sims); the table has a leading `t` column (1-based timestep, matching
# the plots' x-axis) followed by one column of per-timestep means per pair.
# Dependency-free: just aligns rounded strings, no DataFrames/PrettyTables needed.
function mean_table(title, pairs::Pair...; tlabel = "t", sigdigits = 6)
    isempty(pairs) && return nothing
    means = [vec(mean(M; dims = 2)) for (_, M) in pairs]
    steps = maximum(length, means)
    fmt(x) = string(round(x; sigdigits = sigdigits))

    headers = String[tlabel; [string(name) for (name, _) in pairs]]
    rows = [String[string(t); [t <= length(m) ? fmt(m[t]) : "" for m in means]] for t in 1:steps]
    widths = [maximum(length, [headers[c]; [r[c] for r in rows]]) for c in eachindex(headers)]
    line(cells) = join((lpad(cells[c], widths[c]) for c in eachindex(widths)), "  ")

    println()
    println(title, "  (cross-run mean vs timestep)")
    println(line(headers))
    println(join(("-"^w for w in widths), "  "))
    foreach(r -> println(line(r)), rows)
    return nothing
end
