# graphics.jl
#
# Figures: evolution of the objective function during an annealing run and
# multi-start visualization.

using Plots


"""
    plot_objective_function(instance_name, visited_values, best_f_history)

Plots the current value (blue) and the best value (red) of the objective
function at each iteration of the annealing.
"""
function plot_objective_function(instance_name, visited_values::Vector{Int}, best_f_history::Vector{Int})
    iterations = 1:length(visited_values)
    fig = plot(iterations, visited_values, label="Current value", xlabel="Iterations", ylabel="Objective function value", title=instance_name)
    plot!(fig, iterations, best_f_history, label="Best value", color=:red)
    return fig
end

"""
    plot_multi_start(z0, z_end, best_z, graph_title)

For each multi-start run, draws an arrow from the initial value `z0[i]`
(black dot) to the value after annealing `z_end[i]` (red dot).
"""
function plot_multi_start(z0, z_end, best_z, graph_title)
    n_runs = min(length(z0), length(z_end))

    fig = plot(xlabel="Start", ylabel="Value of z",
               title=graph_title, legend=:topright)

    for i in 1:n_runs
        plot!(fig, [i, i], [z0[i], z_end[i]],
              color=:green, linewidth=1.5, arrow=true, label=false)
    end

    scatter!(fig, 1:n_runs, z0[1:n_runs],
             color=:black, marker=:circle, label="z0")
    scatter!(fig, 1:n_runs, z_end[1:n_runs],
             color=:red, marker=:circle, label="zend")

    hline!(fig, [best_z], color=:green, linewidth=2, label="best z")

    return fig
end
