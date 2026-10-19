# Main.jl
#
# Point d'entrée du projet : résolution du Minimum Sum Coloring Problem par
# DSATUR + recuit simulé (voisinages one-move et exchange swap).
# Voir le README pour l'installation et des exemples d'utilisation.

using Random, Statistics


include("graphics.jl")
include("glouton.jl")
include("recuit.jl")
include("benchmarks.jl")
include("utils.jl")


"""
    lancer_experiences(instances; kwargs...)

Lance `nb_runs` exécutions de « glouton + recuit simulé » sur chaque instance,
affiche un résumé (min, moyenne, écart-type) et écrit une ligne par exécution
dans `results/resultats_bruts_<moveType>.csv`.

Arguments nommés :
- `moveType` : `"onemove"` ou `"swap"` ;
- `nb_runs` : nombre d'exécutions par instance ;
- `construire` : glouton initial (`DSATUR` ou `randDSATUR`) ;
- `K`, `nbIter` : nombre de paliers de température et d'itérations par palier ;
- `p_init`, `p_fin` : probabilités d'acceptation d'une dégradation moyenne à `T0` et `Tmin` ;
- `chemin` : fonction qui associe à un nom d'instance le chemin de son fichier `.col` ;
- `seed` : graine aléatoire (`nothing` pour ne pas fixer la graine) ;
- `enchainer_swap` : si vrai, enchaîne après chaque recuit un second recuit swap
  (K/2 paliers, nbIter/2 itérations), non inclus dans le temps mesuré ;
- `sauver_graphique` : si vrai, enregistre l'évolution de la fonction objectif
  du premier run dans `plots/single/<moveType>_evolution_z_<instance>.png`.
"""
function lancer_experiences(instances::Vector{String};
        moveType::String = "onemove",
        nb_runs::Int = 10,
        construire::Function = DSATUR,
        K::Int = 1500,
        nbIter::Int = 600,
        p_init::Float64 = 0.5,
        p_fin::Float64 = 0.0001,
        chemin::Function = nom -> "Instances/$nom.col",
        seed::Union{Int, Nothing} = nothing,
        enchainer_swap::Bool = false,
        sauver_graphique::Bool = false)

    moveType in ("onemove", "swap") || error("moveType doit valoir \"onemove\" ou \"swap\"")
    seed === nothing || Random.seed!(seed)

    mkpath("results")
    fichier_csv = "results/resultats_bruts_$moveType.csv"

    resultats = NamedTuple[]

    open(fichier_csv, "w") do csv
        println(csv, "instance,moveType,run,nbIter,K,nb_aretes,z0,z,valide,temps_s")
        flush(csv)

        warmup_fait = false

        for nom in instances
            println("\n=== Instance : ", nom, " (", moveType, ") ===")
            edges, n = parser(chemin(nom))
            adjOf = adjacence(edges, n)
            p = n + 1
            z_runs = Int[]

            # tour de chauffe : évite de compter la compilation JIT dans les temps.
            # Il appelle les mêmes fonctions que les vrais runs (glouton, calibration,
            # recuit), avec des températures de type Float64 comme celles renvoyées
            # par calibrer_T, pour que Julia compile exactement les mêmes méthodes.
            if !warmup_fait
                x0 = construire(n, adjOf)
                calibrer_T(x0, adjOf, n, p_init, p_fin, moveType)
                if moveType == "onemove"
                    recuit_simule_onemove_rapide(x0, adjOf, 1.0, 0.9, p, 0.5, 5)
                else
                    recuit_simule_swap(x0, adjOf, 1.0, 0.9, 0.5, 5)
                end

                warmup_fait = true
            end

            for run in 1:nb_runs
                temps = @elapsed begin
                    x0 = construire(n, adjOf)
                    z0 = sum(x0)

                    T0, Tmin = calibrer_T(x0, adjOf, n, p_init, p_fin, moveType)

                    if T0 === nothing || Tmin === nothing || isnan(T0) || isnan(Tmin)
                        println("Calibration impossible, repli sur T0 = 50, Tmin = 0.1")
                        T0 = 50
                        Tmin = 0.1
                    end
                    alpha = (Tmin / T0)^(1 / K)

                    x_best, _, valeurs_parcourues, best_f_par_iteration = moveType == "onemove" ?
                        recuit_simule_onemove_rapide(x0, adjOf, T0, Tmin, p, alpha, nbIter) :
                        recuit_simule_swap(x0, adjOf, T0, Tmin, alpha, nbIter)
                end

                if sauver_graphique && run == 1
                    mkpath("plots/single")
                    fig = plot_objective_function(nom, valeurs_parcourues, best_f_par_iteration)
                    savefig(fig, "plots/single/$(moveType)_evolution_z_$nom.png")
                end

                if enchainer_swap
                    println("Lancement du swap")
                    alpha = (Tmin / T0)^(1 / (K / 2))
                    x_best, _, _, _ = recuit_simule_swap(x_best, adjOf, T0, Tmin, alpha, nbIter ÷ 2)
                end

                valide = isValid(x_best, adjOf)
                z = sum(x_best)
                push!(z_runs, z)

                println("run ", run, " : z0 = ", z0, "  z = ", z,
                        "  valide = ", valide, "  temps = ", round(temps, digits = 1), " s")

                push!(resultats, (instance = nom, moveType = moveType, run = run,
                                  nbIter = nbIter, K = K, nb_aretes = length(edges),
                                  z0 = z0, z = z, valide = valide, temps = temps))
                println(csv, nom, ",", moveType, ",", run, ",", nbIter, ",", K, ",",
                        length(edges), ",", z0, ",", z, ",", valide, ",", temps)
                flush(csv)
            end

            println("Bilan ", nom, " : min = ", minimum(z_runs),
                    "  moyenne = ", round(mean(z_runs), digits = 1),
                    "  σ = ", round(length(z_runs) > 1 ? std(z_runs) : 0.0, digits = 1))
        end
    end

    println("\nRésultats bruts écrits dans ", fichier_csv)
    return resultats
