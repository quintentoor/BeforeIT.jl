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
end
