# Part 5 — Verified GDS results

## Environment

- Neo4j local Browser
- GDS observed in the successful run: **2026.06.0**
- Base graph: **9,941 nodes / 1,006,617 relationships**

## 5.1 PageRank

Projected graph:

| graph | nodes | relationships |
|---|---:|---:|
| movieGraph | 3,883 | 100,000 |

Observed top rows:

| movieId | title | PageRank score |
|---:|---|---:|
| 2858 | American Beauty (1999) | 9.679310341928172 |
| 260 | Star Wars: Episode IV - A New Hope (1977) | 9.118844616644234 |
| 1196 | Star Wars: Episode V - The Empire Strikes Back (1980) | 9.07751958489126 |
| 1198 | Raiders of the Lost Ark (1981) | 7.9903093403909615 |
| 608 | Fargo (1996) | 7.0379017101667545 |
| 593 | Silence of the Lambs, The (1991) | 6.758826813070229 |
| 858 | Godfather, The (1972) | 6.334646995281922 |
| 318 | Shawshank Redemption, The (1994) | 6.282112746692942 |
| 2571 | Matrix, The (1999) | 6.2669076505329135 |

Only rows visible in the captured practical result are reported.

## 5.2 Louvain

Projected graph:

| graph | nodes | relationships |
|---|---:|---:|
| userSimilarity | 6,040 | 100,000 |

Observed statistics:

- communityCount = **4,826**
- modularity = **0.158615421812715**

Largest observed communities:

| communityId | users |
|---:|---:|
| 4276 | 792 |
| 1736 | 235 |
| 1273 | 190 |

Top genres for the largest observed communities:

- Community 4276: Drama 68,786; Comedy 55,595; Action 37,508
- Community 1736: Comedy 28,908; Drama 26,587; Action 23,014

## 5.3 Dijkstra

Projected graph:

| graph | nodes | relationships |
|---|---:|---:|
| userGraph | 6,040 | 100,000 |

Cost definition:

`SIMILAR.cost = 1 / SIMILAR.weight`

where `SIMILAR.weight` is the number of movies both users rated >=4.

Selected connected pair:

`4169 → 4277`

- hops = **1**
- totalCost = **0.0013623978201634877**

Multi-pair check:

| source | target | hops |
|---:|---:|---:|
| 4169 | 4277 | 1 |
| 817 | 4484 | 2 |
| 1119 | 3681 | 2 |
| 2237 | 3658 | 2 |
| 2244 | 5239 | 2 |
| 3512 | 4279 | 2 |
| 5054 | 5047 | 2 |
| 5458 | 5722 | 2 |
| 5636 | 5684 | 2 |
| 5809 | 5077 | 2 |

## Cleanup

Final verification:

```text
similarRelationships = 0
```

This confirms that temporary `SIMILAR` relationships were removed after the practical GDS analysis.