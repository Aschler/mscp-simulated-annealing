# greedy.jl
#
# Initial solution construction with the DSATUR and randDSATUR greedy algorithms.

"""
    dsat(v, colorOf, adjOf)

Saturation degree of `v`: number of distinct colors already assigned to its
neighbors (color 0 means "uncolored").
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

Smallest color (≥ 1) that does not appear in `neighborColors`.
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

Randomized DSATUR: at each step, the vertex to color is drawn uniformly among
the 10 % of uncolored vertices with the highest saturation degree. Used by the
multi-start.
"""
function randDSATUR(n, adjOf)
    colorOf::Vector{Int} = zeros(Int, n)

    uncolored = Set(1:n)

    while !isempty(uncolored)
        verticesByDsat = Tuple{Int, Int}[]
        for v in uncolored
            dSat = dsat(v, colorOf, adjOf)
            push!(verticesByDsat, (dSat, v))
        end

        sort!(verticesByDsat, by = pair -> pair[1], rev = true)
        topVertices = verticesByDsat[1:max(1, floor(Int, length(verticesByDsat)/10))]
        bestVertex = rand(topVertices)[2]

        neighborColors = [colorOf[u] for u in adjOf[bestVertex] if colorOf[u] != 0]
        colorOf[bestVertex] = minAvailableColor(neighborColors)

        delete!(uncolored, bestVertex)
    end

    return colorOf
end

"""
    DSATUR(n, adjOf)

DSATUR greedy algorithm (Brélaz, 1979): at each step, colors the uncolored
vertex with the highest saturation degree using the smallest available color.
"""
function DSATUR(n, adjOf)
    colorOf::Vector{Int} = zeros(Int, n)

    uncolored = Set(1:n)

    while !isempty(uncolored)
        maxDsat = -1
        bestVertex = -1
        for v in uncolored
            dSat = dsat(v, colorOf, adjOf)
            if dSat > maxDsat
                maxDsat = dSat
                bestVertex = v
            end
        end

        neighborColors = [colorOf[u] for u in adjOf[bestVertex] if colorOf[u] != 0]
        colorOf[bestVertex] = minAvailableColor(neighborColors)

        delete!(uncolored, bestVertex)
    end

    return colorOf
end
