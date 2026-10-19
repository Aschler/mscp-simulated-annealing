# glouton.jl
#
# Construction d'une solution initiale par les gloutons DSATUR et randDSATUR.

"""
    dsat(v, colorOf, adjOf)

Degré de saturation de `v` : nombre de couleurs distinctes déjà attribuées
à ses voisins (la couleur 0 signifie « non coloré »).
"""
function dsat(v, colorOf::Vector{Int}, adjOf::Vector{Vector{Int}})::Int
    usedColors = Set{Int}()

    for u in adjOf[v]
        c = colorOf[u]
        if c != 0
            push!(usedColors, c)
        end
    end

    return length(usedColors)
end

"""
    minAvailableColor(neighborColors)

Plus petite couleur (≥ 1) absente de `neighborColors`.
"""
function minAvailableColor(neighborColors::Vector{Int})::Int
    color::Int = 1
    usedColors::Set{Int} = Set(neighborColors)

    while color in usedColors
        color += 1
    end

    return color
end

"""
    randDSATUR(n, adjOf)

Variante aléatoire de DSATUR : à chaque étape, le sommet à colorier est tiré
uniformément parmi les 10 % de sommets non colorés de plus grand degré de
saturation. Utilisée pour le multi-start.
"""
function randDSATUR(n, adjOf)
    colorOf::Vector{Int} = zeros(Int, n)

    unColored = Set(1:n)

    while !isempty(unColored)
        verticesByDsat = Tuple{Int, Int}[]
        for v in unColored
            dSat = dsat(v, colorOf, adjOf)
            push!(verticesByDsat, (dSat, v))
        end

        sort!(verticesByDsat, by = pair -> pair[1], rev = true)
        topVertices = verticesByDsat[1:max(1, floor(Int, length(verticesByDsat)/10))]
        bestVertex = rand(topVertices)[2]

        neighborColors = [colorOf[u] for u in adjOf[bestVertex] if colorOf[u] != 0]
        colorOf[bestVertex] = minAvailableColor(neighborColors)

        delete!(unColored, bestVertex)
    end

    return colorOf
end

"""
    DSATUR(n, adjOf)

Glouton DSATUR (Brélaz, 1979) : colorie à chaque étape le sommet non coloré
de plus grand degré de saturation avec la plus petite couleur disponible.
"""
function DSATUR(n, adjOf)
    colorOf::Vector{Int} = zeros(Int, n)

    unColored = Set(1:n)

    while !isempty(unColored)
        maxDsat = -1
        bestVertex = -1
        for v in unColored
            dSat = dsat(v, colorOf, adjOf)
            if dSat > maxDsat
                maxDsat = dSat
                bestVertex = v
            end
        end

        neighborColors = [colorOf[u] for u in adjOf[bestVertex] if colorOf[u] != 0]
        colorOf[bestVertex] = minAvailableColor(neighborColors)

        delete!(unColored, bestVertex)
    end

    return colorOf
end
