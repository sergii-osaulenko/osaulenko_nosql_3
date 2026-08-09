# Граф знань для рекомендаційної системи

## MovieLens 1M + Neo4j + GDS — FINAL SUBMISSION

**Статус:** фінальна версія, доповнена після повторної перевірки початкових вимог та практичних результатів у Neo4j Browser.

Цей README містить не лише інструкції запуску, а й відповіді на всі основні питання завдання, фактичні результати, пояснення алгоритмів, висновки та порівняння з SQL.

---

# 1. Дані та графова схема

## 1.1. MovieLens 1M

Фактичні контрольні значення:

| Сутність | Кількість |
|---|---:|
| Users | **6,040** |
| Movies | **3,883** |
| Genres | **18** |
| Ratings | **1,000,209** |
| Movie–Genre links | **6,408** |
| Total nodes | **9,941** |
| Base relationships | **1,006,617** |

Оригінальний MovieLens README зазначає, що MovieID може доходити до 3952, але не кожен ID відповідає фактичному рядку. Тому граф містить саме 3,883 записів із `movies.dat`, а не штучно створені відсутні MovieID.

Dataset використовує:

```text
delimiter = ::
encoding  = Latin-1
```

`convert.py` перетворює `.dat` у UTF-8 CSV.

---

## 1.2. Схема

```text
(:User {userId, gender, age, occupation})
       |
       | [:RATED {rating, timestamp}]
       v
(:Movie {movieId, title, year})
       |
       | [:HAS_GENRE]
       v
(:Genre {name})
```

### Чому User, Movie та Genre — вузли?

**User** — самостійна сутність із власними атрибутами та великою кількістю зв'язків.

**Movie** — самостійна сутність, через яку проходять основні recommendation traversals.

**Genre** — окрема сутність, оскільки вона є точкою входу для пошуку фільмів, агрегацій та майбутнього розширення графа.

### Чому RATED — relationship?

Факт оцінювання природно має форму:

```text
User X оцінив Movie Y значенням Z у момент T
```

Тому:

```text
(User)-[:RATED {rating, timestamp}]->(Movie)
```

є компактною і природною моделлю.

Типові traversal стають простими:

```text
User → Movie
Movie ← User
User → Movie ← User
```

Окремий `Rating` node для 1,000,209 ratings додав би понад мільйон вузлів і щонайменше ще два типи relationships. Він був би виправданий, якби rating мав багато власних атрибутів/зв'язків. Для MovieLens 1M це зайва складність.

### Чому Genre — окремий node?

Альтернатива:

```text
Movie {genres: ["Action", "Comedy"]}
```

Обрана модель:

```text
(Movie)-[:HAS_GENRE]->(Genre)
```

Переваги:

- природний traversal `Genre → Movie`;
- прості агрегації по жанрах;
- нормалізація назви жанру;
- можливість додати зв'язки до Genre у майбутньому.

Ціна — лише 18 Genre nodes і 6,408 `HAS_GENRE` relationships, що для цього датасету дуже мало.

---

# 2. Завантаження даних

## 2.1. Конвертація

Запуск:

```bash
python convert.py
```

Створює:

```text
import/movies.csv
import/users.csv
import/ratings.csv
```

`users.dat` містить Zip-code, але він навмисно не переноситься в граф, оскільки не використовується в задачах.

## 2.2. Захист унікальності

Фінальний loader використовує:

```cypher
CREATE CONSTRAINT user_id_unique IF NOT EXISTS
FOR (u:User) REQUIRE u.userId IS UNIQUE;

CREATE CONSTRAINT movie_id_unique IF NOT EXISTS
FOR (m:Movie) REQUIRE m.movieId IS UNIQUE;

CREATE CONSTRAINT genre_name_unique IF NOT EXISTS
FOR (g:Genre) REQUIRE g.name IS UNIQUE;
```

Це сильніше за просто індекс: ключ одночасно індексується та захищається від дублювання.

## 2.3. Чому MERGE?

`MERGE` гарантує, що повторний запуск не створить дублікати User/Movie/Genre. Для `RATED` він також не створює повторний зв'язок для тієї самої пари User–Movie.

