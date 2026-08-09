# Граф знань для рекомендаційної системи

## MovieLens 1M + Neo4j AuraDB + GDS

---

# 0. Що саме реалізовано

Проєкт охоплює весь цикл завдання:

1. `.dat` → UTF-8 CSV;
2. проєктування графової схеми;
3. індекси та завантаження вузлів;
4. пакетне завантаження 1 000 209 оцінок;
5. шість Cypher-запитів;
6. пошук супервузлів;
7. GDS PageRank, Louvain та Dijkstra;
8. порівняння з реляційною моделлю;
9. реальні контрольні значення для MovieLens 1M;
10. окремі result-файли для перевірки.

## Структура репозиторію

```text
.
├── docker-compose.yml
├── convert.py
├── MovieLens_README.txt
├── import/
│   ├── movies.csv
│   ├── users.csv
│   └── ratings.csv
├── queries/
│   ├── part2_load.cypher
│   ├── part3.cypher
│   ├── part4_supernodes.cypher
│   └── part5_gds.cypher
├── results/
│   ├── query1_all.csv
│   ├── query2_all.csv
│   ├── query3_all.csv
│   ├── query4_all.csv
│   ├── query5_top20.csv
│   ├── supernodes_users.csv
│   ├── supernodes_movies.csv
│   ├── genre_degrees.csv
│   ├── pagerank_reference_networkx.csv
│   ├── louvain_reference_networkx.csv
│   ├── louvain_summary_networkx.json
│   ├── dijkstra_reference_networkx.json
│   └── dijkstra_graph_summary_networkx.json
├── RUN.md
└── README.md
```

---

# 1. Дані MovieLens 1M

Джерело: **MovieLens 1M**, GroupLens Research.

Наданий датасет містить:

| Сутність | Кількість |
|---|---:|
| Users | **6 040** |
| Movie rows | **3 883** |
| Ratings | **1 000 209** |
| Genres | **18** |
| Movie–Genre links | **6 408** |

Оригінальний README датасету зазначає, що `MovieID` може бути в діапазоні до 3952, але не кожен ID відповідає фактичному рядку фільму. Тому в граф завантажуються саме **3 883 записи з `movies.dat`**, а не штучно створюються відсутні MovieID.

Датасет використовує:

```text
delimiter = ::
encoding = Latin-1
```

Тому перед імпортом `.dat` конвертуються у CSV з UTF-8.

### Контрольна перевірка CSV

У наданих файлах:

- немає дубльованих пар `UserID + MovieID` у `ratings.dat`;
- кожен користувач має щонайменше 20 оцінок;
- фактичний максимум ratings на одного User — **2 314**;
- фактичний максимум ratings на один Movie — **3 428**.

Ці значення використані далі в аналізі супервузлів.

---

# 2. Частина 1 — проєктування схеми

## 2.1. Запропонована схема

```text
                         ┌───────────────────────────┐
                         │        (:Genre)            │
                         │        {name}              │
                         └─────────────▲─────────────┘
                                       │
                                  HAS_GENRE
                                       │
┌───────────────────────────┐          │          ┌───────────────────────────┐
│         (:User)           │          │          │         (:Movie)          │
│                           │          │          │                           │
│ userId                    │          └──────────│ movieId                   │
│ gender                    │                     │ title                     │
│ age                       │                     │ year                      │
│ occupation                │                     │                           │
└─────────────┬─────────────┘                     └─────────────▲─────────────┘
              │                                                │
              │ RATED                                          │
              │ {rating, timestamp}                            │
              └────────────────────────────────────────────────┘
```

У скороченому вигляді:

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

## 2.2. Які сутності стали вузлами, а які — ребрами?

### Вузли

**User** — самостійна сутність, яка має власні атрибути та бере участь у великій кількості рекомендаційних traversal.

**Movie** — самостійна сутність з `movieId`, назвою та роком. Через Movie проходять основні recommendation-зв'язки.

**Genre** — окрема сутність, оскільки жанр використовується не лише як текстове значення, а як точка входу до групи фільмів.

### Ребра

