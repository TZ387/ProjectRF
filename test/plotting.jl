using GLMakie: GLMakie

GLMakie.activate!(visible = false)

@testset "plot_graphs saves all plots" begin
    gp = GridParams(0.09, 0.09, 0.05, 9, 9, 5)
    material_indices = [1 + (l > 2) for i in 1:9, j in 1:9, l in 1:5]
    sigma = [0.2, 0.5][material_indices]
    rf = RFParams(sigma, fill(1e4, size(sigma)), zeros(size(sigma)), 1e6)  # complex V and E
    bc = Dict("top" => (x, t) -> abs(x[1]) <= 0.02 ? 100.0 : nothing, "bottom" => (x, t) -> 0.0)
    _, _, Qel, E_mag, E_vec, V = @test_logs min_level = Logging.Warn run_simulation(gp, rf, bc)
    mktempdir() do dir
        plot_graphs(material_indices, gp, Qel, E_mag, E_vec, V, joinpath(dir, "plot"))
        @test all(isfile(joinpath(dir, "plot_$c.png")) for c in 'a':'e')
    end
end

@testset "live heat plot" begin
    gp = GridParams(0.01, 0.01, 0.01, 4, 4, 4)
    Qel = [1e5 * l for i in 1:4, j in 1:4, l in 1:4]
    heat_params(phase) = HeatParams([phase, HeatPhase(duration = 5.0)], 2, fill(37.0, 4, 4, 4), fill(1e6, 4, 4, 4), fill(0.5, 4, 4, 4))
    hp = heat_params(HeatPhase(duration = 10.0, rf_factor = 1.0))
    T = @test_logs min_level = Logging.Warn run_heat_simulation(Qel, gp, hp; create_timelapse = true)
    @test T == run_heat_simulation(Qel, gp, hp)
    # A solver error reaches the caller instead of leaving the plot waiting
    @test_throws TaskFailedException run_heat_simulation(Qel, gp, heat_params(HeatPhase(duration = 10.0, rf_factor = ones(3, 3, 3))); create_timelapse = true)
end
