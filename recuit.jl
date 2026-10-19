# recuit.jl
#
# Recuit simulé pour le MSCP avec deux voisinages :
#   - one-move à évaluation incrémentale (annexe A.1 du rapport) ;
#   - exchange swap (chaînes de Kempe), qui reste dans l'espace réalisable.

"""
    recuit_simule_onemove_rapide(x0, adjOf, T0, Tmin, p, alpha, nbIter; trace = true)

Recuit simulé avec le voisinage one-move et la fonction objectif pénalisée
`f_p(x) = Σ x[v] + p · (nombre d'arêtes en conflit)`, évaluée de manière
incrémentale en O(deg(v)) par itération.

Renvoie `(best_x, best_f, valeurs_parcourues, best_f_par_iteration)` si
`trace` est vrai, `(best_x, best_f)` sinon.
"""
function recuit_simule_onemove_rapide(x0, adjOf, T0, Tmin, p, alpha, nbIter; trace = true)
    function ajouter_conflit!(conf_list, pos, v)
        push!(conf_list, v)
        pos[v] = length(conf_list)
    end

    function retirer_conflit!(conf_list, pos, v)
        i = pos[v]
        dernier = conf_list[end]
        conf_list[i] = dernier
        pos[dernier] = i
        pop!(conf_list)
        pos[v] = 0
    end

    n = length(x0)
    x = copy(x0)

    # ---------- état maintenu incrémentalement ----------
    somme = sum(x)

    # nbconf[v] = nombre de voisins de v ayant la même couleur que v
    nbconf = zeros(Int, n)
    for v in 1:n
        for u in adjOf[v]
            if x[u] == x[v]
                nbconf[v] += 1
            end
        end
    end
    # chaque arête en conflit est comptée par ses deux extrémités
    nb_aretes_conflit = sum(nbconf) ÷ 2

    # ensemble des sommets en conflit (nbconf[v] > 0), avec tirage uniforme en O(1)
    conf_list = Int[]
    pos = zeros(Int, n)        # pos[v] = position de v dans conf_list (0 si absent)
    for v in 1:n
        if nbconf[v] > 0
            ajouter_conflit!(conf_list, pos, v)
        end
    end

    # nbColor[c] = nombre de sommets de couleur c, pour suivre la couleur maximale
    nbColor = zeros(Int, maximum(x) + 2)
    for c in x
        nbColor[c] += 1
    end
    couleur_max = maximum(x)

    # ---------- boucle de recuit ----------
    f_courant = somme + p * nb_aretes_conflit
    best_x = copy(x)
    best_f = f_courant

    T = T0

    if trace
        valeurs_parcourues = [f_courant]
        best_f_par_iteration = [best_f]
    end

    while T > Tmin
        for _ in 1:nbIter
            # 1) tirage du mouvement (c_new est tirée différente de c_old)
            v = isempty(conf_list) ? rand(1:n) : rand(conf_list)
            c_old = x[v]
            c_new = rand(1:couleur_max + 1)

            while c_new == c_old
                c_new = rand(1:couleur_max + 1)
            end

            # 2) calcul du delta
            nb_adj_c_old = nbconf[v]           # voisins de couleur c_old
            nb_adj_c_new = 0                   # voisins de couleur c_new
            for u in adjOf[v]
                if x[u] == c_new
                    nb_adj_c_new += 1
                end
            end
            delta = (c_new - c_old) + p * (nb_adj_c_new - nb_adj_c_old)

            # 3) critère de Metropolis
            if delta <= 0 || rand() < exp(-delta / T)

                # mise à jour des voisins
                for u in adjOf[v]
                    cu = x[u]
                    if cu == c_old
                        nbconf[u] -= 1
                        if nbconf[u] == 0
                            retirer_conflit!(conf_list, pos, u)
                        end
                    elseif cu == c_new
                        if nbconf[u] == 0
                            ajouter_conflit!(conf_list, pos, u)
                        end
                        nbconf[u] += 1
                    end
                end

                # mise à jour de v
                nbconf[v] = nb_adj_c_new
                if nb_adj_c_old > 0 && nb_adj_c_new == 0
                    retirer_conflit!(conf_list, pos, v)
                elseif nb_adj_c_old == 0 && nb_adj_c_new > 0
                    ajouter_conflit!(conf_list, pos, v)
                end

                # mise à jour globale
                x[v] = c_new

                nbColor[c_old] -= 1
                while length(nbColor) < c_new
                    push!(nbColor, 0)
                end

                nbColor[c_new] += 1
                if c_new > couleur_max
                    couleur_max = c_new
                end

                while nbColor[couleur_max] == 0
                    couleur_max -= 1
                end

                f_courant += delta
                if f_courant < best_f
                    best_x = copy(x)
                    best_f = f_courant
                end
            end

            if trace
                push!(valeurs_parcourues, f_courant)
                push!(best_f_par_iteration, best_f)
            end
        end

        T *= alpha
    end

    if trace
        return best_x, best_f, valeurs_parcourues, best_f_par_iteration
    else
        return best_x, best_f
    end
