# Simulated Annealing for the Minimum Sum Coloring Problem (MSCP)

Metaheuristics project (Université d'Angers), Quentin HÛ.

This program solves the *Minimum Sum Coloring Problem*: find a valid coloring
of a graph (two adjacent vertices never share the same color) that minimizes
the sum of the colors assigned to the vertices. The method works in two steps:

1. **Greedy construction** of an initial solution with DSATUR (or its
   randomized variant `randDSATUR` for the multi-start);
2. **Improvement by simulated annealing**, with a choice of two neighborhoods:
   - `onemove`: recolors a single vertex (preferably a conflicting one), with
     a penalty on conflicts and incremental evaluation;
   - `swap`: swaps the two colors of a two-colored connected component (Kempe
     chain), which stays within the space of feasible solutions.

The method and the analysis of the results are detailed in the report
[`HU_Quentin_Metaheuristiques.pdf`](HU_Quentin_Metaheuristiques.pdf), at the
root of the project. **The report is written in French.**

---

## Table of contents

0. [Use of AI](#0-use-of-ai)
1. [Project structure](#1-project-structure)
2. [Installation](#2-installation)
3. [Running the program](#3-running-the-program)
4. [Detailed usage](#4-detailed-usage)
5. [Output files](#5-output-files)
6. [Reproducing the results of the report](#6-reproducing-the-results-of-the-report)
7. [Using other instances](#7-using-other-instances)
8. [Troubleshooting](#8-troubleshooting)

---

## 0. Use of AI

All the metaheuristic algorithms developed here were designed and written by
hand. The use of AI (LLM) was limited to writing the parser, auxiliary
functions and this README, to detecting errors, inconsistencies and poor
variable naming, and to translating the code and the README into English.

## 1. Project structure

```
Project/
├── Main.jl          Entry point: run_experiments and multi_start
├── greedy.jl        DSATUR and randDSATUR (initial solution)
├── annealing.jl     Simulated annealing (incremental one-move, swap) and neighborhoods
├── utils.jl         Reading .col files, adjacency lists, coloring validity,
│                    calibration of T0 and Tmin
├── benchmarks.jl    Best known bounds from the literature (Jin et al., 2016)
├── graphics.jl      Figures (objective function evolution, multi-start)
├── Project.toml     Julia dependencies of the project
├── README.md        This file
├── HU_Quentin_Metaheuristiques.pdf   Project report (in French)
├── Instances/       Test instances in DIMACS format (.col)
├── results/         Results (CSV, multi-start summaries)
└── plots/           Generated figures
    ├── single/      Objective function evolution during an annealing run
    └── multiple/    Multi-start visualization
```

Mapping between the algorithms of the report (in French) and the code. The
report was written before the code was translated into English, so it uses
the former file names: `glouton.jl` is now `greedy.jl`, and `recuit.jl`
(called `recuit_rapide.jl` in the report) is now `annealing.jl`.

| Report (French)                                     | Code                                               |
|-----------------------------------------------------|----------------------------------------------------|
| Algorithme 1 – DSATUR                               | `DSATUR` (`greedy.jl`)                             |
| Algorithme 2 – voisinage one-move (naive version)   | `neighbor_onemove` (`annealing.jl`)                |
| Algorithme 3 – composante connexe                   | `connected_component` (`annealing.jl`)             |
| Algorithme 4 – voisinage swap                       | `neighbor_swap` (`annealing.jl`)                   |
| Section 3.3.4 – calibration of T0 and Tmin          | `calibrate_temperatures` (`utils.jl`)              |
| Algorithme 5 – recuit simulé (swap)                 | `simulated_annealing_swap` (`annealing.jl`)        |
| Algorithme 6 – incremental one-move annealing       | `simulated_annealing_onemove_fast` (`annealing.jl`)|
| Section 4.3 – multi-start / randDSATUR              | `multi_start` (`Main.jl`), `randDSATUR`            |

---

## 2. Installation

### 2.1 Installing Julia

The code was developed and tested with **Julia 1.12** and works with Julia
1.10 or later. The recommended way to install Julia is **juliaup**, the
official installer:

- **Linux and macOS** (in a terminal):

  ```bash
  curl -fsSL https://install.julialang.org | sh
  ```

  Close and reopen the terminal so that the `julia` command is found.

- **Windows** (in PowerShell or the command prompt):

  ```
  winget install --name Julia --id 9NJNWW8PVKMN -e -s msstore
  ```

  Julia can also be installed from the Microsoft Store ("Julia" app).

- Alternatively, download the installer from
  <https://julialang.org/downloads/>.

Then check the installation:

```bash
julia --version
```

The command should print version 1.10 or later.

### 2.2 Installing the dependencies

The dependencies are declared in `Project.toml`:

| Package      | Purpose                                           |
|--------------|---------------------------------------------------|
| `Plots`      | Figure generation (GR backend)                    |
| `Random`     | Random draws, seed (standard library)             |
| `Statistics` | Mean and standard deviation (standard library)    |

Go **to the project folder** (the one containing `Main.jl`) and run once:

```bash
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

This command downloads and precompiles the packages in an environment specific
to the project, without touching your global installation. An Internet
connection is required. The first installation of `Plots` can take **several
minutes** (precompilation), which is normal.

---

## 3. Running the program

All commands must be run **from the project folder**, because the paths
`Instances/`, `results/` and `plots/` are relative to this folder.

### 3.1 From the Julia REPL (recommended)

```bash
julia --project=.
```

Then, in the REPL:

```julia
include("Main.jl")

# One-move annealing, 10 runs on queen5_5
run_experiments(["queen5_5"])

# Swap annealing on several instances
run_experiments(["queen7_7", "huck", "myciel4"]; moveType = "swap")

# One-move multi-start
multi_start(["anna", "david"]; n_starts = 100)
```

The first `include("Main.jl")` takes a few seconds (loading `Plots`). The
REPL then keeps the compiled code, which makes subsequent calls faster.

### 3.2 As a single command

```bash
julia --project=. -e 'include("Main.jl"); run_experiments(["queen5_5", "huck"]; n_runs = 5, seed = 1)'
```

On Windows (PowerShell / cmd), swap the quotes:

```
julia --project=. -e "include(\"Main.jl\"); run_experiments([\"queen5_5\"]; n_runs = 5)"
```

---

## 4. Detailed usage

Instance names are the names of the files in `Instances/` **without the
`.col` extension**:

| Instance     | \|V\| | \|E\|   | Best known upper bound |
|--------------|------:|--------:|-----------------------:|
| `queen5_5`   | 25    | 160     | 75 (proven optimum)    |
| `queen7_7`   | 49    | 476     | 196 (proven optimum)   |
| `queen8_12`  | 96    | 1,368   | 624 (proven optimum)   |
| `huck`       | 74    | 301     | 243 (proven optimum)   |
| `games120`   | 120   | 638     | 443                    |
| `anna`       | 138   | 493     | 276                    |
| `david`      | 87    | 406     | 237                    |
| `myciel4`    | 23    | 71      | 45                     |
| `le450_25c`  | 450   | 17,343  | 4,515                  |
| `DSJC500_5`  | 500   | 62,624  | 10,886                 |
| `DSJC1000_9` | 1,000 | 449,449 | 103,445                |

### 4.1 `run_experiments`: simulated annealing over several runs

```julia
run_experiments(instances::Vector{String}; kwargs...)
```

For each instance and each of the `n_runs` runs: greedy construction,
calibration of `T0` and `Tmin`, simulated annealing, then validity check of
the coloring. One line is printed per run, followed by a summary per instance
(minimum, mean and standard deviation of z). The function also returns the
list of results as `NamedTuple`s.

| Keyword argument | Default                        | Description |
|------------------|--------------------------------|-------------|
| `moveType`       | `"onemove"`                    | Neighborhood: `"onemove"` or `"swap"` |
| `n_runs`         | `10`                           | Number of runs per instance |
| `greedy`         | `DSATUR`                       | Initial greedy algorithm: `DSATUR` or `randDSATUR` |
| `K`              | `1500`                         | Number of temperature levels |
| `nbIter`         | `600`                          | Iterations per temperature level |
| `p_init`         | `0.5`                          | Probability of accepting a mean degradation at `T0` |
| `p_final`        | `0.0001`                       | Probability of accepting a mean degradation at `Tmin` |
| `path`           | `name -> "Instances/$name.col"`| Function giving the file path of an instance |
| `seed`           | `nothing`                      | Random seed (integer) to make a run reproducible |
| `chain_swap`     | `false`                        | Chains a second swap annealing (K/2 levels, nbIter/2 iterations) after each run. Not used in the report, and not counted in the measured time |
| `save_plot`      | `false`                        | Saves the objective function evolution of the 1st run to `plots/single/` |

The penalty per conflicting edge (one-move neighborhood) is `p = n + 1`.

Examples:

```julia
# Reproducible, with the objective function evolution plot
run_experiments(["queen7_7"]; moveType = "onemove", seed = 42, save_plot = true)

# Longer annealing
run_experiments(["le450_25c"]; K = 3000, nbIter = 1000, n_runs = 3)

# Instance stored in another folder
run_experiments(["my_graph"]; path = name -> "data/$name.col", n_runs = 5)
```

### 4.2 `multi_start`: annealing from several initial solutions

```julia
multi_start(instances::Vector{String}; kwargs...)
```

For each instance, runs `n_starts` annealings, each from a different initial
solution built by `randDSATUR` (vertex drawn at random among the 10 % with the
highest saturation degree). The best value obtained is compared with the
bounds from the literature, then a figure is saved: a black dot for each
initial solution, a red dot for the value obtained after annealing.

| Keyword argument     | Default                        | Description |
|----------------------|--------------------------------|-------------|
| `moveType`           | `"onemove"`                    | `"onemove"` or `"swap"` |
| `n_starts`           | `10`                           | Number of starts |
| `K`, `nbIter`        | `1500`, `600`                  | Cooling schedule |
| `p_init`, `p_final`  | `0.5`, `0.0001`                | Temperature calibration |
| `path`               | `name -> "Instances/$name.col"`| Instance file path |
| `seed`               | `nothing`                      | Random seed |

### 4.3 Lower-level functions

The building blocks of the algorithm can also be called directly:

```julia
include("Main.jl")
edges, n = read_instance("Instances/huck.col")
adjOf = adjacency_lists(edges, n)

x0 = DSATUR(n, adjOf)                     # initial coloring (vector of colors)
sum(x0), isValid(x0, adjOf)               # value and validity

T0, Tmin = calibrate_temperatures(x0, adjOf, n, 0.5, 0.0001, "onemove")
alpha = (Tmin / T0)^(1 / 1500)
x_best, f_best, values, best_values = simulated_annealing_onemove_fast(x0, adjOf, T0, Tmin, n + 1, alpha, 600)
x_best, f_best, values, best_values = simulated_annealing_swap(x0, adjOf, T0, Tmin, alpha, 600)

compare_to_best_known("huck", sum(x_best), sum(x0), "results/test.txt")
```

---

## 5. Output files

The `results/` and `plots/` folders are created automatically if they do not exist.

| File                                            | Produced by        | Content |
|-------------------------------------------------|--------------------|---------|
| `results/raw_results_<moveType>.csv`            | `run_experiments`  | One line per run: `instance, moveType, run, nbIter, K, n_edges, z0, z, valid, time_s`. **The file is overwritten at each call** |
| `plots/single/<moveType>_evolution_z_<name>.png`| `run_experiments` (`save_plot = true`) | Current value (blue) and best value (red) at each iteration |
| `results/multiple_<name>.txt`                   | `multi_start`      | Summary compared with the bounds from the literature. **Appended to the file** at each call |
| `plots/multiple/<name>.png`                     | `multi_start`      | Multi-start visualization |

In the CSV, `z0` is the value of the greedy solution, `z` the value of the
best solution found, `valid` indicates the absence of conflicts and `time_s`
is the time (greedy + calibration + annealing) in seconds.

The files already present in `results/` are examples produced with
`run_experiments(["queen5_5"])` and `multi_start(["queen5_5"])`. The figures
in `plots/` are those of the report (in French), except
`plots/multiple/queen5_5.png`, which was regenerated with the English version.

---

## 6. Reproducing the results of the report

The parameters of the report (Table 2 of the French report) are the default
values: `K = 1500`, `nbIter = 600`, `p_init = 0.5`, `p_final = 0.0001`,
`p = n + 1`.

```julia
include("Main.jl")
instances = ["queen5_5", "queen7_7", "queen8_12", "huck", "games120", "anna",
             "david", "myciel4", "le450_25c", "DSJC500_5", "DSJC1000_9"]

# Tables 3 and 4: 10 runs per instance
run_experiments(instances; moveType = "onemove", n_runs = 10)
run_experiments(instances; moveType = "swap",    n_runs = 10)

# Tables 5 and 6: multi-start (100 starts with one-move, 10 with swap)
multi_start(instances; moveType = "onemove", n_starts = 100)
multi_start(instances; moveType = "swap",    n_starts = 10)
```

Simulated annealing is stochastic, so the values obtained vary from one run
to another (use `seed` to fix the draws). Running times depend on the
machine. As a rough guide, a run takes less than one second with one-move on
small instances, about 5 s on `DSJC1000_9`, and 1 to 12 s with swap. The
one-move multi-start with 100 starts on all instances therefore takes several
minutes.

---

## 7. Using other instances

The program reads the standard DIMACS format (`.col`):

```
c comment lines
p edge <number_of_vertices> <number_of_edges>
e 1 2
e 1 3
...
```

Vertices are numbered from 1. Duplicate edges (listed in both directions) and
self-loops are ignored. Other instances are available, for example, at
<https://mat.tepper.cmu.edu/COLOR/instances.html>. Just put the file in
`Instances/` and call the program with its name without the extension. If the
instance is listed in `benchmarks.jl`, `multi_start` compares it with the
best known bounds. Otherwise, a message says so and the rest of the program
works normally.

---

## 8. Troubleshooting

- **`ERROR: ArgumentError: Package Plots not found`**: Julia was not started
  with the project environment. Use `julia --project=.` from the project
  folder, and run `Pkg.instantiate()` once beforehand (section 2.2).
- **`SystemError: opening file "Instances/....col"`**: Julia was not started
  from the project folder, or the instance name is misspelled (do not include
  the `.col` extension). In the REPL, `pwd()` prints the current folder and
  `cd("path/to/Project")` changes it.
- **`QPainterPath::arcTo: ... NaN` message** during `multi_start`: harmless
  warning from the GR backend, emitted when an arrow has zero length (start
  already equal to the final result). The figure is still saved.
- **Machine without a display (server, SSH)**: if GR causes problems, run
  `ENV["GKSwstype"] = "100"` before `include("Main.jl")` to generate the
  figures without opening a window.
