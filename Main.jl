# Main.jl
#
# Entry point of the project: solving the Minimum Sum Coloring Problem with
# DSATUR + simulated annealing (one-move and exchange swap neighborhoods).
# See the README for installation and usage examples. The accompanying report
# (HU_Quentin_Metaheuristiques.pdf) is written in French.

using Random, Statistics


include("graphics.jl")
include("greedy.jl")
include("annealing.jl")
include("benchmarks.jl")
include("utils.jl")


"""
    run_experiments(instances; kwargs...)

Runs `n_runs` executions of "greedy + simulated annealing" on each instance,
prints a summary (min, mean, standard deviation) and writes one line per run
to `results/raw_results_<moveType>.csv`.

Keyword arguments:
- `moveType`: `"onemove"` or `"swap"`;
- `n_runs`: number of runs per instance;
- `greedy`: initial greedy algorithm (`DSATUR` or `randDSATUR`);
- `K`, `nbIter`: number of temperature levels and iterations per level;
- `p_init`, `p_final`: probabilities of accepting a mean degradation at `T0` and `Tmin`;
- `path`: function mapping an instance name to the path of its `.col` file;
- `seed`: random seed (`nothing` to leave the seed unset);
- `chain_swap`: if true, chains a second swap annealing after each run
  (K/2 levels, nbIter/2 iterations), not included in the measured time;
- `save_plot`: if true, saves the evolution of the objective function of the
  first run to `plots/single/<moveType>_evolution_z_<instance>.png`.
"""
function run_experiments(instances::Vector{String};
        moveType::String = "onemove",
        n_runs::Int = 10,
        greedy::Function = DSATUR,
        K::Int = 1500,
        nbIter::Int = 600,
        p_init::Float64 = 0.5,
        p_final::Float64 = 0.0001,
        path::Function = name -> "Instances/$name.col",
        seed::Union{Int, Nothing} = nothing,
        chain_swap::Bool = false,
        save_plot::Bool = false)

    moveType in ("onemove", "swap") || error("moveType must be \"onemove\" or \"swap\"")
    seed === nothing || Random.seed!(seed)

    mkpath("results")
    csv_file = "results/raw_results_$moveType.csv"

    results = NamedTuple[]

    open(csv_file, "w") do csv
        println(csv, "instance,moveType,run,nbIter,K,n_edges,z0,z,valid,time_s")
        flush(csv)

        warmup_done = false

        for name in instances
            println("\n=== Instance: ", name, " (", moveType, ") ===")
            edges, n = read_instance(path(name))
            adjOf = adjacency_lists(edges, n)
            p = n + 1
            z_runs = Int[]

            # warm-up: keeps JIT compilation out of the measured times.
            # It calls the same functions as the actual runs (greedy, calibration,
            # annealing), with Float64 temperatures like those returned by
            # calibrate_temperatures, so that Julia compiles exactly the same methods.
            if !warmup_done
                x0 = greedy(n, adjOf)
                calibrate_temperatures(x0, adjOf, n, p_init, p_final, moveType)
                if moveType == "onemove"
                    simulated_annealing_onemove_fast(x0, adjOf, 1.0, 0.9, p, 0.5, 5)
                else
                    simulated_annealing_swap(x0, adjOf, 1.0, 0.9, 0.5, 5)
                end

                warmup_done = true
            end

            for run in 1:n_runs
                elapsed = @elapsed begin
                    x0 = greedy(n, adjOf)
                    z0 = sum(x0)

                    T0, Tmin = calibrate_temperatures(x0, adjOf, n, p_init, p_final, moveType)

                    if T0 === nothing || Tmin === nothing || isnan(T0) || isnan(Tmin)
                        println("Calibration failed, falling back to T0 = 50, Tmin = 0.1")
                        T0 = 50
                        Tmin = 0.1
                    end
                    alpha = (Tmin / T0)^(1 / K)

                    x_best, _, visited_values, best_f_history = moveType == "onemove" ?
                        simulated_annealing_onemove_fast(x0, adjOf, T0, Tmin, p, alpha, nbIter) :
                        simulated_annealing_swap(x0, adjOf, T0, Tmin, alpha, nbIter)
                end

                if save_plot && run == 1
                    mkpath("plots/single")
                    fig = plot_objective_function(name, visited_values, best_f_history)
                    savefig(fig, "plots/single/$(moveType)_evolution_z_$name.png")
                end

                if chain_swap
                    println("Running the chained swap annealing")
                    alpha = (Tmin / T0)^(1 / (K / 2))
                    x_best, _, _, _ = simulated_annealing_swap(x_best, adjOf, T0, Tmin, alpha, nbIter ÷ 2)
                end

                valid = isValid(x_best, adjOf)
                z = sum(x_best)
                push!(z_runs, z)

                println("run ", run, ": z0 = ", z0, "  z = ", z,
                        "  valid = ", valid, "  time = ", round(elapsed, digits = 1), " s")

                push!(results, (instance = name, moveType = moveType, run = run,
                                nbIter = nbIter, K = K, n_edges = length(edges),
                                z0 = z0, z = z, valid = valid, time = elapsed))
                println(csv, name, ",", moveType, ",", run, ",", nbIter, ",", K, ",",
                        length(edges), ",", z0, ",", z, ",", valid, ",", elapsed)
                flush(csv)
            end

            println("Summary ", name, ": min = ", minimum(z_runs),
                    "  mean = ", round(mean(z_runs), digits = 1),
                    "  σ = ", round(length(z_runs) > 1 ? std(z_runs) : 0.0, digits = 1))
        end
    end

    println("\nRaw results written to ", csv_file)
    return results