**RATED** — зв'язок конкретного користувача з конкретним фільмом. Саме на ребрі природно зберігаються `rating` та `timestamp`.

**HAS_GENRE** — зв'язок фільму з жанром. Він не має власних властивостей, тому окремий вузол-зв'язок для нього не потрібен.

---

## 2.3. `Rating` як ребро чи окремий вузол?

У роботі обрано:

```text
(User)-[:RATED {rating, timestamp}]->(Movie)
```

### Чому це добре для MovieLens 1M

У датасеті оцінка фактично є фактом про зв'язок двох сутностей:

> користувач X оцінив фільм Y значенням Z у момент T.

Тому `rating` і `timestamp` природно належать relationship `RATED`.

Це дає дуже прості traversal:

```text
User → RATED → Movie
Movie ← RATED ← User
User → Movie ← User
```

Наприклад, Q3 — пошук фільмів, які високо оцінили два користувачі — безпосередньо відповідає структурі графа.

### Переваги окремого `Rating`-вузла

Альтернативна модель:

```text
(User)-[:MADE]->(Rating)-[:FOR]->(Movie)
```

була б виправданою, якщо сама оцінка мала б багато властивостей або зв'язків, наприклад:

- джерело оцінки;
- версію алгоритму;
- причину зміни оцінки;
- модератора;
- кілька подій навколо однієї оцінки.

### Недоліки окремого вузла для цього датасету

Для 1 000 209 ratings це створило б понад мільйон додаткових вузлів і щонайменше ще два типи ребер на кожну оцінку. Типові recommendation-запити стали б довшими.

Отже, для **MovieLens 1M** relationship-модель є кращим компромісом між розміром графа та природністю traversal.

---

## 2.4. Чому `Genre` краще як окремий вузол?

Альтернатива:

```text
Movie {genres: ["Action", "Comedy"]}
```

Обрана модель:

```text
(Movie)-[:HAS_GENRE]->(Genre)
```

### Переваги

1. **Traversal:** легко знайти всі фільми жанру.
2. **Агрегації:** можна перейти `Genre → Movie → Rating`.
3. **Розширення:** до `Genre` у майбутньому можна додати інші зв'язки.
4. **Нормалізація:** назва жанру не дублюється в кожному Movie як окремий об'єкт.

### Компроміс

Додаються 18 Genre-вузлів та 6 408 `HAS_GENRE`-ребер. Для цього датасету це дуже мала ціна.

Водночас жанри — це хороший приклад **супервузлів**: `Drama` має **1 603** фільми, `Comedy` — **1 200**. Тому traversal через жанр без додаткових фільтрів може бути широким.

---

# 3. Частина 2 — завантаження даних

## 3.1. Конвертація `.dat → .csv`

`convert.py` читає:

```python
encoding="latin-1"
```

і розділяє рядки:

```python
parts = line.rstrip("\r\n").split("::")
```

Для `users.dat` Zip-code не переноситься, тому що він не використовується в запропонованій схемі.

Результат:

```text
import/movies.csv
import/users.csv
import/ratings.csv
```

CSV мають UTF-8, що спрощує роботу з Neo4j та українськими/спеціальними символами.

---

## 3.2. Індекси

У `part2_load.cypher` створено:

```cypher
CREATE INDEX user_userId IF NOT EXISTS
FOR (u:User) ON (u.userId);

CREATE INDEX movie_movieId IF NOT EXISTS
FOR (m:Movie) ON (m.movieId);

CREATE INDEX genre_name IF NOT EXISTS
FOR (g:Genre) ON (g.name);
```

Індекси потрібні насамперед для пошуку вузлів за стабільними ключами під час імпорту `RATED` та для селективного старту запитів, наприклад:

```cypher
MATCH (g:Genre {name: 'Thriller'})
```

---

## 3.3. Чому `MERGE`, а не `CREATE`?

`CREATE` безумовно створює новий вузол/зв'язок. Повторний запуск імпорту тоді може створити дублікати.

`MERGE` спочатку шукає відповідний pattern і створює його лише за відсутності.

Наприклад:

