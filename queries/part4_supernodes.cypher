// Part 4 — Supernodes / high-degree analysis
// Final version. Uses application IDs instead of deprecated id().

// ============================================================
// Q1 — Overall highest-degree nodes
// ============================================================

CALL {
  MATCH (u:User)
  RETURN 'User' AS nodeType, toString(u.userId) AS identifier,
         count { (u)-[:RATED]->() } AS degree
  ORDER BY degree DESC
  LIMIT 5
}
UNION ALL
CALL {
  MATCH (m:Movie)
  RETURN 'Movie' AS nodeType, toString(m.movieId) AS identifier,
         count { (m)<-[:RATED]-() } AS degree
  ORDER BY degree DESC
  LIMIT 5
}
UNION ALL
CALL {
  MATCH (g:Genre)
  RETURN 'Genre' AS nodeType, g.name AS identifier,
         count { (g)<-[:HAS_GENRE]-() } AS degree
  ORDER BY degree DESC
  LIMIT 5
}
RETURN nodeType, identifier, degree
ORDER BY degree DESC, nodeType ASC, identifier ASC;


// ============================================================
// Q2 — Users with >= 500 ratings
// ============================================================

MATCH (u:User)
WITH u, count { (u)-[:RATED]->() } AS degree
WHERE degree >= 500
RETURN u.userId AS userId, degree
ORDER BY degree DESC;


// ============================================================
// Q3 — Movies with >= 1000 ratings
// ============================================================

MATCH (m:Movie)
WITH m, count { (m)<-[:RATED]-() } AS degree
WHERE degree >= 1000
RETURN m.movieId AS movieId, m.title AS title, degree
ORDER BY degree DESC;


// ============================================================
// Q4 — Genre degrees
// ============================================================

MATCH (g:Genre)
RETURN g.name AS genre,
       count { (g)<-[:HAS_GENRE]-() } AS movieCount
ORDER BY movieCount DESC;


// ============================================================
// Q5 — P99-style high-degree Genre threshold
// The observed threshold used in the practical analysis was 1534.49.
// ============================================================

MATCH (g:Genre)
WITH g, count { (g)<-[:HAS_GENRE]-() } AS degree
WHERE degree >= 1534.49
RETURN g.name AS genre, degree
ORDER BY degree DESC;


// ============================================================
// Q6 — Top 5 users
// ============================================================

MATCH (u:User)
WITH u, count { (u)-[:RATED]->() } AS degree
RETURN 'User' AS nodeType,
       toString(u.userId) AS identifier,
       degree
ORDER BY degree DESC
LIMIT 5;


// ============================================================
// Q7 — Final 15-row high-degree summary
// Top 5 Users + top 5 Movies + top 5 Genres
// ============================================================

CALL {
  MATCH (u:User)
  WITH u, count { (u)-[:RATED]->() } AS degree
  RETURN 'User' AS nodeType, toString(u.userId) AS identifier, degree
  ORDER BY degree DESC
  LIMIT 5
}
UNION ALL
CALL {
  MATCH (m:Movie)
  WITH m, count { (m)<-[:RATED]-() } AS degree
  RETURN 'Movie' AS nodeType, toString(m.movieId) AS identifier, degree
  ORDER BY degree DESC
  LIMIT 5
}
UNION ALL
CALL {
  MATCH (g:Genre)
  WITH g, count { (g)<-[:HAS_GENRE]-() } AS degree
  RETURN 'Genre' AS nodeType, g.name AS identifier, degree
  ORDER BY degree DESC
  LIMIT 5
}
RETURN nodeType, identifier, degree
ORDER BY degree DESC, nodeType ASC, identifier ASC;