end


"""
    multi_start(instances; kwargs...)

For each instance, runs `n_starts` annealings from different initial solutions
built by `randDSATUR`, compares the best value obtained with the bounds from
the literature (appended to `results/multiple_<instance>.txt`) and saves the
figure `plots/multiple/<instance>.png`.

Keyword arguments: `moveType`, `n_starts`, `K`, `nbIter`, `p_init`, `p_final`,
`path` and `seed`, with the same meaning as in `run_experiments`.
"""
function multi_start(instances::Vector{String};
        moveType::String = "onemove",
        n_starts::Int = 10,
        K::Int = 1500,
        nbIter::Int = 600,
        p_init::Float64 = 0.5,
        p_final::Float64 = 0.0001,
        path::Function = name -> "Instances/$name.col",
        seed::Union{Int, Nothing} = nothing)

    moveType in ("onemove", "swap") || error("moveType must be \"onemove\" or \"swap\"")
    seed === nothing || Random.seed!(seed)

    mkpath("results")
    mkpath("plots/multiple")

    for name in instances
        println("\n==================== ", name, " (", moveType, ") ====================\n")

        edges, n = read_instance(path(name))
        adjOf = adjacency_lists(edges, n)

        p = n + 1

        allz0 = Int[]
        allz_end = Int[]

        best_z = Inf
        best_z0 = 0

        for i in 1:n_starts
            x_greedy = randDSATUR(n, adjOf)
            z_greedy = sum(x_greedy)

            push!(allz0, z_greedy)

            T0, Tmin = calibrate_temperatures(x_greedy, adjOf, n, p_init, p_final, moveType)

            if T0 === nothing || Tmin === nothing
                println("Unable to calibrate the initial and final temperatures.")
                T0 = 50
                Tmin = 0.1
            end
            alpha = (Tmin / T0)^(1/K)

            if moveType == "onemove"
                _, z_annealing = simulated_annealing_onemove_fast(x_greedy, adjOf, T0, Tmin, p, alpha, nbIter; trace=false)
            else
                _, z_annealing, _, _ = simulated_annealing_swap(x_greedy, adjOf, T0, Tmin, alpha, nbIter)
            end

            if z_annealing < best_z
                best_z = z_annealing
                best_z0 = z_greedy
            end
            push!(allz_end, z_annealing)

            print("$i-")
        end

        println("\n$name - Best z found: ", best_z)

        compare_to_best_known(name, best_z, best_z0, "results/multiple_$name.txt")
        fig = plot_multi_start(allz0, allz_end, best_z, name)
        savefig(fig, "plots/multiple/$name.png")
        println("Plot saved to plots/multiple/$name.png")
    end
end


println("""
Available functions:
  run_experiments(["queen5_5"]; moveType = "onemove", n_runs = 10)
      → simulated annealing (\"onemove\" or \"swap\") over several runs, results in results/
  multi_start(["queen5_5"]; moveType = "onemove", n_starts = 10)
      → multi-start from randDSATUR, figure in plots/multiple/
See the README for the full list of options.""")