```cypher
MERGE (u:User {userId: toInteger(row.userId)})
```

гарантує логічну ідентичність User за `userId`.

Для rating:

```cypher
MERGE (u)-[r:RATED]->(m)
SET r.rating = ...,
    r.timestamp = ...
```

це захищає від дублювання relationship при повторному запуску.

У вихідному MovieLens 1M додатково перевірено, що пар `UserID + MovieID` не дублюється.

---

## 3.4. Чому `apoc.periodic.iterate`?

`ratings.csv` має **1 000 209** рядків.

Виконувати весь імпорт одним гігантським transaction небажано через:

- пам'ять;
- transaction log;
- timeout;
- ризик невдалого імпорту після довгого виконання.

Тому використано:

```cypher
CALL apoc.periodic.iterate(
  "LOAD CSV ...",
  "MATCH ... MERGE ...",
  {batchSize: 10000, parallel: false}
)
```

Тобто робота виконується блоками приблизно по 10 000 рядків.

### Чому `parallel:false`?

Це консервативніший і безпечніший режим для імпорту, коли різні batches можуть одночасно звертатися до тих самих User/Movie вузлів.

Якщо вузли гарантовано створені заздалегідь, а тіло batch використовує лише `MATCH` і не створює спільні сутності, можна експериментувати з `parallel:true`. Для навчальної роботи безпечніше залишити `false`.

---

## 3.5. Очікувана валідація після імпорту

Для повного датасету потрібно отримати:

```text
users           = 6040
movies          = 3883
genres          = 18
ratings         = 1000209
movieGenreLinks = 6408
```

Також query на дублікати `User–RATED–Movie` повинен повернути **0 рядків**.

---

# 4. Частина 3 — шість Cypher-запитів

Усі запити знаходяться у `queries/part3.cypher`.

---

## Q1. Thriller із середнім рейтингом > 4.0

### Логіка

Traversal:

```text
Genre → Movie ← RATED
```

Після цього оцінки групуються по Movie:

```cypher
avg(r.rating)
count(r)
```

Повертається і середній рейтинг, і кількість оцінок. Це важливо для інтерпретації: середнє 4.5 на кількох оцінках не таке надійне, як 4.3 на тисячах.

### Фактичний результат

**52 фільми** відповідають умові.

Перші 10:

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

Повний CSV: `results/query1_all.csv`.

---

## Q2. Користувачі, які поставили >50 оцінок «5»

### Логіка

Спочатку залишаються тільки relationships:

```cypher
WHERE r.rating = 5
```

Потім вони групуються за User:

```cypher
count(r)
```

і застосовується:

```cypher
fiveStarCount > 50
```

### Фактичний результат

**1 390 користувачів** відповідають умові.

Перші 10:

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

Повний CSV: `results/query2_all.csv`.

---

## Q3. Фільми, які високо оцінили і User 1, і User 2

### Логіка

Шукаємо один Movie, до якого є два різні `RATED` relationships:

```text
User 1 → Movie ← User 2
```

і обидві оцінки >=4.

### Фактичний результат

**6 фільмів:**

| movieId | title | User 1 | User 2 |
|---:|---|---:|---:|
| 1193 | One Flew Over the Cuckoo's Nest (1975) | 5 | 5 |
| 1207 | To Kill a Mockingbird (1962) | 4 | 4 |
| 1246 | Dead Poets Society (1989) | 4 | 5 |
| 1962 | Driving Miss Daisy (1989) | 4 | 5 |
| 2028 | Saving Private Ryan (1998) | 5 | 4 |
| 3105 | Awakenings (1990) | 5 | 4 |

Повний CSV: `results/query3_all.csv`.

---

## Q4. Жанри зі стабільно високими оцінками

### Логіка

Traversal:

```text
Genre → Movie ← RATED
```

Для кожного Genre рахується:

```text
avg(r.rating)
count(r)
```

Додатково введено:

```text
ratingCount >= 100
avgRating >= 4.0
```

### Фактичний результат

Є **один** жанр:

| genre | avgRating | ratingCount |
|---|---:|---:|
| Film-Noir | 4.0752 | 18 261 |

