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

# Root-mean-square error between a model series and an externally SOURCED reference
# series. `M` is the (steps × n_sims) model matrix already in the SAME units as
# `sourced` (e.g. pass `100 .* unemp_base` for a %-rate, or a growth matrix for a
# %-growth); its cross-run MEAN is the model series compared against `sourced`. The
# comparison spans the overlapping quarters `min(steps, length(sourced))`, so it
# still works if the run length ever differs from the hand-entered reference. Returns
# the RMSE in those shared units.
function rmse_vs_sourced(M, sourced)
    m = vec(mean(M; dims = 2))
    n = min(length(m), length(sourced))
    return sqrt(mean(abs2, m[1:n] .- sourced[1:n]))
end

# Paired PERCENTAGE difference of `num` vs `den` — both (steps × n_sims) with columns
# sharing RNG seeds (run s of `num` and run s of `den` use the same seed). Returns the
# per-run ABSOLUTE difference (num − den) divided by the cross-run MEAN `den` level at
# each quarter. Feed it to `confidence_band` / `mean_table` exactly like the old ratio:
# its column MEAN is exactly 100·(mean(num)/mean(den) − 1) — the ratio-of-means, the
# same figure `run_comparison` prints — and its column spread is the paired difference's.
#
# Use this instead of the per-run ratio `100·(num/den − 1)` (mean-of-ratios). The two
# agree only when `den` barely varies across runs; once the same-seed pairing
# decorrelates over the horizon (corr(num, den) → small), mean-of-ratios is BIASED
# (E[x/y] ≠ E[x]/E[y]) and noisier. Dividing the paired difference by a single (mean)
# denominator fixes both. See the note atop `plot_emissions_diff.jl`.
pct_diff_vs(num, den) = 100 .* (num .- den) ./ vec(mean(den; dims = 2))

# --- Paired significance test --------------------------------------------------
# Per-timestep p-value of a PAIRED t-test comparing the carbon run to base. `base`/
# `carbon` are (steps × n_sims) matrices that share RNG seeds COLUMN BY COLUMN (base
# run s and carbon run s use the same seed), so we use the paired difference
# d = carbon − base per run, which cancels the common run-to-run variability. Per row:
# t = mean(d) / (std(d)/√n), df = n − 1, with the Student-t tail — NOT the normal
# approximation — because the difference matters right at the 5% boundary (the tail is
# a regularized incomplete beta below, so no Distributions/SpecialFunctions import).
#
# `tail` picks the alternative hypothesis:
#   :left  → H1 mean(carbon) < mean(base)   p = P(T ≤ t)        (a REDUCTION)
#   :right → H1 mean(carbon) > mean(base)   p = P(T ≥ t)        (an INCREASE)
#   :two   → H1 mean(carbon) ≠ mean(base)   p = 2·min(P(T≤t), P(T≥t))
# Returns a length-`steps` vector; rows where the two runs are identical (std 0, e.g.
# the first quarter before the tax bites) come back as `NaN` (the test is undefined).
function paired_pvalue(base, carbon; tail::Symbol = :two)
    steps, n = size(base)
    p = fill(NaN, steps)
    n < 2 && return p
    for t in 1:steps
        d = @view(carbon[t, :]) .- @view(base[t, :])
        md = mean(d); s = std(d)
        s == 0 && continue
        cdf = student_t_cdf(md / (s / sqrt(n)), n - 1)  # P(T ≤ t)
        p[t] =
            tail === :left  ? cdf :
            tail === :right ? 1 - cdf :
            tail === :two   ? 2 * min(cdf, 1 - cdf) :
            error("tail must be :left, :right or :two, got $tail")
    end
    return p
end

# One-sided REDUCTION p-value (H1: carbon < base). The one-sided direction is justified
# a priori by demand-side substitution — the tax raises the relative price of carbon-
# intensive goods, so households (CES consumption nest) and firms (price-weighted
# intermediate matching) shift away from them — so the predicted sign is set before
# seeing the data, not chosen from it. Thin wrapper over `paired_pvalue(; tail = :left)`.
paired_pvalue_reduction(base, carbon) = paired_pvalue(base, carbon; tail = :left)

