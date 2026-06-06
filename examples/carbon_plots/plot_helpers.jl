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

# Overlay base (mean ± ribbon) and carbon (mean ± ribbon) on one panel. Each
# argument is a (steps × n_sims) matrix; extra `kwargs` (title, xlabel, …) are
# forwarded to the underlying `plot` call.
function compare_panel(Mbase, Mcarbon; kwargs...)
    mb, sb = confidence_band(Mbase)
    mc, sc = confidence_band(Mcarbon)
    p = plot(1:length(mb), mb; ribbon = sb, fillalpha = 0.2, label = "base (no tax)", kwargs...)
    plot!(p, 1:length(mc), mc; ribbon = sc, fillalpha = 0.2, label = "carbon")
    return p
end

# x-axis ticks for a `T`-quarter run starting at 2024Q1, showing one tick per
# year (2024Q1, 2025Q1, …) so the axis stays readable. Returns a value suitable
# for `xticks =`. Pair with `xrotation = 45` so the labels don't overlap.
function quarter_xticks(T)
    labels = [string(2024 + (t - 1) ÷ 4, "Q", (t - 1) % 4 + 1) for t in 1:T]
    idx = 1:4:T
    return (collect(idx), labels[idx])
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