У README можна показати округлення до 4.08.

> **Нюанс:** один rating може належати до кількох жанрів, якщо Movie має кілька genres. Тому `ratingCount` тут є кількістю rating-genre пар, а не кількістю унікальних rating relationships у всьому графі.

Повний CSV: `results/query4_all.csv`.

---

## Q5. Рекомендація «схожі користувачі також оцінили»

Це найважчий Cypher-запит частини 3.

### Алгоритм

Для target user = **1**:

1. беремо його high-rated movies (`rating >= 4`);
2. знаходимо інших Users, які теж високо оцінили ці Movies;
3. рахуємо кількість спільних high-rated movies;
4. залишаємо `sharedHighRated >= 3`;
5. беремо їхні Movies з rating >=4;
6. виключаємо Movies, які User 1 вже оцінював;
7. ранжуємо кандидатів за кількістю supporting users;
8. додатково враховуємо середній rating та максимальне taste overlap.

### Фактичний результат

Для User 1 знайдено **4 310** інших користувачів, які мають щонайменше 3 спільні high-rated movies.

Top recommendations:

| movieId | title | supportingUsers | supportingAvg |
|---:|---|---:|---:|
| 2858 | American Beauty (1999) | 2307 | 4.6862 |
| 1196 | Star Wars: Episode V - The Empire Strikes Back (1980) | 2250 | 4.6009 |
| 593 | Silence of the Lambs, The (1991) | 2029 | 4.5998 |
| 1198 | Raiders of the Lost Ark (1981) | 2018 | 4.6754 |
| 318 | Shawshank Redemption, The (1994) | 1930 | 4.7062 |
| 2571 | Matrix, The (1999) | 1891 | 4.6589 |
| 1210 | Star Wars: Episode VI - Return of the Jedi (1983) | 1800 | 4.4906 |
| 858 | Godfather, The (1972) | 1736 | 4.7442 |
| 589 | Terminator 2: Judgment Day (1991) | 1709 | 4.4576 |
| 110 | Braveheart (1995) | 1698 | 4.6113 |

Повний top-20: `results/query5_top20.csv`.

### Чому це вже recommendation traversal?

У реляційній моделі довелося б кілька разів self-join таблицю ratings. У графі логіка безпосередньо відповідає топології:

```text
User
 ↓ RATED
Movie
 ↑ RATED
Similar User
 ↓ RATED
Candidate Movie
```

---

## Q6. Найкоротший шлях між User 1 і User 2

### Запит

Використано ненаправлений traversal:

```cypher
MATCH p = shortestPath((u1)-[:RATED*..10]-(u2))
```

Це свідоме рішення: задача питає про **ланцюжок зв'язку**, а не про напрямок рекомендації.

### Фактичний результат для User 1 і User 2

```text
User 1
  ↓
Movie 3105 — Awakenings (1990)
  ↑
User 2
```

Довжина:

```text
2 hops
```

Це означає, що обидва користувачі оцінили один і той самий Movie.

### Інтерпретація довжини

**2 hops:**

```text
User → Movie → User
```

Два користувачі мають спільний фільм.

**4 hops:**

```text
User A → Movie 1 → User B → Movie 2 → User C
```

Між початковим і кінцевим User є один проміжний User.

**6 hops:**

```text
User A → Movie 1 → User B → Movie 2 → User C → Movie 3 → User D
```

Між кінцевими User є два проміжні User.

Таким чином, парність довжини пояснюється чергуванням `User` і `Movie`.

---

# 5. Частина 4 — супервузли

Супервузол — вузол з дуже великим degree. Важливо розрізняти:

- **популярний Movie** — багато incoming `RATED`;
- **дуже активний User** — багато outgoing `RATED`;
- **широкий Genre** — багато `HAS_GENRE`.

## 5.1. Найбільші User

Максимум:

```text
User 4169 → 2314 ratings
```

Top users:

| userId | ratings |
|---:|---:|
| 4169 | 2314 |
| 1680 | 1850 |
| 4277 | 1743 |
| 1941 | 1595 |
| 1181 | 1521 |
| 889 | 1518 |
| 3618 | 1344 |
| 2063 | 1323 |
| 1150 | 1302 |
| 1015 | 1286 |

