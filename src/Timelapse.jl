# Timelapse.jl
#
# Live plot of the heat simulation. The solver runs on a worker thread (Threads.@spawn) so the
# GLMakie window stays responsive. Observables may only be written from the main thread, so the
# worker sends snapshots through a Channel, and the main thread polls it every 50 ms and
# updates the plot.

module Timelapse

using GLMakie
using Printf
using ..Config
using ..HeatSolver
using ..Plotting: plot_slices

export run_heat_timelapse

"""
    run_heat_timelapse(Qel, heat_params, grid_params; use_gpu = false)

Run the heat schedule while showing the temperature field in a live 3D slice plot. The colour
range follows the data unless both `T_plot_min` and `T_plot_max` are set.
"""
function run_heat_timelapse(Qel::Array{Float64,3}, heat_params::Config.HeatParams, grid_params::Config.GridParams;
                            use_gpu::Bool = false)
    T0     = heat_params.T_initial
    fixed  = heat_params.T_plot_min !== nothing && heat_params.T_plot_max !== nothing
    field  = Observable(T0)
    crange = Observable(fixed ? (heat_params.T_plot_min, heat_params.T_plot_max) : (minimum(T0), maximum(T0) + 1.0))
    title  = Observable("t = 0.00 s")
    display(plot_slices(field, grid_params; title, colormap = :thermal, colorrange = crange,
                        ticks = GLMakie.Makie.automatic, label = "Temperature [°C]"))

    # A small buffer, so the worker rarely waits for the plot but no stale frames queue up
    snapshots = Channel(4)
    sim_task  = Threads.@spawn HeatSolver.solve_heat_schedule(Qel, heat_params, grid_params; use_gpu,
                    update_cb = (T, t, label) -> put!(snapshots, (Array(T), t, label)))  # a copy, as the solver reuses T
    bind(snapshots, sim_task)  # closes the channel when the worker finishes or fails

    # isopen before isready, so snapshots queued before the close are still shown;
    # sleep yields to the GLMakie event loop
    while isopen(snapshots) || isready(snapshots)
        while isready(snapshots)
            T, t, label = take!(snapshots)
            field[] = T
            if !fixed
                Tmin, Tmax = extrema(T)
                crange[] = (Tmin, Tmax ≈ Tmin ? Tmin + 1.0 : Tmax)
            end
            title[] = @sprintf("t = %.2f s  [%s]", t, label)
        end
        sleep(0.05)
    end
    return fetch(sim_task)  # rethrows an error from the worker
end

end # module Timelapse
