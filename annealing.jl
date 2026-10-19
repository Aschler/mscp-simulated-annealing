# annealing.jl
#
# Simulated annealing for the MSCP with two neighborhoods:
#   - one-move with incremental evaluation (appendix A.1 of the report, written in French);
#   - exchange swap (Kempe chains), which stays within the feasible space.

"""
    simulated_annealing_onemove_fast(x0, adjOf, T0, Tmin, p, alpha, nbIter; trace = true)

Simulated annealing with the one-move neighborhood and the penalized objective
function `f_p(x) = Σ x[v] + p · (number of conflicting edges)`, evaluated
incrementally in O(deg(v)) per iteration.

Returns `(best_x, best_f, visited_values, best_f_history)` if `trace` is true,
`(best_x, best_f)` otherwise.
"""
function simulated_annealing_onemove_fast(x0, adjOf, T0, Tmin, p, alpha, nbIter; trace = true)
    function add_conflict!(conflict_list, pos, v)
        push!(conflict_list, v)
        pos[v] = length(conflict_list)
    end

    function remove_conflict!(conflict_list, pos, v)
        i = pos[v]
        last_vertex = conflict_list[end]
        conflict_list[i] = last_vertex
        pos[last_vertex] = i
        pop!(conflict_list)
        pos[v] = 0
    end

    n = length(x0)
    x = copy(x0)

    # ---------- incrementally maintained state ----------
    color_sum = sum(x)

    # nb_conflicts[v] = number of neighbors of v sharing the color of v
    nb_conflicts = zeros(Int, n)
    for v in 1:n
        for u in adjOf[v]
            if x[u] == x[v]
                nb_conflicts[v] += 1
            end
        end
    end
    # each conflicting edge is counted by both of its endpoints
    nb_conflict_edges = sum(nb_conflicts) ÷ 2

    # set of conflicting vertices (nb_conflicts[v] > 0), with O(1) uniform sampling
    conflict_list = Int[]
    pos = zeros(Int, n)        # pos[v] = position of v in conflict_list (0 if absent)
    for v in 1:n
        if nb_conflicts[v] > 0
            add_conflict!(conflict_list, pos, v)
        end
    end

    # color_count[c] = number of vertices with color c, used to track the maximum color
    color_count = zeros(Int, maximum(x) + 2)
    for c in x
        color_count[c] += 1
    end
    max_color = maximum(x)

    # ---------- annealing loop ----------
    f_current = color_sum + p * nb_conflict_edges
    best_x = copy(x)
    best_f = f_current

    T = T0

    if trace
        visited_values = [f_current]
        best_f_history = [best_f]
    end

    while T > Tmin
        for _ in 1:nbIter
            # 1) draw the move (c_new is drawn different from c_old)
            v = isempty(conflict_list) ? rand(1:n) : rand(conflict_list)
            c_old = x[v]
            c_new = rand(1:max_color + 1)

            while c_new == c_old
                c_new = rand(1:max_color + 1)
            end

            # 2) delta computation
            nb_adj_c_old = nb_conflicts[v]     # neighbors with color c_old
            nb_adj_c_new = 0                   # neighbors with color c_new
            for u in adjOf[v]
                if x[u] == c_new
                    nb_adj_c_new += 1
                end
            end
            delta = (c_new - c_old) + p * (nb_adj_c_new - nb_adj_c_old)

            # 3) Metropolis criterion
            if delta <= 0 || rand() < exp(-delta / T)

                # update the neighbors
                for u in adjOf[v]
                    cu = x[u]
                    if cu == c_old
                        nb_conflicts[u] -= 1
                        if nb_conflicts[u] == 0
                            remove_conflict!(conflict_list, pos, u)
                        end
                    elseif cu == c_new
                        if nb_conflicts[u] == 0
                            add_conflict!(conflict_list, pos, u)
                        end
                        nb_conflicts[u] += 1
                    end
                end

                # update v
                nb_conflicts[v] = nb_adj_c_new
                if nb_adj_c_old > 0 && nb_adj_c_new == 0
                    remove_conflict!(conflict_list, pos, v)
                elseif nb_adj_c_old == 0 && nb_adj_c_new > 0
                    add_conflict!(conflict_list, pos, v)
                end

                # global update
                x[v] = c_new

                color_count[c_old] -= 1
                while length(color_count) < c_new
                    push!(color_count, 0)
                end

                color_count[c_new] += 1
                if c_new > max_color
                    max_color = c_new
                end

                while color_count[max_color] == 0
                    max_color -= 1
                end

                f_current += delta
                if f_current < best_f
                    best_x = copy(x)
                    best_f = f_current
                end
            end

            if trace
                push!(visited_values, f_current)
                push!(best_f_history, best_f)
            end
        end

        T *= alpha
    end

    if trace
        return best_x, best_f, visited_values, best_f_history
    else
        return best_x, best_f
    end
end

"""
    simulated_annealing_swap(x0, adjOf, T0, Tmin, alpha, nbIter)

Simulated annealing with the exchange swap neighborhood. Explored solutions
remain feasible if `x0` is feasible, so the objective function is the sum of
the colors, without penalty.

Returns `(best_x, best_f, visited_values, best_f_history)`.
"""
function simulated_annealing_swap(x0, adjOf, T0, Tmin, alpha, nbIter)
    evaluate = (x -> sum(x))

    x = copy(x0)
    f_current = evaluate(x)

    best_x = copy(x)
    best_f = f_current

    T = T0

    visited_values = [f_current]
    best_f_history = [best_f]

    while T > Tmin
        for _ in 1:nbIter
            x_new = neighbor_swap(x, adjOf)

            f_new = evaluate(x_new)
            delta = f_new - f_current

            if delta <= 0 || rand() < exp(-delta / T)
                x = x_new
                f_current = f_new

                if f_current < best_f
                    best_x = copy(x)
                    best_f = f_current
                end
            end

            push!(visited_values, f_current)
            push!(best_f_history, best_f)
        end

        T *= alpha
    end

    return best_x, best_f, visited_values, best_f_history
end

"""
    neighbor_onemove(colorOf, adjOf)

Naive version of the one-move neighborhood (algorithm 2 of the report), in
O(|E|). The one-move annealing uses its incremental version; this one is only
used to calibrate the temperatures (`calibrate_temperatures`).
"""
function neighbor_onemove(colorOf::Vector{Int}, adjOf::Vector{Vector{Int}})
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
    neighbor_swap(colorOf, adjOf)

Exchange swap neighborhood (algorithm 4 of the report): swaps colors `c1` and
`c2` on the two-colored connected component containing a randomly drawn vertex.
"""
function neighbor_swap(colorOf, adjOf)
    v0 = rand(1:length(colorOf))

    while length(adjOf[v0]) == 0
        v0 = rand(1:length(colorOf))
    end

    c1 = colorOf[v0]
    c2 = colorOf[rand(adjOf[v0])]

    component = connected_component(v0, c1, c2, colorOf, adjOf)
    x_new = copy(colorOf)
    for v in component
        x_new[v] = (c1 == colorOf[v] ? c2 : c1)
    end

    return x_new
end

"""
    connected_component(v0, c1, c2, colorOf, adjOf)

Connected component containing `v0` in the subgraph induced by the vertices of
color `c1` or `c2` (algorithm 3 of the report).
"""
function connected_component(v0, c1, c2, colorOf::Vector{Int}, adjOf::Vector{Vector{Int}})
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

    component::Vector{Int} = collect(result)
    return component
end