## 2.4. Batch import

Ratings містить понад мільйон рядків. Фінальна версія використовує native transactional batching:

```cypher
CALL {
  LOAD CSV WITH HEADERS FROM 'file:///ratings.csv' AS row
  ...
} IN TRANSACTIONS OF 10000 ROWS;
```

Це дозволяє не тримати весь імпорт в одній транзакції.

## 2.5. Контрольні результати

Після імпорту очікуються:

```text
Users            = 6,040
Movies           = 3,883
Genres           = 18
RATED            = 1,000,209
HAS_GENRE        = 6,408
Nodes            = 9,941
Base relationships = 1,006,617
```

Пари `User–Movie` у вихідному `ratings.dat` не дублюються; додатково uniqueness constraints захищають graph model.

---

# 3. Шість Cypher-запитів — відповіді та результати

## Q1 — Thriller movies with average rating > 4

**Питання:** які Thriller-фільми мають середній рейтинг > 4?

**Результат:** **52 movies**.

Top 10:

| movieId | title | avgRating | ratings |
|---:|---|---:|---:|
| 745 | Close Shave, A (1995) | 4.5205 | 657 |
| 50 | Usual Suspects, The (1995) | 4.5171 | 1783 |
| 904 | Rear Window (1954) | 4.4762 | 1050 |
| 1212 | Third Man, The (1949) | 4.4521 | 480 |
| 2762 | Sixth Sense, The (1999) | 4.4063 | 2459 |
| 908 | North by Northwest (1959) | 4.3840 | 1315 |
| 593 | Silence of the Lambs, The (1991) | 4.3518 | 2578 |
| 1252 | Chinatown (1974) | 4.3392 | 1185 |
| 1267 | Manchurian Candidate, The (1962) | 4.3333 | 765 |
| 2571 | Matrix, The (1999) | 4.3158 | 2590 |

**Висновок:** одного лише `avgRating` недостатньо для оцінки якості — кількість ratings також важлива. Наприклад, високий average на сотнях/тисячах оцінок набагато переконливіший.

---

## Q2 — Users with >50 five-star ratings

**Питання:** які користувачі поставили понад 50 оцінок `5`?

**Результат:** **1,390 users**.

Top 10:

| userId | gender | age | occupation | fiveStarCount |
|---:|:---:|---:|---:|---:|
| 4277 | M | 35 | 16 | 571 |
| 4169 | M | 50 | 0 | 476 |
| 3032 | M | 25 | 0 | 466 |
| 4448 | M | 25 | 14 | 434 |
| 5100 | M | 50 | 6 | 424 |
| 1680 | M | 25 | 20 | 406 |
| 549 | M | 25 | 6 | 402 |
| 2909 | M | 25 | 7 | 396 |
| 3391 | M | 18 | 4 | 387 |
| 1285 | M | 35 | 4 | 377 |

**Висновок:** User 4277 має найбільше п'ятизіркових оцінок — 571.

---

## Q3 — Movies highly rated by User 1 and User 2

**Питання:** які фільми одночасно отримали >=4 від User 1 і User 2?

**Результат:** **6 movies**.

| movieId | title | User 1 | User 2 |
|---:|---|---:|---:|
| 1193 | One Flew Over the Cuckoo's Nest (1975) | 5 | 5 |
| 1207 | To Kill a Mockingbird (1962) | 4 | 4 |
| 1246 | Dead Poets Society (1989) | 4 | 5 |
| 1962 | Driving Miss Daisy (1989) | 4 | 5 |
| 2028 | Saving Private Ryan (1998) | 5 | 4 |
| 3105 | Awakenings (1990) | 5 | 4 |

**Висновок:** у User 1 і User 2 є 6 спільних high-rated movies, тому вони мають достатню основу для similarity/recommendation traversal.

---

## Q4 — Genres with average >=4 and >=100 ratings

**Питання:** які жанри мають середній рейтинг >=4 та щонайменше 100 ratings?

**Результат:** лише **Film-Noir**.

| genre | avgRating | ratingCount |
|---|---:|---:|
| Film-Noir | 4.08 | 18,261 |