# Lower-tail CDF of Student's t with `df` degrees of freedom, P(T ≤ x), via the
# regularized incomplete beta I_z(df/2, 1/2) with z = df/(df + x²). Validated against
# standard t-tables (e.g. cdf(2.228, 10) = 0.975).
student_t_cdf(x, df) = (z = df / (df + x^2);
    half = 0.5 * reg_inc_beta(z, df / 2, 0.5); x >= 0 ? 1 - half : half)

# Regularized incomplete beta I_x(a, b) and its supporting log-gamma (Lanczos) and
# continued-fraction (Numerical Recipes `betacf`) pieces. Dependency-free so the
# significance column works in the bare `examples` environment (Statistics only).
function reg_inc_beta(x, a, b)
    x <= 0 && return 0.0
    x >= 1 && return 1.0
    bt = exp(_lgamma(a + b) - _lgamma(a) - _lgamma(b) + a * log(x) + b * log(1 - x))
    x < (a + 1) / (a + b + 2) ? bt * _betacf(a, b, x) / a : 1 - bt * _betacf(b, a, 1 - x) / b
end

function _betacf(a, b, x)
    FPMIN = 1e-30
    qab = a + b; qap = a + 1; qam = a - 1
    c = 1.0; d = 1 - qab * x / qap; abs(d) < FPMIN && (d = FPMIN); d = 1 / d; h = d
    for m in 1:300
        m2 = 2m
        aa = m * (b - m) * x / ((qam + m2) * (a + m2))
        d = 1 + aa * d; abs(d) < FPMIN && (d = FPMIN)
        c = 1 + aa / c; abs(c) < FPMIN && (c = FPMIN); d = 1 / d; h *= d * c
        aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2))
        d = 1 + aa * d; abs(d) < FPMIN && (d = FPMIN)
        c = 1 + aa / c; abs(c) < FPMIN && (c = FPMIN); d = 1 / d; del = d * c; h *= del
        abs(del - 1) < 1e-12 && break
    end
    return h
end

function _lgamma(x)
    g = 7
    ctab = [0.99999999999980993, 676.5203681218851, -1259.1392167224028,
        771.32342877765313, -176.61502916214059, 12.507343278686905,
        -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7]
    x < 0.5 && return log(pi / sin(pi * x)) - _lgamma(1 - x)
    x -= 1; a = ctab[1]; t = x + g + 0.5
    for i in 2:length(ctab)
        a += ctab[i] / (x + i - 1)
    end
    return 0.5 * log(2pi) + (x + 0.5) * log(t) - t + log(a)
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
#
# `extra` appends already-computed value columns (each `name => vector`, NOT a matrix
# to be averaged) after the mean columns — e.g. a per-timestep p-value column. They
# are formatted and aligned the same way; rows shorter than `steps` are left blank.
function mean_table(title, pairs::Pair...; tlabel = "t", sigdigits = 6, extra = Pair[])
    (isempty(pairs) && isempty(extra)) && return nothing
    # Each column is (header, per-timestep value vector): means for `pairs`, the
    # supplied vectors for `extra`.
    cols = Tuple{String, Vector{Float64}}[]
    for (name, M) in pairs
        push!(cols, (string(name), vec(mean(M; dims = 2))))
    end
    for (name, v) in extra
        push!(cols, (string(name), collect(float.(v))))
    end
    steps = maximum(length(v) for (_, v) in cols)
    fmt(x) = isnan(x) ? "—" : string(round(x; sigdigits = sigdigits))

    headers = String[tlabel; [h for (h, _) in cols]]
    rows = [String[string(t); [t <= length(v) ? fmt(v[t]) : "" for (_, v) in cols]] for t in 1:steps]
    widths = [maximum(length, [headers[c]; [r[c] for r in rows]]) for c in eachindex(headers)]
    line(cells) = join((lpad(cells[c], widths[c]) for c in eachindex(widths)), "  ")

    println()
    println(title, "  (cross-run mean vs timestep)")
    println(line(headers))
    println(join(("-"^w for w in widths), "  "))
    foreach(r -> println(line(r)), rows)
    return nothing
end
