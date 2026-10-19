# utils.jl
#
# Lecture des instances, structures de graphe, validité d'une coloration et
# calibration des températures du recuit simulé.

"""
    isValid(colorOf, adjOf)

Vrai si aucune arête ne relie deux sommets de même couleur.
"""
function isValid(colorOf, adjOf)
    for (v, c) in enumerate(colorOf)
        for u in adjOf[v]
            if c == colorOf[u]
                return false
            end
        end
    end
    return true
end

"""
    calibrer_T(x, adjOf, nb_echantillon, proba_initiale, proba_finale, moveType)

Calcule `T0` et `Tmin` à partir de la dégradation moyenne observée sur
`max(100, nb_echantillon)` voisins de `x` (sans pénalité), de sorte qu'une
dégradation moyenne soit acceptée avec la probabilité `proba_initiale` au
début et `proba_finale` à la fin. Renvoie `(nothing, nothing)` si aucun
voisin dégradant n'a été observé.
"""
function calibrer_T(x, adjOf, nb_echantillon, proba_initiale, proba_finale,
                    moveType::String = "onemove")
    voisin = moveType == "onemove" ? voisinage_onemove : voisinage_swap

    deltas_degrad = Int[]
    f_ref = sum(x)
    for _ in 1:max(100, nb_echantillon)
        x_new = voisin(x, adjOf)
        delta = sum(x_new) - f_ref
        if delta > 0
            push!(deltas_degrad, delta)
        end
    end

    if isempty(deltas_degrad)
        return nothing, nothing
    end

    mean_delta = mean(deltas_degrad)
    T0   = -mean_delta / log(proba_initiale)
    Tmin = -mean_delta / log(proba_finale)
    return T0, Tmin
end

"""
    adjacence(edges, n)

Listes d'adjacence d'un graphe non orienté à `n` sommets.
"""
function adjacence(edges, n)::Vector{Vector{Int}}
    adjOf::Vector{Vector{Int}} = [Int[] for _ in 1:n]

    for (u, v) in edges
        push!(adjOf[u], v)
        push!(adjOf[v], u)
    end
    return adjOf
end

"""
    parser(filename)

Lit un fichier au format DIMACS (`.col`) et renvoie `(edges, n)`.
"""
function parser(filename::String)
    # Les fichiers DIMACS (.col) listent parfois chaque arête dans les deux sens
    # ("e 1 2" puis "e 2 1"), et l'en-tête "p edge n m" compte alors m = 2 x |E|.
    # On normalise chaque arête en (min, max), on ignore les boucles et on
    # supprime les doublons pour que chaque arête réelle apparaisse une seule fois.
    edges_set = Set{Tuple{Int,Int}}()
    n = 0
    open(filename, "r") do file
        for line in eachline(file)
            if startswith(line, "p")
                parts = split(line)
                n = parse(Int, parts[3])
            elseif startswith(line, "e")
                parts = split(line)
                u = parse(Int, parts[2])
                v = parse(Int, parts[3])
                u == v && continue
                push!(edges_set, u < v ? (u, v) : (v, u))
            end
        end
    end
    edges::Vector{Tuple{Int,Int}} = sort!(collect(edges_set))
    return edges, n
end
