# graphics.jl
#
# Figures : évolution de la fonction objectif pendant un recuit et
# visualisation du multi-start.

using Plots


"""
    plot_objective_function(name_instance, valeurs_parcourues, best_f_par_iteration)

Trace la valeur courante (bleu) et la meilleure valeur (rouge) de la fonction
objectif à chaque itération du recuit.
"""
function plot_objective_function(name_instance, valeurs_parcourues::Vector{Int}, best_f_par_iteration::Vector{Int})
    iterations = 1:length(valeurs_parcourues)
    fig = plot(iterations, valeurs_parcourues, label="Valeur courante", xlabel="Itérations", ylabel="Valeur de la fonction objectif", title=name_instance)
    plot!(fig, iterations, best_f_par_iteration, label="Meilleure valeur", color=:red)
    return fig
end

"""
    plot_multiple_recuit(z0, z_end, best_z, graph_title)

Pour chaque départ du multi-start, flèche de la valeur initiale `z0[i]`
(point noir) vers la valeur après recuit `z_end[i]` (point rouge).
"""
function plot_multiple_recuit(z0, z_end, best_z, graph_title)
    nb_runs = min(length(z0), length(z_end))

    fig = plot(xlabel="Départ", ylabel="Valeur de z",
               title=graph_title, legend=:topright)

    for i in 1:nb_runs
        plot!(fig, [i, i], [z0[i], z_end[i]],
              color=:green, linewidth=1.5, arrow=true, label=false)
    end

    scatter!(fig, 1:nb_runs, z0[1:nb_runs],
             color=:black, marker=:circle, label="z0")
    scatter!(fig, 1:nb_runs, z_end[1:nb_runs],
             color=:red, marker=:circle, label="zend")

    hline!(fig, [best_z], color=:green, linewidth=2, label="meilleur z")

    return fig
end
