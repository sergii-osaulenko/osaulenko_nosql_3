// Part 3 — Cypher analysis queries
// MovieLens 1M
//
// Run each query separately when screenshots are required.

// ============================================================
// Q1 — Thriller movies with average rating > 4
// ============================================================

MATCH (g:Genre {name: 'Thriller'})<-[:HAS_GENRE]-(m:Movie)<-[r:RATED]-()
WITH m, avg(r.rating) AS avgRating, count(r) AS ratingCount
WHERE avgRating > 4.0
RETURN m.movieId AS movieId,
       m.title AS title,
       round(avgRating * 100.0) / 100.0 AS avgRating,
       ratingCount
ORDER BY avgRating DESC, ratingCount DESC;


// ============================================================
// Q2 — Users with more than 50 five-star ratings
// ============================================================

MATCH (u:User)-[r:RATED]->()
WHERE r.rating = 5
WITH u, count(r) AS fiveStarCount
WHERE fiveStarCount > 50
RETURN u.userId AS userId,
       u.gender AS gender,
       u.age AS age,
       fiveStarCount
ORDER BY fiveStarCount DESC;


// ============================================================
// Q3 — Movies rated >= 4 by both User 1 and User 2
// ============================================================

MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)
      <-[r2:RATED]-(u2:User {userId: 2})
WHERE r1.rating >= 4
  AND r2.rating >= 4
RETURN m.movieId AS movieId,
       m.title AS title,
       r1.rating AS user1Rating,
       r2.rating AS user2Rating
ORDER BY movieId;


// ============================================================
// Q4 — Genres with average rating >= 4 and at least 100 ratings
// ============================================================

MATCH (g:Genre)<-[:HAS_GENRE]-(m:Movie)<-[r:RATED]-()
WITH g, avg(r.rating) AS avgRating, count(r) AS ratingCount
WHERE ratingCount >= 100
  AND avgRating >= 4.0
RETURN g.name AS genre,
       round(avgRating * 100.0) / 100.0 AS avgRating,
       ratingCount
ORDER BY avgRating DESC, ratingCount DESC;


// ============================================================
// Q5 — Recommendation through similar users
// Target user = 1.
// Similarity = number of shared movies both users rated >= 4.
// Candidate movie must be new to target and rated >= 4 by similar users.
// ============================================================

MATCH (target:User {userId: 1})-[tr:RATED]->(shared:Movie)
      <-[sr:RATED]-(similar:User)
WHERE tr.rating >= 4
  AND sr.rating >= 4
  AND similar <> target
WITH target, similar, count(shared) AS sharedHighRated
WHERE sharedHighRated >= 3
MATCH (similar)-[cr:RATED]->(candidate:Movie)
WHERE cr.rating >= 4
  AND NOT EXISTS {
    MATCH (target)-[:RATED]->(candidate)
  }
WITH candidate,
     count(DISTINCT similar) AS supportingUsers,
     sum(cr.rating) * 1.0 / count(cr) AS supportingAvg,
     max(sharedHighRated) AS strongestTasteOverlap
RETURN candidate.movieId AS movieId,
       candidate.title AS title,
       supportingUsers,
       round(supportingAvg * 100.0) / 100.0 AS supportingAvg,
       strongestTasteOverlap
ORDER BY supportingUsers DESC,
         supportingAvg DESC,
         strongestTasteOverlap DESC
LIMIT 20;


// ============================================================
// Q6 — Shortest connection between User 1 and User 2
// ============================================================

MATCH (u1:User {userId: 1}),
      (u2:User {userId: 2})
MATCH p = shortestPath((u1)-[:RATED*..10]-(u2))
RETURN length(p) AS pathLength,
       [n IN nodes(p) |
          CASE
            WHEN n:User THEN 'User ' + toString(n.userId)
            WHEN n:Movie THEN n.title
            ELSE coalesce(n.name, toString(elementId(n)))
          END
       ] AS path;