import BeforeIT as Bit

using Random
using Test

@testset "carbon model" begin
    parameters = Bit.AUSTRIA2010Q1.parameters
    initial_conditions = Bit.AUSTRIA2010Q1.initial_conditions
    G = Int(parameters["G"])
    T = 4

    # Behavioural test 1 — with tau_carbon == 0 the carbon model must match the
    # base model bit-for-bit, given the same RNG seed.
    @testset "tau_carbon=0 reproduces base model" begin
        Random.seed!(42)
        base = Bit.Model(parameters, initial_conditions)
        for _ in 1:T
            Bit.step!(base; parallel = false)
            Bit.collect_data!(base)
        end

        Random.seed!(42)
        carbon = Bit.ModelCarbon(parameters, initial_conditions; tau_carbon = 0.0)
        for _ in 1:T
            Bit.step!(carbon; parallel = false)
            Bit.collect_data!(carbon)
        end

        @test isapprox(carbon.firms.P_i, base.firms.P_i; atol = 1.0e-10)
        @test isapprox(carbon.firms.Y_i, base.firms.Y_i; atol = 1.0e-10)
        @test isapprox(carbon.gov.Y_G, base.gov.Y_G; atol = 1.0e-10)
    end

    # Behavioural test 2 — with a dirty sector taxed and others not, that
    # sector's average price must be strictly above the baseline.
    @testset "carbon tax raises prices in taxed sector" begin
        Random.seed!(7)
        base = Bit.Model(parameters, initial_conditions)
        for _ in 1:T
            Bit.step!(base; parallel = false)
            Bit.collect_data!(base)
        end

        intensity = zeros(Float64, G)
        intensity[1] = 1.0  # only sector 1 is dirty
        Random.seed!(7)
        carbon = Bit.ModelCarbon(
            parameters, initial_conditions; tau_carbon = 0.5, carbon_intensity_s = intensity,
        )
        for _ in 1:T
            Bit.step!(carbon; parallel = false)
            Bit.collect_data!(carbon)
        end

        sector_one = carbon.firms.G_i .== 1
        carbon_mean = sum(carbon.firms.P_i[sector_one]) / count(sector_one)
        base_mean = sum(base.firms.P_i[sector_one]) / count(sector_one)
        @test carbon_mean > base_mean
    end

    # Incremental-tax test — a `CarbonTaxRamp` shock raises tau_carbon by a fixed
    # amount each quarter. The stored rate must follow the linear path, the
    # ramped run must raise strictly more revenue than a constant run pinned at
    # the ramp's starting rate, and the GVA identity must still hold.
    @testset "CarbonTaxRamp raises tax each quarter" begin
        intensity = ones(Float64, G)
        intensity[1] = 5.0
        tau_0, incr = 0.1, 0.1

        Random.seed!(123)
        ramped = Bit.ModelCarbon(
            parameters, initial_conditions; tau_carbon = tau_0, carbon_intensity_s = intensity,
        )
        ramp = Bit.CarbonTaxRamp(tau_0, incr)
        for _ in 1:T
            Bit.step!(ramped; parallel = false, shock! = ramp)
            Bit.collect_data!(ramped)
        end
        # After T steps agg.t == T + 1, but the shock caps reads at the last
        # executed quarter T, so the stored rate reflects quarter T.
        @test isapprox(ramped.firms.tau_carbon, tau_0 + incr * (T - 1); atol = 1.0e-12)

        # Constant run pinned at the ramp's starting rate, same seed/intensities.
        Random.seed!(123)
        flat = Bit.ModelCarbon(
            parameters, initial_conditions; tau_carbon = tau_0, carbon_intensity_s = intensity,
        )
        for _ in 1:T
            Bit.step!(flat; parallel = false)
            Bit.collect_data!(flat)
        end

        @test sum(ramped.data.taxes_production) > sum(flat.data.taxes_production)

        # GVA identity still holds under a time-varying tax.
        zero1 = sum(
            ramped.data.nominal_gva - ramped.data.compensation_employees -
                ramped.data.operating_surplus - ramped.data.taxes_production,
        )
        @test isapprox(zero1, 0.0, atol = 1.0e-8)
    end

    # Start-time test — with start_time > 1 the tax is off (tau_carbon == 0)
    # until that quarter, then switches on at tau_carbon_0.
    @testset "CarbonTaxRamp start_time delays the tax" begin
        intensity = ones(Float64, G)
        intensity[1] = 5.0
        tau_0, incr, start = 0.1, 0.1, 3

        Random.seed!(321)
        model = Bit.ModelCarbon(
            parameters, initial_conditions; tau_carbon = tau_0, carbon_intensity_s = intensity,
        )
        ramp = Bit.CarbonTaxRamp(tau_0, incr; start_time = start)

        # Quarters before start_time: tax is off.
        for _ in 1:(start - 1)
            Bit.step!(model; parallel = false, shock! = ramp)
            @test model.firms.tau_carbon == 0.0
        end
        # start_time quarter: tax switches on at the base rate.
        Bit.step!(model; parallel = false, shock! = ramp)
        @test isapprox(model.firms.tau_carbon, tau_0; atol = 1.0e-12)
    end

    # Accounting test — every standard accounting identity must still hold for
    # the carbon model. Money raised by the carbon tax flows from firms to the
    # government with no leakage.
    @testset "accounting identities hold for ModelCarbon" begin
        Random.seed!(99)
        intensity = ones(Float64, G)
        intensity[1] = 5.0  # make sector 1 visibly dirty so the carbon flow is non-trivial
        model = Bit.ModelCarbon(
            parameters, initial_conditions; tau_carbon = 0.1, carbon_intensity_s = intensity,
        )
        for _ in 1:1
            Bit.step!(model; parallel = false)
            Bit.collect_data!(model)
        end

        # GVA identity
        zero1 = sum(
            model.data.nominal_gva - model.data.compensation_employees -
                model.data.operating_surplus - model.data.taxes_production,
        )
        @test isapprox(zero1, 0.0, atol = 1.0e-8)

        # Nominal GDP / expenditure identity
        zero2 = sum(
            model.data.nominal_gdp - model.data.nominal_household_consumption -
                model.data.nominal_government_consumption - model.data.nominal_capitalformation -
                model.data.nominal_exports + model.data.nominal_imports,
        )
        @test isapprox(zero2, 0.0, atol = 1.0e-8)

        # Real GDP / expenditure identity
        zero3 = sum(
            model.data.real_gdp - model.data.real_household_consumption -
                model.data.real_government_consumption - model.data.real_capitalformation -
                model.data.real_exports + model.data.real_imports,
        )
        @test isapprox(zero3, 0.0, atol = 1.0e-8)

        # Central bank balance sheet identity
        zero4 = model.cb.E_CB + model.rotw.D_RoW - model.gov.L_G + model.bank.D_k
        @test isapprox(zero4, 0.0, atol = 1.0e-8)

        # Commercial bank balance sheet identity
        tot_D_h = sum(model.w_act.D_h) + sum(model.w_inact.D_h) + sum(model.firms.D_h) + model.bank.D_h
        zero5 = sum(model.firms.D_i) + tot_D_h + sum(model.bank.E_k) - sum(model.firms.L_i) - model.bank.D_k
        @test isapprox(zero5, 0.0, atol = 1.0e-8)
    end

    # Multi-sector split — splitting several sectors must append one renewable
    # firm per sector, preserve each split sector's initial emissions, and let a
    # multi-sector `CarbonTransition` raise every renewable firm's output share.
    @testset "multi-sector split + transition" begin
        Random.seed!(2024)
        base = Bit.Model(parameters, initial_conditions)
        # Split the two sectors with the most employment, so each has plenty of
        # workers to spread across its firms after carving out a renewable firm.
        N_by_sector = [sum(base.firms.N_i[base.firms.G_i .== g]) for g in 1:G]
        split = sortperm(N_by_sector; rev = true)[1:2]

        intensity = ones(Float64, G)
        intensity[split] .= 5.0  # make the split sectors visibly dirty
        share, ren_int = 0.2, 0.0

        Random.seed!(2024)
        model = Bit.ModelCarbon(
            parameters, initial_conditions;
            tau_carbon = 0.0, carbon_intensity_s = intensity,
            split_sector = split, renewable_share = share, renewable_intensity = ren_int,
        )

        # One renewable firm is appended per split sector.
        @test length(model.firms.G_i) == Int(sum(parameters["I_s"])) + length(split)

        for s in split
            idx = findall(==(s), model.firms.G_i)
            ren = idx[end]
            foss = idx[1:(end - 1)]
            # The appended firm is the (near-)clean renewable firm; the fossil
            # firms are scaled up so the split sector's initial emissions equal
            # intensity[s] times the sector's (post-split) total output.
            @test model.firms.carbon_intensity_i[ren] == ren_int
            @test all(model.firms.carbon_intensity_i[foss] .> intensity[s])
            sector_em = sum(model.firms.carbon_intensity_i[idx] .* model.firms.Y_i[idx])
            @test isapprox(sector_em, intensity[s] * sum(model.firms.Y_i[idx]); rtol = 1.0e-10)
        end

        # A multi-sector transition under a real tax must raise the renewable
        # output share in every split sector.
        function ren_share(m, s)
            idx = findall(==(s), m.firms.G_i)
            return m.firms.Y_i[idx[end]] / sum(m.firms.Y_i[idx])
        end
        share0 = [ren_share(model, s) for s in split]

        ramp = Bit.CarbonTaxRamp(0.2, 0.1)
        transition = Bit.CarbonTransition(ramp, split; rate = 0.3, max_step = 0.1)
        for _ in 1:8
            Bit.step!(model; parallel = false, shock! = transition)
            Bit.collect_data!(model)
        end
        share1 = [ren_share(model, s) for s in split]
        @test all(share1 .> share0)
    end
end
