# Граф знань для рекомендаційної системи

### ASCII-діаграма

```text
+-----------------------------------------------------------------+
|                              User                               |
| {userId: Integer, gender: String, age: Integer, occ: Integer}   |
+-----------------------------------------------------------------+
          |                                       ^
          | [:RATED]                              | [:SIMILAR]
          | {rating: Integer,                     | {weight: Integer}
          |  timestamp: Integer}                  | (GDS Проєкція)
          v                                       v
+-----------------------------------------------------------------+
|                             Movie                               |
|            {movieId: Integer, title: String, year: Integer}     |
+-----------------------------------------------------------------+
          |                                       ^
          | [:HAS_GENRE]                          | [:CO_RATED]
          v                                       | {weight: Integer}
+-----------------------------------------------------------------+
|                             Genre                               |
|                         {name: String}                          |
+-----------------------------------------------------------------+
```

# Граф знань для рекомендаційної системи

Цей репозиторій підготовлений на **MovieLens 1M** з наданих файлів.

Контрольні значення:
- Users: **6040**
- Movies: **3883**
- Ratings: **1000209**
- Genres: **18**

> **GDS note:** PageRank/Louvain reference-результати обчислені локально з тією самою логікою top-50,000 weighted edges. Neo4j GDS може дати трохи інші community IDs/розміри через власну реалізацію та стохастичність Louvain. Для фінального README бажано зробити скриншоти фактичного запуску в AuraDB.

## 1. Схема

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

`User`, `Movie`, `Genre` — самостійні сутності, тому вони є вузлами. `RATED` описує зв'язок користувача з фільмом і містить властивості `rating` та `timestamp`; `HAS_GENRE` описує належність фільму до жанру.

Оцінка змодельована як **ребро**, а не окремий `Rating`-вузол. Це компактніше і природніше для типових traversal-запитів. Окремий вузол мав би сенс, якби оцінка мала багато власних зв'язків/атрибутів; для 1 000 209 оцінок це також суттєво збільшило б граф.

`Genre` винесено в окремі вузли, щоб підтримувати traversal, агрегації та подальше розширення графа.

## 2. Завантаження

`convert.py` читає `.dat` як `latin-1` і створює UTF-8 CSV. `part2_load.cypher` використовує uniqueness constraints, `MERGE`, `UNWIND` для жанрів та `apoc.periodic.iterate` з `parallel:false` для пакетного імпорту оцінок.

## 3. Запити

### Q1 — Thriller, average > 4

Reference: **52 movies**. Перші 10:

| movieId | title | avg | count |
|---:|---|---:|---:|
| 745 | Close Shave, A (1995) | 4.52 | 657 |
| 50 | Usual Suspects, The (1995) | 4.52 | 1783 |
| 904 | Rear Window (1954) | 4.48 | 1050 |
| 1212 | Third Man, The (1949) | 4.45 | 480 |
| 2762 | Sixth Sense, The (1999) | 4.41 | 2459 |
| 908 | North by Northwest (1959) | 4.38 | 1315 |
| 593 | Silence of the Lambs, The (1991) | 4.35 | 2578 |
| 1252 | Chinatown (1974) | 4.34 | 1185 |
| 1267 | Manchurian Candidate, The (1962) | 4.33 | 765 |
| 2571 | Matrix, The (1999) | 4.32 | 2590 |

### Q2 — >50 оцінок «5»

Reference: **1390 users**.

Перші:
`4277:571`, `4169:476`, `3032:466`, `4448:434`, `5100:424`, `1680:406`, `549:402`, `2909:396`, `3391:387`, `1285:377`.

### Q3 — user 1 і user 2, rating >=4

**6 фільмів:** 1193, 1207, 1246, 1962, 2028, 3105.

### Q4 — жанри з avg >=4 і >=100 ratings

Є один результат:

| genre | avgRating | ratingCount |
|---|---:|---:|
| Film-Noir | 4.08 | 18261 |

### Q5 — рекомендація через схожих користувачів

Для user 1 використано `sharedHighRated >= 3`. Таких reference-similar users: **4310**.

Перші рекомендації:

| movieId | title | supportingUsers | supportingAvg |
|---:|---|---:|---:|
| 2858 | American Beauty (1999) | 2307 | 4.69 |
| 1196 | Star Wars V | 2250 | 4.60 |
| 593 | Silence of the Lambs | 2029 | 4.60 |
| 1198 | Raiders of the Lost Ark | 2018 | 4.68 |
| 318 | Shawshank Redemption | 1930 | 4.71 |
| 2571 | Matrix | 1891 | 4.66 |
| 1210 | Star Wars VI | 1800 | 4.49 |
| 858 | Godfather | 1736 | 4.74 |
| 589 | Terminator 2 | 1709 | 4.46 |
| 110 | Braveheart | 1698 | 4.61 |

