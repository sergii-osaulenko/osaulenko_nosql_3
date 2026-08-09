// ============================================================
// PART 4 — SUPERNODE / HIGH-DEGREE ANALYSIS
// ============================================================
//
// A supernode candidate is identified using the 99th percentile
// of the degree distribution for each node type.
//
// User degree   = number of RATED relationships
// Movie degree  = number of incoming RATED relationships
// Genre degree  = number of HAS_GENRE relationships
//
// The analysis is descriptive and does not modify the graph.
// ============================================================


// ============================================================
// Q1. User degree distribution
// ============================================================

MATCH (u:User)
WITH collect(count { (u)-[:RATED]->() }) AS degrees
UNWIND degrees AS degree
RETURN
    count(degrees) AS users,
    round(avg(degree) * 100.0) / 100.0 AS avgDegree,
    percentileCont(degree, 0.5) AS medianDegree,
    percentileCont(degree, 0.95) AS p95Degree,
    percentileCont(degree, 0.99) AS p99Degree,
    max(degree) AS maxDegree;


// ============================================================
// Q2. Top User high-degree nodes
// ============================================================

MATCH (u:User)
WITH u, count { (u)-[:RATED]->() } AS degree
WHERE degree >= 906.6
RETURN
    u.userId AS userId,
    u.gender AS gender,
    u.age AS age,
    u.occupation AS occupation,
    degree
ORDER BY degree DESC;


// ============================================================
// Q3. Movie degree distribution
// ============================================================

MATCH (m:Movie)
WITH collect(count { (m)<-[:RATED]-() }) AS degrees
UNWIND degrees AS degree
RETURN
    count(degrees) AS movies,
    round(avg(degree) * 100.0) / 100.0 AS avgDegree,
    percentileCont(degree, 0.5) AS medianDegree,
    percentileCont(degree, 0.95) AS p95Degree,
    percentileCont(degree, 0.99) AS p99Degree,
    max(degree) AS maxDegree;


// ============================================================
// Q4. Top Movie high-degree nodes
// ============================================================

MATCH (m:Movie)
WITH m, count { (m)<-[:RATED]-() } AS degree
WHERE degree >= 1756.76
RETURN
    m.movieId AS movieId,
    m.title AS title,
    m.year AS year,
    degree
ORDER BY degree DESC;


// ============================================================
// Q5. Genre degree distribution
// ============================================================

MATCH (g:Genre)
WITH collect(count { (g)<-[:HAS_GENRE]-() }) AS degrees
UNWIND degrees AS degree
RETURN
    count(degrees) AS genres,
    round(avg(degree) * 100.0) / 100.0 AS avgDegree,
    percentileCont(degree, 0.5) AS medianDegree,
    percentileCont(degree, 0.95) AS p95Degree,
    percentileCont(degree, 0.99) AS p99Degree,
    max(degree) AS maxDegree;


// ============================================================
// Q6. Top Genre high-degree nodes
// ============================================================

MATCH (g:Genre)
WITH g, count { (g)<-[:HAS_GENRE]-() } AS degree
WHERE degree >= 1534.49
RETURN
    g.name AS genre,
    degree
ORDER BY degree DESC;


// ============================================================
// Q7. Overall high-degree summary
// ============================================================

CALL {
    MATCH (u:User)
    WITH u, count { (u)-[:RATED]->() } AS degree
    RETURN
        'User' AS nodeType,
        u.userId AS identifier,
        degree
    ORDER BY degree DESC
    LIMIT 5
}
RETURN nodeType, identifier, degree
ORDER BY degree DESC;