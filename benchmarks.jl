# benchmarks.jl
#
# Best known values (lower/upper bounds f^b_LB, f^b_UB) reported in:
# Jin, Y., Hamiez, J.-P., Hao, J.-K. (2016). Algorithms for the minimum sum
# coloring problem: a review. Artificial Intelligence Review. Table 3 (Appendix).
#
# Key = instance name (name of the .col file without the extension).
# lb == ub  =>  proven optimum.
# lb <  ub  =>  ub is the best known solution, but the gap with lb is still
#               open (the optimum could be anywhere between the two).

const BEST_KNOWN_VALUES = Dict{String, NamedTuple{(:lb, :ub), Tuple{Int,Int}}}(
    "myciel3"        => (lb=16,    ub=21),
    "myciel4"        => (lb=34,    ub=45),
    "myciel5"        => (lb=70,    ub=93),
    "myciel6"        => (lb=142,   ub=189),
    "myciel7"        => (lb=286,   ub=381),
    "anna"           => (lb=273,   ub=276),
    "david"          => (lb=234,   ub=237),
    "huck"           => (lb=243,   ub=243),
    "jean"           => (lb=216,   ub=217),
    "homer"          => (lb=1129,  ub=1150),
    "queen5_5"       => (lb=75,    ub=75),
    "queen6_6"       => (lb=126,   ub=138),
    "queen7_7"       => (lb=196,   ub=196),
    "queen8_8"       => (lb=288,   ub=291),
    "queen8_12"      => (lb=624,   ub=624),
    "queen9_9"       => (lb=405,   ub=409),
    "queen10_10"     => (lb=550,   ub=553),
    "queen11_11"     => (lb=726,   ub=733),
    "queen12_12"     => (lb=936,   ub=943),
    "queen13_13"     => (lb=1183,  ub=1191),
    "queen14_14"     => (lb=1470,  ub=1482),
    "queen15_15"     => (lb=1800,  ub=1814),
    "queen16_16"     => (lb=2176,  ub=2193),
    "school1"        => (lb=2439,  ub=2674),
    "school1-nsh"    => (lb=2176,  ub=2392),
    "miles250"       => (lb=318,   ub=325),
    "miles500"       => (lb=686,   ub=705),
    "miles750"       => (lb=1145,  ub=1173),
    "miles1000"      => (lb=1623,  ub=1666),
    "miles1500"      => (lb=3239,  ub=3354),
    "fpsol2_i_1"     => (lb=3403,  ub=3403),
    "fpsol2_i_2"     => (lb=1668,  ub=1668),
    "fpsol2_i_3"     => (lb=1636,  ub=1636),
    "mug88_1"        => (lb=164,   ub=178),
    "mug88_25"       => (lb=162,   ub=178),
    "mug100_1"       => (lb=188,   ub=202),
    "mug100_25"      => (lb=186,   ub=202),
    "2-Insert_3"     => (lb=55,    ub=62),
    "3-Insert_3"     => (lb=84,    ub=92),
    "inithx_i_1"     => (lb=3676,  ub=3676),
    "inithx_i_2"     => (lb=2050,  ub=2050),
    "inithx_i_3"     => (lb=1986,  ub=1986),
    "mulsol_i_1"     => (lb=1957,  ub=1957),
    "mulsol_i_2"     => (lb=1191,  ub=1191),
    "mulsol_i_3"     => (lb=1187,  ub=1187),
    "mulsol_i_4"     => (lb=1189,  ub=1189),
    "mulsol_i_5"     => (lb=1160,  ub=1160),
    "zeroin_i_1"     => (lb=1822,  ub=1822),
    "zeroin_i_2"     => (lb=1004,  ub=1004),
    "zeroin_i_3"     => (lb=998,   ub=998),
    "wap05"          => (lb=12449, ub=13656),
    "wap06"          => (lb=12454, ub=13773),
    "wap07"          => (lb=24800, ub=28617),
    "wap08"          => (lb=25283, ub=28885),
    "qg_order30"     => (lb=13950, ub=13950),
    "qg_order40"     => (lb=32800, ub=32800),
    "qg_order60"     => (lb=109800,ub=109800),
    "DSJC125_1"      => (lb=247,   ub=326),
    "DSJC125_5"      => (lb=549,   ub=1012),
    "DSJC125_9"      => (lb=1691,  ub=2503),
    "DSJC250_1"      => (lb=570,   ub=970),
    "DSJC250_5"      => (lb=1287,  ub=3210),
    "DSJC250_9"      => (lb=4311,  ub=8277),
    "DSJC500_1"      => (lb=1250,  ub=2836),
    "DSJC500_5"      => (lb=2923,  ub=10886),
    "DSJC500_9"      => (lb=11053, ub=29862),
    "DSJC1000_1"     => (lb=2762,  ub=8991),
    "DSJC1000_5"     => (lb=6708,  ub=37575),
    "DSJC1000_9"     => (lb=26557, ub=103445),
    "DSJR500_1"      => (lb=2069,  ub=2156),
    "DSJR500_1c"     => (lb=15398, ub=16286),
    "DSJR500_5"      => (lb=22974, ub=25440),
    "flat300_20_0"   => (lb=1531,  ub=3150),
    "flat300_26_0"   => (lb=1548,  ub=3966),
    "flat300_28_0"   => (lb=1547,  ub=4238),
    "flat1000_50_0"  => (lb=6601,  ub=25500),
    "flat1000_60_0"  => (lb=6640,  ub=30100),
    "flat1000_76_0"  => (lb=6632,  ub=37164),
    "le450_5a"       => (lb=1193,  ub=1350),
    "le450_5b"       => (lb=1189,  ub=1350),
    "le450_5c"       => (lb=1278,  ub=1350),
    "le450_5d"       => (lb=1282,  ub=1350),
    "le450_15a"      => (lb=2331,  ub=2632),
    "le450_15b"      => (lb=2348,  ub=2632),
    "le450_15c"      => (lb=2610,  ub=3487),
    "le450_15d"      => (lb=2628,  ub=3505),
    "le450_25a"      => (lb=3003,  ub=3153),
    "le450_25b"      => (lb=3305,  ub=3365),
    "le450_25c"      => (lb=3657,  ub=4515),
    "le450_25d"      => (lb=3698,  ub=4544),
    "latin_sqr_10"   => (lb=40950, ub=41444),
    "C2000_5"        => (lb=15091, ub=132483),
    "C4000_5"        => (lb=33033, ub=473234),
    "games120"       => (lb=442,   ub=443),
)