Тут `ratingCount` — кількість rating–genre пар; multi-genre movie може входити до кількох жанрових aggregation.

**Висновок:** Film-Noir має найвищу стабільну середню оцінку серед жанрів, що проходять заданий поріг кількості оцінок.

---

## Q5 — Recommendation via similar users

**Питання:** що можна рекомендувати User 1 на основі користувачів зі схожими смаками?

Алгоритм:

```text
User 1
 → high-rated Movies
 → other Users who also high-rated those Movies
 → count shared high-rated Movies
 → keep sharedHighRated >= 3
 → their high-rated candidate Movies
 → exclude Movies already rated by User 1
 → rank candidates
```

**Результат:** **4,310 similar users** для User 1 за умовою `sharedHighRated >= 3`.

Top recommendations:

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

**Висновок:** American Beauty має найбільшу підтримку — 2,307 similar users. Це демонструє практичну користь graph traversal для recommendation engine.

---

## Q6 — Shortest path

**Питання:** який найкоротший шлях між User 1 і User 2?

У вихідному User–Movie графі:

```text
User 1 → Awakenings (1990) → User 2
```

**Довжина = 2 hops.**

Інтерпретація:

- 2 hops = один спільний Movie;
- 4 hops = два Movie links та один проміжний User;
- 6 hops = ще довший similarity chain.

**Висновок:** shortest path є природною graph operation; у класичному SQL для довільної глибини потрібен recursive CTE або спеціальна graph extension.

---

# 4. Супервузли

## 4.1. Що таке супервузол?

Супервузол — вузол із дуже великою кількістю сусідів.

Для MovieLens це:

- дуже активні Users;
- дуже популярні Movies;
- широкі Genres.

## 4.2. Практичні результати

### Top Movies

| Movie | Degree |
|---|---:|
| 2858 — American Beauty | **3428** |
| 260 | 2991 |
| 1196 | 2990 |
| 1210 | 2883 |
| 480 | 2672 |

### Top Users

| User | Degree |
|---|---:|
| 4169 | **2314** |
| 1680 | 1850 |
| 4277 | 1743 |
| 1941 | 1595 |
| 1181 | 1521 |

Користувачів із >=500 ratings: **399**.

Movies із >=1000 ratings: **207**.

### Genre hubs

| Genre | Movies |
|---|---:|
| Drama | **1603** |
| Comedy | 1200 |
| Action | 503 |
| Thriller | 492 |
| Romance | 471 |

## 4.3. Чому супервузли можуть погіршувати performance?

Індекс швидко знаходить сам вузол, але індекс не прибирає вартість обходу його сусідів.

Наприклад:

```text
Genre: Drama
   ↓
1603 Movies
   ↓
hundreds of thousands of downstream ratings
```

При multi-hop traversal кількість можливих paths може швидко зростати.

## 4.4. Стратегія для Genre supernodes

Не потрібно дублювати Genre nodes.

Краще:

1. починати traversal із селективного indexed lookup;
2. додавати фільтри на Movies/Ratings;
3. обмежувати candidate set;
4. materialize similarity edges, якщо recommendation запускається часто;
5. використовувати GDS projections замість повторного повного traversal.

---

# 5. GDS — PageRank, Louvain, Dijkstra

Практичний GDS запуск був виконаний у локальному Neo4j Browser.

**Observed GDS version:** `2026.06.0`.

Усі top-50,000 materializations використовують deterministic tie-breaking:

```text
weight DESC, stable application IDs ASC
```

Це важливо для відтворюваності.

---

## 5.1. PageRank

Побудований graph:

```text
movieGraph
3,883 Movie nodes
100,000 CO_RATED relationships
```

`CO_RATED.weight` = кількість users, які високо оцінили обидва Movies.

Фактичні top rows:

