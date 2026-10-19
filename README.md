# Recuit simulé pour le problème de coloration de somme minimale (MSCP)

Projet de Métaheuristiques (Université d'Angers), Quentin HÛ.

Ce programme résout le *Minimum Sum Coloring Problem* : trouver une coloration
valide d'un graphe (deux sommets adjacents n'ont jamais la même couleur) qui
minimise la somme des couleurs attribuées aux sommets. La méthode se fait en
deux étapes :

1. **Construction gloutonne** d'une solution initiale par DSATUR (ou sa
   variante aléatoire `randDSATUR` pour le multi-start) ;
2. **Amélioration par recuit simulé**, avec au choix deux voisinages :
   - `onemove` : changement de couleur d'un sommet (de préférence en conflit),
     avec pénalisation des conflits et évaluation incrémentale ;
   - `swap` : échange des deux couleurs d'une composante connexe bicolore
     (chaîne de Kempe), qui reste dans l'espace des solutions réalisables.

Le détail de la méthode et l'analyse des résultats se trouvent dans le rapport
[`HU_Quentin_Metaheuristiques.pdf`](HU_Quentin_Metaheuristiques.pdf), à la racine du projet.

---

## Sommaire

0. [Utilisation de l'IA](#0-utilisation-de-lia)
1. [Structure du projet](#1-structure-du-projet)
2. [Installation](#2-installation)
3. [Lancer le programme](#3-lancer-le-programme)
4. [Utilisation détaillée](#4-utilisation-détaillée)
5. [Fichiers produits](#5-fichiers-produits)
6. [Reproduire les résultats du rapport](#6-reproduire-les-résultats-du-rapport)
7. [Utiliser d'autres instances](#7-utiliser-dautres-instances)
8. [Problèmes fréquents](#8-problèmes-fréquents)

---

## 0. Utilisation de l'IA

L'entiereté des algorithmes concernant les métaheuristiques développés ici ont été conçus et écrits à la main. L'utilisation de l'IA (type LLM) s'est restreinte à l'écriture du parseur, de fonctions annexes et de ce readme. Ainsi que pour la detection d'erreurs, d'incohérences ou de mauvais nommages de variable.

## 1. Structure du projet

```
Projet/
├── Main.jl          Point d'entrée : lancer_experiences et multi_start
├── glouton.jl       DSATUR et randDSATUR (solution initiale)
├── recuit.jl        Recuit simulé (one-move incrémental, swap) et voisinages
├── utils.jl         Lecture des fichiers .col, listes d'adjacence,
│                    validité d'une coloration, calibration de T0 et Tmin
├── benchmarks.jl    Meilleures bornes connues de la littérature (Jin et al., 2016)
├── graphics.jl      Figures (évolution de la fonction objectif, multi-start)
├── Project.toml     Dépendances Julia du projet
├── README.md        Ce fichier
├── HU_Quentin_Metaheuristiques.pdf   Rapport du projet
├── Instances/       Instances de test au format DIMACS (.col)
├── results/         Résultats (CSV, bilans du multi-start)
└── plots/           Figures générées
    ├── single/      Évolution de la fonction objectif pendant un recuit
    └── multiple/    Visualisation du multi-start
```

Correspondance avec les algorithmes du rapport :

| Rapport                                    | Code                                          |
|--------------------------------------------|-----------------------------------------------|
| Algorithme 1 – DSATUR                      | `DSATUR` (`glouton.jl`)                       |
| Algorithme 2 – voisinage one-move (naïf)   | `voisinage_onemove` (`recuit.jl`)             |
| Algorithme 3 – composante connexe          | `composante_connexe` (`recuit.jl`)            |
| Algorithme 4 – voisinage swap              | `voisinage_swap` (`recuit.jl`)                |
| Section 3.3.4 – calibration de T0 et Tmin  | `calibrer_T` (`utils.jl`)                     |
| Algorithme 5 – recuit simulé (swap)        | `recuit_simule_swap` (`recuit.jl`)            |
| Algorithme 6 – recuit one-move incrémental | `recuit_simule_onemove_rapide` (`recuit.jl`)  |
| Section 4.3 – multi-start / randDSATUR     | `multi_start` (`Main.jl`), `randDSATUR`       |

---

## 2. Installation

### 2.1 Installer Julia

Le code a été développé et testé avec **Julia 1.12** et fonctionne à partir de
Julia 1.10. La méthode recommandée pour installer Julia est **juliaup**,
l'installateur officiel :

- **Linux et macOS** (dans un terminal) :

  ```bash
  curl -fsSL https://install.julialang.org | sh
  ```

  Fermez puis rouvrez le terminal pour que la commande `julia` soit trouvée.

- **Windows** (dans PowerShell ou l'invite de commandes) :

  ```
  winget install --name Julia --id 9NJNWW8PVKMN -e -s msstore
  ```

  Julia peut aussi être installé depuis le Microsoft Store (application « Julia »).

- Autre possibilité : télécharger l'installateur sur
  <https://julialang.org/downloads/>.

Vérifiez ensuite l'installation :

```bash
julia --version
```

La commande doit afficher une version supérieure ou égale à 1.10.

### 2.2 Installer les dépendances

Les dépendances sont déclarées dans `Project.toml` :

| Paquet       | Rôle                                                  |
|--------------|-------------------------------------------------------|
| `Plots`      | Génération des figures (moteur graphique GR)          |
| `Random`     | Tirages aléatoires, graine (bibliothèque standard)    |
| `Statistics` | Moyenne et écart-type (bibliothèque standard)         |

Placez-vous **dans le dossier du projet** (celui qui contient `Main.jl`) puis
lancez une seule fois :

```bash
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

Cette commande télécharge et précompile les paquets dans un environnement
propre au projet, sans toucher à votre installation globale. Une connexion
Internet est nécessaire. La première installation de `Plots` peut prendre
**plusieurs minutes** (précompilation), ce qui est normal.

---

## 3. Lancer le programme

Toutes les commandes se lancent **depuis le dossier du projet**, car les
chemins `Instances/`, `results/` et `plots/` sont relatifs à ce dossier.

### 3.1 Depuis le REPL Julia (recommandé)

```bash
julia --project=.
```

Puis, dans le REPL :

```julia
include("Main.jl")

# Recuit one-move, 10 exécutions sur queen5_5
lancer_experiences(["queen5_5"])

# Recuit swap sur plusieurs instances
lancer_experiences(["queen7_7", "huck", "myciel4"]; moveType = "swap")

# Multi-start one-move
multi_start(["anna", "david"]; nbStart = 100)
```

Le premier `include("Main.jl")` prend quelques secondes (chargement de
`Plots`). Le REPL garde ensuite le code compilé, ce qui rend les appels
suivants plus rapides.

### 3.2 En une seule commande

```bash
julia --project=. -e 'include("Main.jl"); lancer_experiences(["queen5_5", "huck"]; nb_runs = 5, seed = 1)'
```

Sous Windows (PowerShell / cmd), inversez les guillemets :

```
julia --project=. -e "include(\"Main.jl\"); lancer_experiences([\"queen5_5\"]; nb_runs = 5)"
```

---

## 4. Utilisation détaillée

Les noms d'instances sont les noms des fichiers de `Instances/` **sans
l'extension `.col`** :

| Instance     | \|V\| | \|E\|   | Meilleure borne sup. connue |
|--------------|------:|--------:|----------------------------:|
| `queen5_5`   | 25    | 160     | 75 (optimum prouvé)         |
| `queen7_7`   | 49    | 476     | 196 (optimum prouvé)        |
| `queen8_12`  | 96    | 1 368   | 624 (optimum prouvé)        |
| `huck`       | 74    | 301     | 243 (optimum prouvé)        |
| `games120`   | 120   | 638     | 443                         |
| `anna`       | 138   | 493     | 276                         |
| `david`      | 87    | 406     | 237                         |
| `myciel4`    | 23    | 71      | 45                          |
| `le450_25c`  | 450   | 17 343  | 4 515                       |
| `DSJC500_5`  | 500   | 62 624  | 10 886                      |
| `DSJC1000_9` | 1 000 | 449 449 | 103 445                     |

### 4.1 `lancer_experiences` : recuit simulé sur plusieurs exécutions

```julia
lancer_experiences(instances::Vector{String}; kwargs...)
```

Pour chaque instance, et pour chacune des `nb_runs` exécutions : construction
gloutonne, calibration de `T0` et `Tmin`, recuit simulé, puis vérification de
la validité de la coloration. Une ligne est affichée par exécution, suivie d'un
bilan par instance (minimum, moyenne et écart-type de z). La fonction renvoie
aussi la liste des résultats sous forme de `NamedTuple`.

| Argument nommé     | Défaut                        | Description |
|--------------------|-------------------------------|-------------|
| `moveType`         | `"onemove"`                   | Voisinage : `"onemove"` ou `"swap"` |
| `nb_runs`          | `10`                          | Nombre d'exécutions par instance |
| `construire`       | `DSATUR`                      | Glouton initial : `DSATUR` ou `randDSATUR` |
| `K`                | `1500`                        | Nombre de paliers de température |
| `nbIter`           | `600`                         | Itérations par palier |
| `p_init`           | `0.5`                         | Probabilité d'accepter une dégradation moyenne à `T0` |
| `p_fin`            | `0.0001`                      | Probabilité d'accepter une dégradation moyenne à `Tmin` |
| `chemin`           | `nom -> "Instances/$nom.col"` | Fonction qui donne le chemin du fichier d'une instance |
| `seed`             | `nothing`                     | Graine aléatoire (entier) pour rendre une exécution reproductible |
| `enchainer_swap`   | `false`                       | Enchaîne un second recuit swap (K/2 paliers, nbIter/2 itérations) après chaque recuit. Non utilisé dans le rapport, et non compté dans le temps mesuré |
| `sauver_graphique` | `false`                       | Enregistre l'évolution de la fonction objectif du 1er run dans `plots/single/` |

La pénalité par arête en conflit (voisinage one-move) vaut `p = n + 1`.

Exemples :

```julia
# Reproductible et avec la figure d'évolution de la fonction objectif
lancer_experiences(["queen7_7"]; moveType = "onemove", seed = 42, sauver_graphique = true)

# Recuit plus long
lancer_experiences(["le450_25c"]; K = 3000, nbIter = 1000, nb_runs = 3)

# Instance placée dans un autre dossier
lancer_experiences(["mon_graphe"]; chemin = nom -> "data/$nom.col", nb_runs = 5)
```

### 4.2 `multi_start` : recuits depuis plusieurs solutions initiales

```julia
multi_start(instances::Vector{String}; kwargs...)
```

Pour chaque instance, lance `nbStart` recuits, chacun depuis une solution
initiale différente construite par `randDSATUR` (sommet tiré au hasard parmi
les 10 % de plus grand degré de saturation). La meilleure valeur obtenue est
comparée aux bornes de la littérature, puis une figure est enregistrée : un
point noir pour chaque solution initiale, un point rouge pour la valeur obtenue
après recuit.

| Argument nommé | Défaut                        | Description |
|----------------|-------------------------------|-------------|
| `moveType`     | `"onemove"`                   | `"onemove"` ou `"swap"` |
| `nbStart`      | `10`                          | Nombre de départs |
| `K`, `nbIter`  | `1500`, `600`                 | Schéma de refroidissement |
| `p_init`, `p_fin` | `0.5`, `0.0001`            | Calibration des températures |
| `chemin`       | `nom -> "Instances/$nom.col"` | Chemin du fichier d'instance |
| `seed`         | `nothing`                     | Graine aléatoire |

### 4.3 Fonctions de plus bas niveau

Les briques de l'algorithme peuvent aussi être appelées directement :

```julia
include("Main.jl")
edges, n = parser("Instances/huck.col")
adjOf = adjacence(edges, n)

x0 = DSATUR(n, adjOf)                     # coloration initiale (vecteur de couleurs)
sum(x0), isValid(x0, adjOf)               # valeur et validité

T0, Tmin = calibrer_T(x0, adjOf, n, 0.5, 0.0001, "onemove")
alpha = (Tmin / T0)^(1 / 1500)
x_best, f_best, valeurs, meilleures = recuit_simule_onemove_rapide(x0, adjOf, T0, Tmin, n + 1, alpha, 600)
x_best, f_best, valeurs, meilleures = recuit_simule_swap(x0, adjOf, T0, Tmin, alpha, 600)

comparer_resultat("huck", sum(x_best), sum(x0), "results/test.txt")
```

---

## 5. Fichiers produits

Les dossiers `results/` et `plots/` sont créés automatiquement s'ils n'existent pas.

| Fichier                                         | Produit par          | Contenu |
|-------------------------------------------------|----------------------|---------|
| `results/resultats_bruts_<moveType>.csv`        | `lancer_experiences` | Une ligne par exécution : `instance, moveType, run, nbIter, K, nb_aretes, z0, z, valide, temps_s`. **Le fichier est réécrit à chaque appel** |
| `plots/single/<moveType>_evolution_z_<nom>.png` | `lancer_experiences` (`sauver_graphique = true`) | Valeur courante (bleu) et meilleure valeur (rouge) à chaque itération |
| `results/multiple_<nom>.txt`                    | `multi_start`        | Bilan comparé aux bornes de la littérature. **Ajouté à la fin du fichier** à chaque appel |
| `plots/multiple/<nom>.png`                      | `multi_start`        | Visualisation du multi-start |

Dans le CSV, `z0` est la valeur de la solution gloutonne, `z` celle de la
meilleure solution trouvée, `valide` indique l'absence de conflit et
`temps_s` le temps (glouton + calibration + recuit) en secondes.

---

## 6. Reproduire les résultats du rapport

Les paramètres du rapport (table 2) sont les valeurs par défaut :
`K = 1500`, `nbIter = 600`, `p_init = 0.5`, `p_fin = 0.0001`, `p = n + 1`.

```julia
include("Main.jl")
instances = ["queen5_5", "queen7_7", "queen8_12", "huck", "games120", "anna",
             "david", "myciel4", "le450_25c", "DSJC500_5", "DSJC1000_9"]

# Tables 3 et 4 : 10 exécutions par instance
lancer_experiences(instances; moveType = "onemove", nb_runs = 10)
lancer_experiences(instances; moveType = "swap",    nb_runs = 10)

# Tables 5 et 6 : multi-start (100 départs en one-move, 10 en swap)
multi_start(instances; moveType = "onemove", nbStart = 100)
multi_start(instances; moveType = "swap",    nbStart = 10)
```

Le recuit est stochastique, donc les valeurs obtenues varient d'une exécution
à l'autre (utilisez `seed` pour fixer le tirage). Les temps dépendent de la
machine. À titre indicatif, une exécution prend moins d'une seconde en
one-move sur les petites instances, environ 5 s sur `DSJC1000_9`, et 1 à
12 s en swap. Le multi-start one-move à 100 départs sur toutes les instances
prend donc plusieurs minutes.

---

## 7. Utiliser d'autres instances

Le programme lit le format DIMACS standard (`.col`) :

```
c lignes de commentaire
p edge <nombre_de_sommets> <nombre_d_aretes>
e 1 2
e 1 3
...
```

Les sommets sont numérotés à partir de 1. Les arêtes en double (listées dans
les deux sens) et les boucles sont ignorées. D'autres instances sont
disponibles par exemple sur <https://mat.tepper.cmu.edu/COLOR/instances.html>.
Il suffit de déposer le fichier dans `Instances/` et d'appeler le programme
avec son nom sans extension. Si l'instance figure dans `benchmarks.jl`,
`multi_start` la compare aux meilleures bornes connues. Sinon, un message
l'indique et le reste du programme fonctionne normalement.

---

## 8. Problèmes fréquents

- **`ERROR: ArgumentError: Package Plots not found`** : Julia n'a pas été lancé
  avec l'environnement du projet. Utilisez `julia --project=.` depuis le dossier
  du projet, et lancez `Pkg.instantiate()` une première fois (section 2.2).
- **`SystemError: opening file "Instances/....col"`** : Julia n'a pas été lancé
  depuis le dossier du projet, ou le nom de l'instance est mal orthographié
  (l'extension `.col` ne doit pas être indiquée). Dans le REPL, `pwd()` affiche
  le dossier courant et `cd("chemin/vers/Projet")` permet d'en changer.
- **Message `QPainterPath::arcTo: ... NaN`** lors de `multi_start` : avertissement
  sans conséquence du moteur graphique GR, émis quand une flèche est de
  longueur nulle (départ déjà égal au résultat final). La figure est quand
  même enregistrée.
- **Machine sans affichage graphique (serveur, SSH)** : si GR pose problème, lancez
  `ENV["GKSwstype"] = "100"` avant `include("Main.jl")` pour générer les figures
  sans fenêtre.

