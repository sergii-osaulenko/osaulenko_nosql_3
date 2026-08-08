// ==========================================
// КРОК 1: Створення унікальних індексів (Констрейнтів)
// Створюються ДО завантаження для уникнення дублів та прискорення MERGE
// ==========================================
CREATE CONSTRAINT user_id_unique IF NOT EXISTS 
FOR (u:User) REQUIRE u.userId IS UNIQUE;

CREATE CONSTRAINT movie_id_unique IF NOT EXISTS 
FOR (m:Movie) REQUIRE m.movieId IS UNIQUE;

CREATE CONSTRAINT genre_name_unique IF NOT EXISTS 
FOR (g:Genre) REQUIRE g.name IS UNIQUE;

// ==========================================
// КРОК 2: Завантаження користувачів
// ==========================================
LOAD CSV WITH HEADERS FROM 'file:///users.csv' AS row
MERGE (u:User {userId: toInteger(row.userId)})
ON CREATE SET 
    u.gender = row.gender,
    u.age = toInteger(row.age),
    u.occupation = toInteger(row.occupation);

// ==========================================
// КРОК 3: Завантаження фільмів та жанрів
// ==========================================
LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
MERGE (m:Movie {movieId: toInteger(row.movieId)})
ON CREATE SET 
    m.title = row.title
WITH m, row
// Розбиваємо рядок жанрів "Action|Sci-Fi" на окремі значення
UNWIND split(row.genres, '|') AS genreName
MERGE (g:Genre {name: genreName})
MERGE (m)-[:HAS_GENRE]->(g);

// ==========================================
// КРОК 4: Завантаження оцінок (Ребер RATED) батчами через APOC
// ==========================================
CALL apoc.periodic.iterate(
  "LOAD CSV WITH HEADERS FROM 'file:///ratings.csv' AS row RETURN row",
  "MATCH (u:User {userId: toInteger(row.userId)})
   MATCH (m:Movie {movieId: toInteger(row.movieId)})
   MERGE (u)-[r:RATED]->(m)
   ON CREATE SET 
       r.rating = toInteger(row.rating),
       r.timestamp = toInteger(row.timestamp)",
  {batchSize: 10000, iterateList: true, parallel: false}
);