| movieId | title | PageRank |
|---:|---|---:|
| 2858 | American Beauty (1999) | **9.679310341928172** |
| 260 | Star Wars: Episode IV - A New Hope (1977) | 9.118844616644234 |
| 1196 | Star Wars: Episode V - The Empire Strikes Back (1980) | 9.07751958489126 |
| 1198 | Raiders of the Lost Ark (1981) | 7.9903093403909615 |
| 608 | Fargo (1996) | 7.0379017101667545 |
| 593 | Silence of the Lambs, The (1991) | 6.758826813070229 |
| 858 | Godfather, The (1972) | 6.334646995281922 |
| 318 | Shawshank Redemption, The (1994) | 6.282112746692942 |
| 2571 | Matrix, The (1999) | 6.2669076505329135 |

### Інтерпретація

PageRank тут означає **структурну центральність у Movie co-rating graph**, а не просто кількість ratings.

American Beauty займає перше місце, бо має сильні зв'язки з іншими центральними Movies у графі.

---

## 5.2. Louvain

Побудований graph:

```text
userSimilarity
6,040 User nodes
100,000 SIMILAR relationships
```

`SIMILAR.weight` = кількість Movies, які обидва Users оцінили >=4.

Фактична статистика GDS:

```text
communityCount = 4,826
modularity     = 0.158615421812715
```

Найбільші observed communities:

| communityId | size |
|---:|---:|
| 4276 | **792** |
| 1736 | 235 |
| 1273 | 190 |

Top genres:

### Community 4276

- Drama — 68,786 high ratings
- Comedy — 55,595
- Action — 37,508

### Community 1736

- Comedy — 28,908
- Drama — 26,587
- Action — 23,014

### Інтерпретація

Louvain знаходить communities Users, які щільніше пов'язані за similarity.

Кластери не повинні збігатися з одним жанром: користувачі мають змішані смаки. Тому домінування Drama/Comedy/Action у великих communities є індикатором спільних preference patterns, а не доказом того, що community = один жанр.

Modularity `0.1586` показує наявність community structure, але вона не є надзвичайно сильною; граф також містить багато малих communities.

---

## 5.3. Dijkstra

Для weighted shortest path:

```text
SIMILAR.weight = shared high-rated movies
SIMILAR.cost   = 1 / weight
```

Тобто:

```text
strong similarity → lower cost
weak similarity   → higher cost
```

Практичний graph:

```text
userGraph
6,040 User nodes
100,000 SIMILAR relationships
```

### Фактичний selected pair

```text
source = 4169
target = 4277
```

Результат:

```text
path = [4169, 4277]
hops = 1
totalCost = 0.0013623978201634877
```

Оскільки:

```text
1 / 0.0013623978201634877 = 734
```

між цими Users є `SIMILAR.weight = 734`, тобто 734 спільних high-rated Movies у materialized top-50k graph.

### Multi-pair verification

| Source | Target | Hops |
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

### Інтерпретація

Це показує, що у materialized similarity graph багато перевірених Users знаходяться дуже близько.

Але це **не** є доказом соціального "six degrees of separation":

1. це similarity-of-taste graph, не social graph;
2. edges означають спільні high-rated Movies;
3. graph обрізаний top-50,000;
4. компоненти можуть бути disconnected.

Коректний висновок: у найбільш зв'язаних частинах similarity graph Users мають короткі chains за taste similarity.

---

## 5.4. Cleanup

Після GDS:

```text
similarRelationships = 0
```

Це підтверджує, що тимчасові `SIMILAR` relationships були видалені.

Також усі temporary GDS graphs:

```text
movieGraph
userSimilarity
userGraph
```

видаляються після відповідної секції.

---

# 6. Порівняння Graph vs SQL

## 6.1. Де Graph сильніший?

### Recommendation Q5

Граф:

```text
User
 ↓
high-rated Movie
 ↑
similar User
 ↓
candidate Movie
```

є прямим traversal.

У SQL потрібно кілька self-joins над `ratings`, aggregation, `HAVING`, а потім exclusion уже оцінених Movies.

### Shortest path Q6

Neo4j/GDS має спеціальні graph algorithms.

У класичному SQL для довільної глибини потрібен recursive CTE або спеціалізована graph functionality.

### GDS

PageRank, Louvain та Dijkstra природно працюють над graph projections. В SQL довелося б спочатку будувати явний edge table, а потім використовувати graph extension або зовнішній engine.

