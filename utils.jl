# utils.jl
#
# Instance reading, graph structures, coloring validity check and calibration
# of the simulated annealing temperatures.

"""
    isValid(colorOf, adjOf)

True if no edge connects two vertices of the same color.
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
    calibrate_temperatures(x, adjOf, n_samples, p_init, p_final, moveType)

Computes `T0` and `Tmin` from the mean degradation observed on
`max(100, n_samples)` neighbors of `x` (without penalty), so that a mean
degradation is accepted with probability `p_init` at the start and `p_final`
at the end. Returns `(nothing, nothing)` if no degrading neighbor was observed.
"""
function calibrate_temperatures(x, adjOf, n_samples, p_init, p_final,
                                moveType::String = "onemove")
    neighbor = moveType == "onemove" ? neighbor_onemove : neighbor_swap

    positive_deltas = Int[]
    f_ref = sum(x)
    for _ in 1:max(100, n_samples)
        x_new = neighbor(x, adjOf)
        delta = sum(x_new) - f_ref
        if delta > 0
            push!(positive_deltas, delta)
        end
    end

    if isempty(positive_deltas)
        return nothing, nothing
    end

    mean_delta = mean(positive_deltas)
    T0   = -mean_delta / log(p_init)
    Tmin = -mean_delta / log(p_final)
    return T0, Tmin
end

"""
    adjacency_lists(edges, n)

Adjacency lists of an undirected graph with `n` vertices.
"""
function adjacency_lists(edges, n)::Vector{Vector{Int}}
    adjOf::Vector{Vector{Int}} = [Int[] for _ in 1:n]

    for (u, v) in edges
        push!(adjOf[u], v)
        push!(adjOf[v], u)
    end
    return adjOf
end

"""
    read_instance(filename)

Reads a DIMACS file (`.col`) and returns `(edges, n)`.
"""
function read_instance(filename::String)
    # DIMACS files (.col) sometimes list each edge in both directions
    # ("e 1 2" then "e 2 1"), in which case the header "p edge n m" counts
    # m = 2 x |E|. Each edge is normalized as (min, max), self-loops are ignored
    # and duplicates removed so that each actual edge appears only once.
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