end

"""
    recuit_simule_swap(x0, adjOf, T0, Tmin, alpha, nbIter)

Recuit simulé avec le voisinage exchange swap. Les solutions explorées restent
réalisables si `x0` l'est : la fonction objectif est donc la somme des couleurs,
sans pénalité.

Renvoie `(best_x, best_f, valeurs_parcourues, best_f_par_iteration)`.
"""
function recuit_simule_swap(x0, adjOf, T0, Tmin, alpha, nbIter)
    evaluer = (x -> sum(x))

    x = copy(x0)
    f_courant = evaluer(x)

    best_x = copy(x)
    best_f = f_courant

    T = T0

    valeurs_parcourues = [f_courant]
    best_f_par_iteration = [best_f]

    while T > Tmin
        for _ in 1:nbIter
            x_new = voisinage_swap(x, adjOf)

            f_new = evaluer(x_new)
            delta = f_new - f_courant

            if delta <= 0 || rand() < exp(-delta / T)
                x = x_new
                f_courant = f_new

                if f_courant < best_f
                    best_x = copy(x)
                    best_f = f_courant
                end
            end

            push!(valeurs_parcourues, f_courant)
            push!(best_f_par_iteration, best_f)
        end

        T *= alpha
    end

    return best_x, best_f, valeurs_parcourues, best_f_par_iteration
end

"""
    voisinage_onemove(colorOf, adjOf)

Version naïve du voisinage one-move (algorithme 2 du rapport), en O(|E|).
Le recuit one-move utilise sa version incrémentale ; celle-ci ne sert plus
qu'à la calibration des températures (`calibrer_T`).
"""
function voisinage_onemove(colorOf::Vector{Int}, adjOf::Vector{Vector{Int}})
    conflict_vertices = Set{Int}()
    for (v, c) in enumerate(colorOf)
        for u in adjOf[v]
            if c == colorOf[u]
                push!(conflict_vertices, v)
                break
            end
        end
    end

    if !isempty(conflict_vertices)
        v = rand(collect(conflict_vertices))
    else
        v = rand(1:length(colorOf))
    end

    new_color = rand(1:maximum(colorOf)+1)

    x_new = copy(colorOf)
    x_new[v] = new_color

    return x_new
end

"""
    voisinage_swap(colorOf, adjOf)

Voisinage exchange swap (algorithme 4 du rapport) : échange les couleurs
`c1` et `c2` sur la composante connexe bicolore contenant un sommet tiré au
hasard.
"""
function voisinage_swap(colorOf, adjOf)
    v0 = rand(1:length(colorOf))

    while length(adjOf[v0]) == 0
        v0 = rand(1:length(colorOf))
    end

    c1 = colorOf[v0]
    c2 = colorOf[rand(adjOf[v0])]

    composante = composante_connexe(v0, c1, c2, colorOf, adjOf)
    x_new = copy(colorOf)
    for v in composante
        x_new[v] = (c1 == colorOf[v] ? c2 : c1)
    end

    return x_new
end

"""
    composante_connexe(v0, c1, c2, colorOf, adjOf)

Composante connexe contenant `v0` du sous-graphe induit par les sommets de
couleur `c1` ou `c2` (algorithme 3 du rapport).
"""
function composante_connexe(v0, c1, c2, colorOf::Vector{Int}, adjOf::Vector{Vector{Int}})
    waiting::Set{Int} = Set([v0])
    result::Set{Int} = Set([v0])

    while !isempty(waiting)
        v = first(waiting)
        for u in adjOf[v]
            if (colorOf[u] == c2 || colorOf[u] == c1) && !(u in result)
                push!(waiting, u)
            end
        end
        push!(result, v)
        delete!(waiting, v)
    end

    composante::Vector{Int} = collect(result)
    return composante
end