---

## 6.2. Де SQL сильніший?

SQL часто простіший для:

- `GROUP BY`;
- reporting;
- ETL;
- масових aggregation;
- табличних exports;
- простих column filters.

Наприклад:

```sql
SELECT movie_id,
       AVG(rating),
       COUNT(*)
FROM ratings
GROUP BY movie_id;
```

не потребує складного graph traversal.

### Загальний висновок

Neo4j не є автоматично швидшим за SQL для всього.

**Graph виграє, коли основна цінність запиту — структура зв'язків.**

**SQL виграє, коли основна цінність — масова таблична агрегація.**

---

# 7. Можливі покращення

## Q1

Індекс `Genre.name` робить старт traversal селективним.

## Q3

`User.userId` та `Movie.movieId` мають uniqueness constraints.

## Q5

Якщо recommendation запускається часто, доцільно materialize:

```text
(User)-[:SIMILAR {weight}]->(User)
```

Це прибирає повторний expensive shared-movie calculation.

Компроміс: similarity edges треба оновлювати після зміни ratings.

## GDS

Top-50k — компроміс між розміром graph projection і збереженням найсильніших similarity/co-rating edges.

Занадто агресивне обрізання може створити багато disconnected components. Тому в production варто тестувати:

- top-K;
- minimum shared-rating threshold;
- component size;
- recall рекомендацій.

---

# 8. Фінальні висновки

1. **Модель `User–RATED–Movie–HAS_GENRE–Genre` добре відповідає recommendation domain.**
2. `RATED` як relationship є компактнішим і природнішим за окремий Rating node для MovieLens 1M.
3. `Genre` як node робить genre traversal та aggregation природними.
4. Dataset коректно представлений у графі: **6,040 Users, 3,883 Movies, 18 Genres, 1,000,209 Ratings**.
5. Q1–Q6 демонструють filtering, aggregation, common-neighbor traversal, recommendation traversal та shortest path.
6. Supernodes показують, що навіть indexed graph node може мати дорогий downstream traversal, якщо degree дуже великий.
7. PageRank визначає структурно центральні Movies.
8. Louvain знаходить communities Users із подібними preference patterns.
9. Dijkstra показує weighted closeness у similarity graph.
10. Graph model має найбільшу перевагу для multi-hop relationship queries.
11. SQL залишається сильнішим для масових tabular aggregation/reporting tasks.
12. Для production recommendation engine доцільно materialize similarity edges та контролювати graph density.

**Головний висновок:** вибір Neo4j виправданий не тим, що graph database "швидша за SQL взагалі", а тим, що recommendation, similarity, community detection та path analysis природно виражаються через зв'язки між сутностями.

---

# 9. Як запустити

## Docker

```bash
docker compose up -d
```

Neo4j Browser:

```text
http://localhost:7474
```

Після запуску:

```bash
python convert.py
```

після чого виконати:

```text
queries/part2_load.cypher
queries/part3.cypher
queries/part4_supernodes.cypher
queries/part5_gds.cypher
```

> Пароль із `docker-compose.yml` є локальним навчальним значенням. Для реального середовища його потрібно змінити.

---

# 10. Evidence

У `evidence/` містяться screenshots фактичного Neo4j Browser запуску:

- Part 3 Q1–Q6;
- Part 4 Q7;
- PageRank;
- Louvain statistics;
- Louvain community sizes;
- Louvain top genres;
- Dijkstra;
- Dijkstra multi-pair;
- final cleanup.

---

# 11. Файли submission

```text
docker-compose.yml
convert.py

import/
  MovieLens_README.txt

queries/
  part2_load.cypher
  part3.cypher
  part4_supernodes.cypher
  part5_gds.cypher

results/
  part3_results.md
  part4_results.md
  part5_results.md
  part3_q1.csv
  part3_q6.csv

evidence/
  actual Neo4j Browser screenshots

docs/
  FINAL_REPORT.pdf
  FINAL_REPORT.docx

README.md
RUN.md
CHECKLIST.md
MANIFEST.md
DATASET_NOTICE.md
REQUIREMENTS_MATRIX.md
```