Користувачів із **>=500 ratings: 399**.

Повний список: `results/supernodes_users.csv`.

---

## 5.2. Найбільші Movie

Максимум:

```text
Movie 2858 — American Beauty (1999)
3428 ratings
```

Top movies:

| movieId | title | ratings |
|---:|---|---:|
| 2858 | American Beauty (1999) | 3428 |
| 260 | Star Wars: Episode IV - A New Hope (1977) | 2991 |
| 1196 | Star Wars: Episode V - The Empire Strikes Back (1980) | 2990 |
| 1210 | Star Wars: Episode VI - Return of the Jedi (1983) | 2883 |
| 480 | Jurassic Park (1993) | 2672 |
| 2028 | Saving Private Ryan (1998) | 2653 |
| 589 | Terminator 2: Judgment Day (1991) | 2649 |
| 2571 | Matrix, The (1999) | 2590 |
| 1270 | Back to the Future (1985) | 2583 |
| 593 | Silence of the Lambs, The (1991) | 2578 |

Movie nodes із >=1000 ratings: **207**.

Повний список: `results/supernodes_movies.csv`.

---

## 5.3. Genre-супервузли

Кількість Movie на Genre:

| Genre | Movies |
|---|---:|
| Drama | 1603 |
| Comedy | 1200 |
| Action | 503 |
| Thriller | 492 |
| Romance | 471 |
| Horror | 343 |
| Adventure | 283 |
| Sci-Fi | 276 |
| Children's | 251 |
| Crime | 211 |

Повний список: `results/genre_degrees.csv`.

### Чому супервузол може бути повільнішим?

Індекс прискорює пошук **самого вузла**, але не скасовує кількість його сусідів.

Наприклад:

```text
MATCH (m:Movie {movieId: 2858})<-[:RATED]-(u)
```

після знаходження Movie 2858 має обробити **3428** rating-зв'язків.

Для Movie з 10 ratings аналогічний traversal має на порядок меншу локальну роботу.

Проблема стає ще сильнішою при кількох hops:

```text
Movie → User → Movie → User → ...
```

оскільки кількість можливих сусідів/кандидатів може швидко збільшуватися.

---

## 5.4. Стратегія для цього датасету

Я б використав комбінацію:

1. селективний старт за `userId`, `movieId`, `genre.name`;
2. фільтрацію rating >=4 якомога раніше;
3. обмеження кандидатів;
4. матеріалізацію часто використовуваних similarity edges;
5. top-K edges для GDS;
6. окремі GDS in-memory projections для конкретного алгоритму.

**Не потрібно** прибирати Genre як вузли лише через те, що вони мають великий degree. Їх лише 18, і вони корисні для семантичних traversal. Потрібно уникати безумовних широких обходів через них.

---

# 6. Частина 5 — GDS

## 6.1. Важливий момент про materialization

GDS працює з **in-memory projection**, а не просто з довільним stored graph без підготовки.

Тому спочатку:

```text
stored graph
   ↓
materialize temporary similarity edges
   ↓
gds.graph.project(...)
   ↓
algorithm
   ↓
gds.graph.drop(...)
```

Це також пояснює, чому в `part5_gds.cypher` тимчасові `CO_RATED` та `SIMILAR` видаляються після завершення.

---

# 6.2. 5.1 PageRank на Movie-графі

## Побудова графа

Матеріалізується:

```text
Movie --CO_RATED-- Movie
```

де:

```text
CO_RATED.weight = кількість User,
які високо оцінили обидва Movie
```

Беруться тільки ratings >=4.

Щоб обмежити розмір, залишається top **50 000** пар.

Також використовується deterministic tie-breaker:

```text
ORDER BY weight DESC, m1.movieId ASC, m2.movieId ASC
```

у фактичному Cypher — через `m1.movieId` і `m2.movieId`.

Це важливо, тому що на межі `LIMIT 50000` багато пар можуть мати однаковий weight.