### Q6 — shortest path

Для user 1 і user 2:

```text
User 1 -> Movie 3105 -> User 2
```

Довжина: **2 hops**.

Інтерпретація:
- 2 hops = спільний фільм;
- 4 hops = два користувачі-посередники та два фільми;
- 6 hops = ще довший ланцюжок із трьома Movie-зв'язками.

## 4. Супервузли

Найбільший User:
`4169` — **2314 ratings**.

Користувачів із >=500 ratings: **399**.

Найбільший Movie:
`2858 — American Beauty (1999)` — **3428 ratings**.

Інші великі Movie: 260 (2991), 1196 (2990), 1210 (2883), 480 (2672).

Movie з >=1000 ratings: **207**.

Genre-супервузли:
- Drama — 1603 movies
- Comedy — 1200
- Action — 503
- Thriller — 492
- Romance — 471

Індекс швидко знаходить сам вузол, але не усуває вартість обходу тисяч його сусідів. Тому traversal через супервузол може бути дорожчим.

Для цього датасету корисні обмеження кандидатів, materialized similarity edges та GDS projections. Жанри не треба дублювати: їх лише 18, і вони логічно потрібні.

## 5. GDS

### 5.1 PageRank

Projection:
- 3883 Movie nodes
- top 50,000 weighted CO_RATED edges

Reference top:
1. American Beauty — 0.004177
2. Star Wars V — 0.003939
3. Star Wars IV — 0.003721
4. Raiders of the Lost Ark — 0.003013
5. Fargo — 0.002968
6. Matrix — 0.002769
7. Silence of the Lambs — 0.002748
8. Sixth Sense — 0.002555
9. Godfather — 0.002485
10. Shakespeare in Love — 0.002428

Високий PageRank тут означає не просто популярність. Він означає центральність у графі фільмів, які часто високо оцінюються спільною аудиторією.

### 5.2 Louvain

Reference:
- 6040 users
- 50,000 weighted SIMILAR edges
- **4549 communities**
- modularity ≈ **0.2565**
- найбільші groups: **1024, 238, 232** users

Top genres:
- 1024-user group: Drama, Comedy, Action
- 238-user group: Drama, Comedy, Action
- 232-user group: Comedy, Drama, Action

Кластери частково відповідають інтуїції, але не є чистими жанровими групами. Перевірка робиться порівнянням top genres кожної community з глобальним розподілом жанрів.

### 5.3 Dijkstra

Через top-50k обрізання user 1 і user 2 можуть опинитися в різних компонентах, тому для weighted shortest path використано connected pair:

```text
4169 -> 3985 -> 4277
```

Ваги similarity:
`125` і `124`.

Вартість:
`1/125 + 1/124 = 0.0160645`.

Hops: **2**.

У найбільшій компоненті reference-графа:
- 1494 users;
- середня ненормована довжина ≈ 2.32 hops;
- diameter = 4.

Це не доказ «шести рукостискань», бо ребра тут означають similarity of taste, а не соціальне знайомство; крім того, граф обрізаний top-50k.

## 6. Граф vs SQL

Рекомендаційний Q5 добре показує перевагу graph traversal: `User -> Movie <- User -> Movie`. У SQL це вимагає кількох self-join над `ratings`, а shortest path Q6 потребував би recursive CTE або спеціального graph extension.

Водночас SQL краще для великих плоских aggregation/reporting задач, наприклад:

```sql
SELECT movie_id, AVG(rating), COUNT(*)
FROM ratings
GROUP BY movie_id;
```

Графова модель виграє, коли запит використовує структуру зв'язків, а не тільки значення полів.

## 7. Покращення

1. Для Q5 можна матеріалізувати `(User)-[:SIMILAR {weight}]-(User)`, щоб не обчислювати спільні фільми при кожному запиті.
2. Для PageRank можна зберігати materialized `(Movie)-[:CO_RATED {weight}]-(Movie)`.
3. Ідентифікатори `User.userId` та `Movie.movieId` вже захищені uniqueness constraints.

## 8. Висновок

Neo4j особливо сильний для recommendation traversal, shortest paths, similarity graphs та GDS. SQL залишається кращим для масових aggregation/reporting/ETL задач. Отже, головний критерій вибору — характер запитів: чим більше значення має структура зв'язків, тим сильніша графова модель.

Фактичні reference-таблиці лежать у `results/`.