end


"""
    multi_start(instances; kwargs...)

Pour chaque instance, lance `nbStart` recuits depuis des solutions initiales
différentes construites par `randDSATUR`, compare la meilleure valeur obtenue
aux bornes de la littérature (ajoutée à `results/multiple_<instance>.txt`) et
enregistre la figure `plots/multiple/<instance>.png`.

Arguments nommés : `moveType`, `nbStart`, `K`, `nbIter`, `p_init`, `p_fin`,
`chemin` et `seed`, avec le même sens que pour `lancer_experiences`.
"""
function multi_start(instances::Vector{String};
        moveType::String = "onemove",
        nbStart::Int = 10,
        K::Int = 1500,
        nbIter::Int = 600,
        p_init::Float64 = 0.5,
        p_fin::Float64 = 0.0001,
        chemin::Function = nom -> "Instances/$nom.col",
        seed::Union{Int, Nothing} = nothing)

    moveType in ("onemove", "swap") || error("moveType doit valoir \"onemove\" ou \"swap\"")
    seed === nothing || Random.seed!(seed)

    mkpath("results")
    mkpath("plots/multiple")

    for nom in instances
        println("\n==================== ", nom, " (", moveType, ") ====================\n")

        edges, n = parser(chemin(nom))
        adjOf = adjacence(edges, n)

        p = n + 1

        allz0 = Int[]
        allz_end = Int[]

        best_z = Inf
        best_z0 = 0

        for i in 1:nbStart
            xGlouton = randDSATUR(n, adjOf)
            zGlouton = sum(xGlouton)

            push!(allz0, zGlouton)

            T0, Tmin = calibrer_T(xGlouton, adjOf, n, p_init, p_fin, moveType)

            if T0 === nothing || Tmin === nothing
                println("Impossible de calibrer les températures initiale et finale.")
                T0 = 50
                Tmin = 0.1
            end
            alpha = (Tmin / T0)^(1/K)

            if moveType == "onemove"
                _, zRecuit = recuit_simule_onemove_rapide(xGlouton, adjOf, T0, Tmin, p, alpha, nbIter; trace=false)
            else
                _, zRecuit, _, _ = recuit_simule_swap(xGlouton, adjOf, T0, Tmin, alpha, nbIter)
            end

            if zRecuit < best_z
                best_z = zRecuit
                best_z0 = zGlouton
            end
            push!(allz_end, zRecuit)

            print("$i-")
        end

        println("\n$nom - Meilleur z trouvé : ", best_z)

        comparer_resultat(nom, best_z, best_z0, "results/multiple_$nom.txt")
        fig = plot_multiple_recuit(allz0, allz_end, best_z, nom)
        savefig(fig, "plots/multiple/$nom.png")
        println("Graphique sauvegardé dans plots/multiple/$nom.png")
    end
end


println("""
Fonctions disponibles :
  lancer_experiences(["queen5_5"]; moveType = "onemove", nb_runs = 10)
      → recuit simulé (\"onemove\" ou \"swap\") sur plusieurs exécutions, résultats dans results/
  multi_start(["queen5_5"]; moveType = "onemove", nbStart = 10)
      → multi-start depuis randDSATUR, figure dans plots/multiple/
Voir le README pour la liste complète des options.""")
