// Part 2 — Final graph loading script
// MovieLens 1M
// Expected local import files: users.csv, movies.csv, ratings.csv
//
// Expected final counts:
// Users = 6,040
// Movies = 3,883
// Genres = 18
// RATED = 1,000,209
// HAS_GENRE = 6,408

// ============================================================
// 1. Uniqueness constraints
// ============================================================

CREATE CONSTRAINT user_id_unique IF NOT EXISTS
FOR (u:User) REQUIRE u.userId IS UNIQUE;

CREATE CONSTRAINT movie_id_unique IF NOT EXISTS
FOR (m:Movie) REQUIRE m.movieId IS UNIQUE;

CREATE CONSTRAINT genre_name_unique IF NOT EXISTS
FOR (g:Genre) REQUIRE g.name IS UNIQUE;


// ============================================================
// 2. Users
// ============================================================

LOAD CSV WITH HEADERS FROM 'file:///users.csv' AS row
MERGE (u:User {userId: toInteger(row.userId)})
SET u.gender = row.gender,
    u.age = toInteger(row.age),
    u.occupation = toInteger(row.occupation);


// ============================================================
// 3. Movies + Genre nodes
// ============================================================

LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
MERGE (m:Movie {movieId: toInteger(row.movieId)})
SET m.title = row.title,
    m.year = CASE
        WHEN row.title =~ '.*\\([0-9]{4}\\)$'
        THEN toInteger(substring(row.title, size(row.title) - 5, 4))
        ELSE null
    END
WITH m, row
UNWIND split(row.genres, '|') AS genreName
MERGE (g:Genre {name: genreName})
MERGE (m)-[:HAS_GENRE]->(g);


// ============================================================
// 4. Ratings — native transactional batching
// ============================================================

CALL {
  LOAD CSV WITH HEADERS FROM 'file:///ratings.csv' AS row
  MATCH (u:User {userId: toInteger(row.userId)})
  MATCH (m:Movie {movieId: toInteger(row.movieId)})
  MERGE (u)-[r:RATED]->(m)
  SET r.rating = toInteger(row.rating),
      r.timestamp = toInteger(row.timestamp)
} IN TRANSACTIONS OF 10000 ROWS;


// ============================================================
// 5. Validation
// ============================================================

MATCH (u:User) RETURN count(u) AS users;
MATCH (m:Movie) RETURN count(m) AS movies;
MATCH (g:Genre) RETURN count(g) AS genres;
MATCH ()-[r:RATED]->() RETURN count(r) AS ratings;
MATCH ()-[r:HAS_GENRE]->() RETURN count(r) AS movieGenreLinks;

// Optional integrity check
MATCH (u:User)
WHERE NOT (u)-[:RATED]->()
RETURN count(u) AS usersWithoutRatings;