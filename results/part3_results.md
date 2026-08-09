# Part 3 — Verified practical results

| Query | Result |
|---|---|
| Q1 | 52 Thriller movies with average rating > 4.0 |
| Q2 | 1,390 users with >50 five-star ratings |
| Q3 | 6 movies rated >=4 by both User 1 and User 2 |
| Q4 | 1 genre meeting avg >=4 and >=100 ratings: Film-Noir |
| Q5 | 4,310 similar users for User 1 under sharedHighRated >=3 |
| Q6 | shortest path length = 2 hops |

## Q1 — Top 10

| movieId | title | avgRating | ratingCount |
|---:|---|---:|---:|
| 50 | Usual Suspects, The (1995) | 4.52 | 1783 |
| 745 | Close Shave, A (1995) | 4.52 | 657 |
| 904 | Rear Window (1954) | 4.48 | 1050 |
| 1212 | Third Man, The (1949) | 4.45 | 480 |
| 2762 | Sixth Sense, The (1999) | 4.41 | 2459 |
| 908 | North by Northwest (1959) | 4.38 | 1315 |
| 593 | Silence of the Lambs, The (1991) | 4.35 | 2578 |
| 1252 | Chinatown (1974) | 4.34 | 1185 |
| 1267 | Manchurian Candidate, The (1962) | 4.33 | 765 |
| 2571 | Matrix, The (1999) | 4.32 | 2590 |

## Q2 — Top users by five-star count

`4277: 571`, `4169: 476`, `3032: 466`, `4448: 434`, `5100: 424`,
`1680: 406`, `549: 402`, `2909: 396`, `3391: 387`, `1285: 377`.

## Q3 — Common high-rated movies

| movieId | title | User 1 | User 2 |
|---:|---|---:|---:|
| 1193 | One Flew Over the Cuckoo's Nest (1975) | 5 | 5 |
| 1207 | To Kill a Mockingbird (1962) | 4 | 4 |
| 1246 | Dead Poets Society (1989) | 4 | 5 |
| 1962 | Driving Miss Daisy (1989) | 4 | 5 |
| 2028 | Saving Private Ryan (1998) | 5 | 4 |
| 3105 | Awakenings (1990) | 5 | 4 |

## Q4

`Film-Noir` — average `4.08`, `18,261` ratings.

## Q5 — Top recommendations for User 1

| movieId | title | supportingUsers | supportingAvg |
|---:|---|---:|---:|
| 2858 | American Beauty (1999) | 2307 | 4.69 |
| 1196 | Star Wars: Episode V - The Empire Strikes Back (1980) | 2250 | 4.60 |
| 593 | Silence of the Lambs, The (1991) | 2029 | 4.60 |
| 1198 | Raiders of the Lost Ark (1981) | 2018 | 4.68 |
| 318 | Shawshank Redemption, The (1994) | 1930 | 4.71 |
| 2571 | Matrix, The (1999) | 1891 | 4.66 |
| 1210 | Star Wars: Episode VI - Return of the Jedi (1983) | 1800 | 4.49 |
| 858 | Godfather, The (1972) | 1736 | 4.74 |
| 589 | Terminator 2: Judgment Day (1991) | 1709 | 4.46 |
| 110 | Braveheart (1995) | 1698 | 4.61 |

## Q6

`User 1 → Awakenings (1990) → User 2`

Path length: **2 hops**.