"""
    compare_to_best_known(instance_name, f_obtained, f_initial, results_file)

Compares `f_obtained` with the best known bounds of the instance, prints the
summary and appends it to `results_file`.
"""
function compare_to_best_known(instance_name::String, f_obtained::Int,
                               f_initial::Int,
                               results_file::String)
    messages = String[]
    add_message(message) = push!(messages, message)

    if !haskey(BEST_KNOWN_VALUES, instance_name)
        add_message("Instance \"$instance_name\" not found in the reference table (check the instance name).")
    else
        lb, ub = BEST_KNOWN_VALUES[instance_name]
        proven_optimal = (lb == ub)

        add_message("Instance                      : $instance_name")
        add_message("Greedy start                  : $f_initial")
        add_message("Result obtained               : $f_obtained")

        add_message("Best known UB                 : $ub" * (proven_optimal ? " (proven optimum)" : ""))
        add_message("Best known LB                 : $lb")

        if f_obtained < lb
            add_message("⚠ Result below the theoretical LB: the coloring is probably not valid (conflicts)!")
        elseif f_obtained == ub
            add_message(proven_optimal ? "✓ Proven optimum reached." : "✓ Best published value matched.")
        elseif f_obtained < ub
            add_message("★ Solution better than the best published value!")
        else
            gap = f_obtained - ub
            percentage = round(100 * gap / ub, digits=2)
            add_message("Gap to the best known UB : +$gap ($percentage %)")
        end
    end

    content = join(messages, "\n") * "\n"
    print(stdout, content)
    flush(stdout)
    open(results_file, "a") do file
        print(file, content)
    end
end