## Що означає високий PageRank?

Це **не просто кількість ratings**.

PageRank працює в графі Movie–Movie, тому високий PageRank означає, що Movie є центральним у мережі фільмів, які високо оцінюються спільними користувачами.

Наприклад, два Movie можуть мати приблизно однакову популярність, але один бути пов'язаний із багатьма іншими центральними Movie. Тоді PageRank може віддати йому вищий score.

Отже:

```text
Popularity ≠ PageRank
```

PageRank тут — **структурна центральність у co-rating graph**.

## Offline reference на реальному MovieLens 1M

Незалежний weighted PageRank на тому самому deterministic top-50k графі дав такий top-10:

| Rank | movieId | title | score |
|---:|---:|---|---:|
| 1 | 2858 | American Beauty (1999) | 0.007937 |
| 2 | 260 | Star Wars: Episode IV - A New Hope (1977) | 0.007506 |
| 3 | 1196 | Star Wars: Episode V - The Empire Strikes Back (1980) | 0.007473 |
| 4 | 1198 | Raiders of the Lost Ark (1981) | 0.006588 |
| 5 | 608 | Fargo (1996) | 0.005803 |
| 6 | 593 | Silence of the Lambs, The (1991) | 0.005590 |
| 7 | 858 | Godfather, The (1972) | 0.005232 |
| 8 | 318 | Shawshank Redemption, The (1994) | 0.005194 |
| 9 | 2571 | Matrix, The (1999) | 0.005188 |
| 10 | 2762 | Sixth Sense, The (1999) | 0.005022 |

**Це offline reference, а не заявлений результат GDS.**

Для фінальної здачі зробити screenshot фактичного:

```cypher
CALL gds.pageRank.stream(...)
```

у Neo4j Browser/AuraDB.

---

# 6.3. 5.2 Louvain — спільноти користувачів

## Побудова графа

```text
User --SIMILAR-- User
```

де:

```text
SIMILAR.weight = кількість Movie,
які обидва користувачі високо оцінили
```

Беруться тільки ratings >=4 і top 50 000 пар.

### Що шукає Louvain?

Louvain шукає communities — групи User, у яких зв'язки всередині групи щільніші, ніж зв'язки з рештою графа.

`modularity` показує, наскільки отримане розбиття має виражену community structure.

## Як перевірити, чи кластери мають зміст?

Не можна сказати:

> «community 123 = любителі бойовиків»

лише за номером community.

Потрібна перевірка через жанри:

1. отримати users community;
2. взяти їхні ratings >=4;
3. перейти до Movie → Genre;
4. порахувати top-3 genres;
5. порівняти top genres різних communities.

Якщо одна community систематично має більшу частку Action/Sci-Fi/Thriller, а інша — Drama/Romance/Comedy, це є змістовним підтвердженням різниці смаків.

Але повністю чистих жанрових кластерів очікувати не варто: користувачі MovieLens мають змішані смаки, а популярні жанри присутні в багатьох групах.

## Offline reference

Незалежний weighted Louvain з `seed=42` на тому самому deterministic top-50k графі дав:

```text
communityCount = 4827
modularity     ≈ 0.154737
```

Розміри найбільших communities:

```text
730
216
186
85
```

У решті є багато малих/одновузлових communities.

Top genres найбільших offline communities:

| Rank | Size | Top genres |
|---:|---:|---|
| 1 | 730 | Drama, Comedy, Action |
| 2 | 216 | Comedy, Drama, Action |
| 3 | 186 | Drama, Comedy, Action |
| 4 | 85 | Drama, Comedy, Action |

Ці значення **не слід підписувати як GDS Louvain results**. GDS має власну реалізацію Louvain, тому community IDs, кількість communities і modularity можуть відрізнятися.

Файли:

```text
results/louvain_reference_networkx.csv
results/louvain_summary_networkx.json
```

Для здачі обов'язково вставити фактичні:

```text
communityCount = ...
modularity = ...
Top 10 community sizes = ...
Top 3 genres = ...
```

зі свого Neo4j/GDS запуску.

---

# 6.4. 5.3 Dijkstra — найкоротший шлях між User

