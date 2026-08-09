// ============================================================
// Part 3 — six Cypher queries of increasing complexity
// ============================================================

// Q1. Thriller movies with average rating > 4.0.
// The rating count is returned so that the average can be interpreted
// together with the sample size.
MATCH (g:Genre {name: 'Thriller'})<-[:HAS_GENRE]-(m:Movie)<-[r:RATED]-()
WITH m, avg(r.rating) AS avgRating, count(r) AS ratingCount
WHERE avgRating > 4.0
RETURN m.movieId AS movieId,
       m.title AS title,
       round(avgRating * 100.0) / 100.0 AS avgRating,
       ratingCount
ORDER BY avgRating DESC, ratingCount DESC;


// Q2. Users who gave rating 5 to more than 50 movies.
MATCH (u:User)-[r:RATED]->()
WHERE r.rating = 5
WITH u, count(r) AS fiveStarCount
WHERE fiveStarCount > 50
RETURN u.userId AS userId,
       u.gender AS gender,
       u.age AS age,
       u.occupation AS occupation,
       fiveStarCount
ORDER BY fiveStarCount DESC;


// Q3. Movies that both users 1 and 2 rated highly (>= 4).
MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User {userId: 2})
WHERE r1.rating >= 4 AND r2.rating >= 4
RETURN m.movieId AS movieId,
       m.title AS title,
       r1.rating AS user1Rating,
       r2.rating AS user2Rating
ORDER BY movieId;


// Q4. Genres whose movies have consistently high ratings.
// A minimum of 100 ratings prevents very small samples from dominating.
MATCH (g:Genre)<-[:HAS_GENRE]-(m:Movie)<-[r:RATED]-()
WITH g,
     avg(r.rating) AS avgRating,
     count(r) AS ratingCount
WHERE ratingCount >= 100
  AND avgRating >= 4.0
RETURN g.name AS genre,
       round(avgRating * 100.0) / 100.0 AS avgRating,
       ratingCount
ORDER BY avgRating DESC, ratingCount DESC;


// Q5. Recommendation for user 1:
// similar users = users sharing at least 3 high-rated movies (>=4).
// Candidate = a movie not rated by user 1 but rated >=4 by similar users.
MATCH (target:User {userId: 1})-[tr:RATED]->(shared:Movie)<-[sr:RATED]-(similar:User)
WHERE tr.rating >= 4
  AND sr.rating >= 4
  AND similar <> target
WITH target, similar, count(shared) AS sharedHighRated
WHERE sharedHighRated >= 3
MATCH (similar)-[cr:RATED]->(candidate:Movie)
WHERE cr.rating >= 4
  AND NOT EXISTS { MATCH (target)-[:RATED]->(candidate) }
WITH candidate,
     count(DISTINCT similar) AS supportingUsers,
     avg(cr.rating) AS supportingAvg,
     max(sharedHighRated) AS strongestTasteOverlap
RETURN candidate.movieId AS movieId,
       candidate.title AS title,
       supportingUsers,
       round(supportingAvg * 100.0) / 100.0 AS supportingAvg,
       strongestTasteOverlap
ORDER BY supportingUsers DESC, supportingAvg DESC, strongestTasteOverlap DESC
LIMIT 20;


// Q6. Shortest connection between user 1 and user 2 through RATED edges.
// The path is intentionally undirected: the task asks for a connection,
// not a directionally valid recommendation path.

MATCH (u1:User {userId: 1}),
      (u2:User {userId: 2})

MATCH p = SHORTEST 1 (u1)-[:RATED]-+(u2)

RETURN length(p) AS pathLength,
       [n IN nodes(p) |
          CASE
            WHEN n:User THEN 'User ' + toString(n.userId)
            WHEN n:Movie THEN n.title
            ELSE toString(id(n))
          END
       ] AS path;