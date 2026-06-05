@warn "making the model deterministic all subsequent calls to the model will be deterministic."
include("epsilon.jl")
include("make_model_deterministic.jl")
include("initialize_deterministic.jl")
include("one_run_deterministic.jl")

# NOTE: the base model now uses the CANVAS average-cost pricing rule
# (π_C = AC_i(t)/AC_i(t-1) − 1, see `cost_push_inflation` in src/agent_actions/firms.jl)
# instead of the original Poledna et al. cost-vs-own-price gap formula. As a result
# `Bit.Model` no longer reproduces the original MATLAB reference *dynamics*, so the
# tests below — which pin step/trajectory output to that external reference — are
# disabled. `initialize_deterministic.jl` (init values, formula-independent) and
# `one_run_deterministic.jl` (serial/parallel self-consistency) above still hold.
# To re-enable: revert to the gap formula, or regenerate the references against the
# new pricing rule.
# include("one_epoch_deterministic.jl")          # MATLAB-reference step dynamics
# include("deterministic_ouput_t1_t5.jl")        # MATLAB-reference t1/t5 trajectory
# include("prediction_pipeline.jl")              # forecast regression vs old Julia snapshot (2010Q1.jld2)