## Чому не можна використовувати `weight` напряму?

У нас:

```text
SIMILAR.weight = кількість спільних high-rated movies
```

Чим більше `weight`, тим сильніша схожість.

А Dijkstra шукає **мінімальну суму cost**.

Тому використано:

```text
cost = 1 / weight
```

Отже:

```text
strong similarity → small cost
weak similarity   → large cost
```

Це відповідає змісту shortest path.

## Важливий результат для User 1

У sparse top-50k similarity graph User 1 є ізольованим вузлом. Тому запуск Dijkstra для:

```text
1 → 2
```

у GDS може коректно не знайти шлях.

Це **не помилка** запиту. Це наслідок того, що top-50k — дуже жорстке обрізання повного similarity graph.

Для демонстрації Dijkstra використовується фактично зв'язана пара:

```text
User 4169 → User 4277
```

### Offline reference

На deterministic top-50k graph:

```text
4169 → 4277
```

має пряме `SIMILAR` ребро з:

```text
shared high-rated movies = 734
cost = 1 / 734 ≈ 0.0013624
hops = 1
```

Шлях через User 3985 з вагами 125/124 не є правильним для цієї deterministic top-50k побудови, оскільки пара 4169–4277 має значно сильніший прямий similarity edge.

## Наскільки «тісний світ»?

У deterministic top-50k offline graph:

```text
User nodes                    = 6040
Connected components          = 4824
Largest component             = 1217 users
Average unweighted path       ≈ 1.945 hops
Diameter of largest component = 3 hops
```

Для 10 контрольних пар у цьому offline graph отримано:

| Source | Target | Hops | Total cost |
|---:|---:|---:|---:|
| 4169 | 4277 | 1 | 0.0013624 |
| 2237 | 3658 | 2 | 0.0110864 |
| 5054 | 5047 | 2 | 0.0115887 |
| 3512 | 4279 | 2 | 0.0113651 |
| 2244 | 5239 | 2 | 0.0104562 |
| 5636 | 5684 | 2 | 0.0085211 |
| 1119 | 3681 | 2 | 0.0074169 |
| 5809 | 5077 | 2 | 0.0125192 |
| 817 | 4484 | 2 | 0.0108348 |
| 5458 | 5722 | 2 | 0.0103930 |

Для цієї вибірки середня кількість hops = **1.9**. Це добре ілюструє компактність найбільшої компоненти, але ще раз не означає соціальне «шість рукостискань».

Це показує, що **в найбільшій компоненті** користувачі дуже близькі за цією similarity-метрикою.

Але не можна робити висновок «шість рукостискань» для всього графа, тому що:

1. це не соціальна мережа;
2. ребро означає similarity taste, а не знайомство;
3. graph обрізаний top-50k;
4. є багато ізольованих компонент.

Тому правильний висновок:

> у найбільшій компоненті similarity graph користувачі мають короткі ланцюжки; це демонструє сильну структурну близькість смаків, але не підтверджує соціальну гіпотезу «six degrees of separation».

---

# 7. Частина 6 — граф vs SQL

## 7.1. Де граф виграє?

Найкращий приклад — Q5.

Графова логіка:

```text
User 1
  ↓ RATED
high-rated Movie
  ↑ RATED
similar User
  ↓ RATED
candidate Movie
```

У Cypher це один послідовний traversal із кількома `MATCH`.

У SQL довелося б кілька разів self-join таблицю ratings.

### Приклад SQL-еквівалента Q5

