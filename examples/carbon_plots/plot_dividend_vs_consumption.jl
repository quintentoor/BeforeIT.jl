# --- carbon dividend vs the real-consumption uplift it drives -------------------
# Overlays the two series behind the "why is real consumption HIGHER under the tax?"
# story on one twin-axis panel, so the co-movement is visible at a glance:
#   • LEFT axis (firebrick):  the lump-sum carbon dividend recycled to each household
#     (`lump_carbon`, €/household/quarter) — the extra spendable income the tax hands
#     back. Carbon run only; the base run has no tax to recycle.
#   • RIGHT axis (steelblue): real household consumption in the carbon run as a %
#     difference from the base run (`consumption_pct_diff`) — the demand response.
#
# Both are cross-run means with 95% CI ribbons, on the shared 2024Q1-start quarterly
# axis (both are length T — `lump_carbon` is tracked per simulated quarter, and the
# consumption diff drops its initial 2023Q4 point). The dividend rising in step with
# the consumption gap is the visual evidence that the recycled rebate — not some
# other channel — is what lifts real consumption above the base case. Reuses
# `confidence_band`/`quarter_xticks` from plot_helpers.jl and `consumption_pct_diff`
# from plot_consumption_diff.jl.
#
# Pass `sim.lump_carbon`, `sim.cons_base`, `sim.cons_carbon`.
function plot_dividend_vs_consumption(lump_carbon, cons_base, cons_carbon)
    dm, ds = confidence_band(lump_carbon)                          # € per household / quarter
    cm, cs = confidence_band(consumption_pct_diff(cons_base, cons_carbon))  # % vs base
    T = length(dm)

    p = plot(
        1:T, dm; ribbon = ds, fillalpha = 0.2, color = :firebrick, linewidth = 2,
        label = "carbon dividend (left)", legend = :topleft,
        title = "carbon dividend vs real-consumption uplift",
        xlabel = "quarter", ylabel = "€ per household / quarter",
        xticks = quarter_xticks(T; start_q0 = 0), xrotation = 45,
        ymirror = false,
    )
    pr = twinx(p)
    plot!(
        pr, 1:T, cm; ribbon = cs, fillalpha = 0.2, color = :steelblue, linewidth = 2,
        label = "real consumption Δ vs base (right)", legend = :bottomright,
        ylabel = "% vs base (no tax)",
    )
    hline!(pr, [0]; linestyle = :dash, color = :gray, label = "")  # base = 0% reference
    return p
end

# Companion table: the dividend and the consumption uplift side by side, cross-run
# mean vs quarter — the numbers behind the overlay.
function table_dividend_vs_consumption(lump_carbon, cons_base, cons_carbon)
    mean_table(
        "carbon dividend (€/hh/q) vs real consumption Δ (% vs base)",
        "carbon dividend (€)" => lump_carbon,
        "real consumption Δ (%)" => consumption_pct_diff(cons_base, cons_carbon),
    )
    return nothing
end
