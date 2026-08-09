# Part 4 — Verified practical results

## Dataset degree facts

- Highest-degree Movie: `2858 — American Beauty (1999)` → **3428 ratings**
- Highest-degree User: `4169` → **2314 ratings**
- Highest-degree Genre: `Drama` → **1603 movies**
- Users with >=500 ratings: **399**
- Movies with >=1000 ratings: **207**

## Q7 — final 15-row high-degree summary

| nodeType | identifier | degree |
|---|---|---:|
| Movie | 2858 | 3428 |
| Movie | 260 | 2991 |
| Movie | 1196 | 2990 |
| Movie | 1210 | 2883 |
| Movie | 480 | 2672 |
| User | 4169 | 2314 |
| User | 1680 | 1850 |
| User | 4277 | 1743 |
| User | 1941 | 1595 |
| User | 1181 | 1521 |
| Genre | Drama | 1603 |
| Genre | Comedy | 1200 |
| Genre | Action | 503 |
| Genre | Thriller | 492 |
| Genre | Romance | 471 |

## Interpretation

The largest Movie and User nodes are genuine high-degree nodes, while Genre nodes are expected to have high degree because a single genre is shared by many movies.

For this dataset, `Drama` is the clearest genre hub. A traversal that enters a genre hub without additional filtering can expand to a large candidate set. Indexes can locate a node efficiently, but they do not eliminate the cost of traversing thousands of adjacent relationships.