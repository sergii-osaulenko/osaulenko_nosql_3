// ============================================================
// PART 2 — LOAD MOVIELENS 1M DATA
// ============================================================

// ============================================================
// STEP 1. UNIQUE CONSTRAINTS
// ============================================================
//
// Constraints забезпечують унікальність ідентифікаторів.
// Вони також створюють backing indexes, які прискорюють
// пошук User/Movie під час створення RATED relationships.
//

CREATE CONSTRAINT user_id_unique IF NOT EXISTS
FOR (u:User)
REQUIRE u.userId IS UNIQUE;

CREATE CONSTRAINT movie_id_unique IF NOT EXISTS
FOR (m:Movie)
REQUIRE m.movieId IS UNIQUE;

CREATE CONSTRAINT genre_name_unique IF NOT EXISTS
FOR (g:Genre)
REQUIRE g.name IS UNIQUE;


// ============================================================
// STEP 2. LOAD USERS
// ============================================================
//
// MovieLens 1M містить 6,040 користувачів.
//
// ZIP-код навмисно не імпортуємо: він не використовується
// у графових запитах цього завдання.
//

LOAD CSV WITH HEADERS
FROM 'file:///users.csv'
AS row

MERGE (u:User {
    userId: toInteger(row.userId)
})

ON CREATE SET
    u.gender = row.gender,
    u.age = toInteger(row.age),
    u.occupation = toInteger(row.occupation);


// ============================================================
// STEP 3. LOAD MOVIES AND GENRES
// ============================================================
//
// MovieLens 1M містить 3,883 фільми.
//
// Рік випуску витягуємо з кінця title.
// Наприклад:
// "Toy Story (1995)" -> 1995
//
// Жанри зберігаємо як окремі Genre nodes.
//

LOAD CSV WITH HEADERS
FROM 'file:///movies.csv'
AS row

MERGE (m:Movie {
    movieId: toInteger(row.movieId)
})

ON CREATE SET
    m.title = row.title,
    m.year =
        CASE
            WHEN row.title =~ '.*\\([0-9]{4}\\)$'
            THEN toInteger(
                substring(
                    row.title,
                    size(row.title) - 5,
                    4
                )
            )
            ELSE null
        END

WITH m, row

UNWIND split(row.genres, '|') AS genreName

MERGE (g:Genre {
    name: genreName
})

MERGE (m)-[:HAS_GENRE]->(g);


// ============================================================
// STEP 4. LOAD RATINGS IN BATCHES
// ============================================================
//
// MovieLens 1M містить 1,000,209 ratings.
//
// Використовуємо сучасний Cypher
// CALL { ... } IN TRANSACTIONS
// замість deprecated apoc.periodic.iterate.
//
// batch size = 10,000 rows
// Транзакції виконуються послідовно.
//

LOAD CSV WITH HEADERS
FROM 'file:///ratings.csv'
AS row

CALL (row) {
    MATCH (u:User {
        userId: toInteger(row.userId)
    })

    MATCH (m:Movie {
        movieId: toInteger(row.movieId)
    })

    MERGE (u)-[r:RATED]->(m)

    ON CREATE SET
        r.rating = toInteger(row.rating),
        r.timestamp = toInteger(row.timestamp)
}
IN TRANSACTIONS OF 10000 ROWS;