```sql
WITH similar_users AS (
    SELECT r2.user_id,
           COUNT(*) AS shared_high_rated
    FROM ratings r1
    JOIN ratings r2
      ON r1.movie_id = r2.movie_id
     AND r1.user_id <> r2.user_id
    WHERE r1.user_id = 1
      AND r1.rating >= 4
      AND r2.rating >= 4
    GROUP BY r2.user_id
    HAVING COUNT(*) >= 3
),
candidates AS (
    SELECT r.movie_id,
           COUNT(DISTINCT r.user_id) AS supporting_users,
           AVG(r.rating) AS supporting_avg
    FROM ratings r
    JOIN similar_users s
      ON s.user_id = r.user_id
    WHERE r.rating >= 4
      AND NOT EXISTS (
          SELECT 1
          FROM ratings seen
          WHERE seen.user_id = 1
            AND seen.movie_id = r.movie_id
      )
    GROUP BY r.movie_id
)
SELECT c.movie_id,
       m.title,
       c.supporting_users,
       c.supporting_avg
FROM candidates c
JOIN movies m ON m.movie_id = c.movie_id
ORDER BY c.supporting_users DESC,
         c.supporting_avg DESC
LIMIT 20;
```

Цей SQL є цілком можливим, але видно кілька self-join/CTE/NOT EXISTS. У графі структура зв'язків є частиною моделі, тому traversal є природним.

### Q6 ще сильніше демонструє перевагу графа

У Neo4j:

```cypher
shortestPath(...)
```

або GDS Dijkstra.

У класичному SQL для довільного графа потрібен recursive CTE, спеціалізована розширена функціональність або попередньо обчислені шляхи. Чим глибший і менш передбачуваний traversal, тим менш природною стає реляційна модель.

---

## 7.2. Де граф програє?

Для цього датасету SQL часто буде кращим для:

- масових `GROUP BY`;
- звітів;
- статистики за всіма користувачами;
- експорту всіх ratings;
- ETL;
- табличних агрегацій;
- простих фільтрів по колонках.

Наприклад:

```sql
SELECT movie_id,
       AVG(rating) AS avg_rating,
       COUNT(*) AS rating_count
FROM ratings
GROUP BY movie_id;
```

Це таблична aggregation-задача, яка не потребує складного graph traversal.

Отже, не можна казати, що Neo4j «завжди швидший». Його перевага проявляється тоді, коли важлива **структура зв'язків**.

---

## 7.3. Покращення схеми для конкретних запитів

### Q1

Індекс:

```cypher
CREATE INDEX genre_name IF NOT EXISTS
FOR (g:Genre) ON (g.name);
```

дозволяє селективно знайти `Thriller`.

### Q3

Індекси:

```text
User.userId
Movie.movieId
```

дозволяють швидко знайти конкретних User.

### Q5

Найбільше покращення — матеріалізувати:

```text
(User)-[:SIMILAR {weight}]->(User)
```

Якщо рекомендація запускається часто, не потрібно щоразу заново обчислювати спільні high-rated movies.

Компроміс: similarity edges потрібно оновлювати після зміни ratings.

### GDS

Для алгоритмів не варто проектувати весь можливий граф similarity без обмеження. Top-K або threshold зменшує:

- кількість in-memory relationships;
- час побудови projection;
- пам'ять;
- вартість алгоритму.

---

# 8. Фінальні висновки

Графова модель `User–RATED–Movie–HAS_GENRE–Genre` добре відповідає рекомендаційній задачі.

Найважливіший виграш Neo4j — не в тому, що він автоматично швидший за SQL для будь-якого запиту. Виграш полягає в тому, що traversal через пов'язані сутності є безпосередньою операцією над моделлю даних.

Для Q5 це дозволяє природно виразити рекомендацію через схожих користувачів. Для Q6 shortest path є першокласною графовою операцією. Для GDS та similarity analysis графова модель також є природною основою.

Водночас масові агрегації, звіти, ETL та прості табличні фільтри не обов'язково виграють від графової моделі. Для них SQL часто буде простішим і дуже ефективним.

Супервузли демонструють ще одну важливу властивість графів: індекс прискорює пошук вузла, але не прибирає вартість обходу великої кількості його сусідів. У MovieLens це видно на дуже популярних фільмах, активних користувачах та широких жанрах.

PageRank дає структурну центральність Movie у co-rating graph; Louvain шукає communities користувачів зі схожими смаками; Dijkstra дозволяє виміряти близькість у similarity graph за заданою cost-функцією.

Таким чином, Neo4j + GDS добре підходять для recommendation engine, де важливі не лише властивості об'єктів, а насамперед **зв'язки між ними**.

---