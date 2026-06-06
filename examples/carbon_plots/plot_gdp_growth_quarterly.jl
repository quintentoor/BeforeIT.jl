# Quarter-over-quarter real GDP growth, in %, BASE case only.
#
# `gdp_base` is (T+1 × n_sims): row 1 is the 2023Q4 initial point and rows
# 2..T+1 are the simulated quarters 2024Q1..2028Q4. Because row 1 exists, quarter
# 1 (2024Q1) already has a prior point to grow from, so the growth series is
# (T × n_sims) aligned to 2024Q1..2028Q4.
# Quarter-over-quarter real GDP growth (%), as a matrix aligned to 2024Q1..2028Q4.
# Shared by the plot and the table so the growth transform lives in one place.
gdp_growth_quarterly(gdp_base) = 100 .* (gdp_base[2:end, :] ./ gdp_base[1:(end - 1), :] .- 1)

function plot_gdp_growth_quarterly(gdp_base)
    T = size(gdp_base, 1) - 1
    m, s = confidence_band(gdp_growth_quarterly(gdp_base))
    return plot(
        1:T, m; ribbon = s, fillalpha = 0.2, label = "base (no tax)",
        title = "real GDP growth per quarter", xlabel = "quarter", ylabel = "% (QoQ)",
        xticks = quarter_xticks(T), xrotation = 45,
    )
end

# Same data as a mean-vs-time table (base case only).
table_gdp_growth_quarterly(gdp_base) =
    mean_table("real GDP growth per quarter (%)", "base (no tax)" => gdp_growth_quarterly(gdp_base))
