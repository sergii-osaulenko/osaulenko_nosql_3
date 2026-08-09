// Part 5 — GDS: PageRank, Louvain, Dijkstra
// Final reproducible version based on the successful local Neo4j Browser run.
// GDS observed in the practical run: 2026.06.0.
//
// Important reproducibility choice:
// all top-50,000 materializations use a deterministic tie-breaker after
// weight DESC. Application IDs are used instead of deprecated id().

// ============================================================
// 5.1 PageRank — Movie co-rating graph
// ============================================================

MATCH (m1:Movie)<-[r1:RATED]-(u:User)-[r2:RATED]->(m2:Movie)
WHERE r1.rating >= 4
  AND r2.rating >= 4
  AND m1.movieId < m2.movieId
WITH m1, m2, count(u) AS weight
WHERE count { (m1)<-[:RATED]-() } > 20
  AND count { (m2)<-[:RATED]-() } > 20
WITH m1, m2, weight
ORDER BY weight DESC, m1.movieId ASC, m2.movieId ASC
LIMIT 50000
MERGE (m1)-[co:CO_RATED]->(m2)
SET co.weight = weight;

CALL gds.graph.project(
  'movieGraph',
  'Movie',
  {CO_RATED: {orientation: 'UNDIRECTED', properties: 'weight'}}
)
YIELD graphName, nodeCount, relationshipCount
RETURN graphName, nodeCount, relationshipCount;

CALL gds.pageRank.stream(
  'movieGraph',
  {relationshipWeightProperty: 'weight', dampingFactor: 0.85}
)
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).movieId AS movieId,
       gds.util.asNode(nodeId).title AS title,
       score
ORDER BY score DESC, movieId ASC
LIMIT 20;

// Evidence visualization — run before cleanup.
// This query returns the same top-50 materialized CO_RATED relationships
// used for the submission screenshot.
MATCH (m1:Movie)-[r:CO_RATED]->(m2:Movie)
RETURN m1, r, m2
ORDER BY r.weight DESC, m1.movieId ASC, m2.movieId ASC
LIMIT 50;

CALL gds.graph.drop('movieGraph');
MATCH ()-[co:CO_RATED]->() DELETE co;


// ============================================================
// 5.2 Louvain — User similarity graph
// ============================================================

MATCH (u1:User)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE r1.rating >= 4
  AND r2.rating >= 4
  AND u1.userId < u2.userId
WITH u1, u2, count(m) AS weight
ORDER BY weight DESC, u1.userId ASC, u2.userId ASC
LIMIT 50000
MERGE (u1)-[sim:SIMILAR]->(u2)
SET sim.weight = weight;

CALL gds.graph.project(
  'userSimilarity',
  'User',
  {SIMILAR: {orientation: 'UNDIRECTED', properties: 'weight'}}
)
YIELD graphName, nodeCount, relationshipCount
RETURN graphName, nodeCount, relationshipCount;

CALL gds.louvain.stats(
  'userSimilarity',
  {relationshipWeightProperty: 'weight', concurrency: 1}
)
YIELD communityCount, modularity
RETURN communityCount, modularity;

CALL gds.louvain.stream(
  'userSimilarity',
  {relationshipWeightProperty: 'weight', concurrency: 1}
)
YIELD nodeId, communityId
WITH communityId, count(*) AS communitySize
RETURN communityId, communitySize
ORDER BY communitySize DESC, communityId ASC
LIMIT 10;

CALL gds.louvain.stream(
  'userSimilarity',
  {relationshipWeightProperty: 'weight', concurrency: 1}
)
YIELD nodeId, communityId
WITH communityId, collect(gds.util.asNode(nodeId)) AS communityUsers
WITH communityId, communityUsers
ORDER BY size(communityUsers) DESC, communityId ASC
LIMIT 10
UNWIND communityUsers AS u
MATCH (u)-[r:RATED]->(m:Movie)-[:HAS_GENRE]->(g:Genre)
WHERE r.rating >= 4
WITH communityId, g.name AS genre, count(*) AS highRatings
ORDER BY communityId ASC, highRatings DESC, genre ASC
WITH communityId,
     collect({genre: genre, highRatings: highRatings})[0..3] AS topGenres
RETURN communityId, topGenres
ORDER BY communityId ASC;

// Evidence visualization — run before cleanup.
// Browser node captions may show age depending on the active style;
// user identity is determined by userId in the query.
MATCH (u1:User)-[r:SIMILAR]->(u2:User)
RETURN u1, r, u2
ORDER BY r.weight DESC, u1.userId ASC, u2.userId ASC
LIMIT 50;

CALL gds.graph.drop('userSimilarity');
MATCH ()-[sim:SIMILAR]->() DELETE sim;


// ============================================================
// 5.3 Dijkstra — weighted shortest path between users
// SIMILAR.weight = shared high-rated movies.
// cost = 1 / weight, so stronger similarity means lower path cost.
// ============================================================

MATCH (u1:User)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE r1.rating >= 4
  AND r2.rating >= 4
  AND u1.userId < u2.userId
WITH u1, u2, count(m) AS weight
ORDER BY weight DESC, u1.userId ASC, u2.userId ASC
LIMIT 50000
MERGE (u1)-[sim:SIMILAR]->(u2)
SET sim.weight = weight,
    sim.cost = 1.0 / weight;

CALL gds.graph.project(
  'userGraph',
  'User',
  {SIMILAR: {orientation: 'UNDIRECTED', properties: 'cost'}}
)
YIELD graphName, nodeCount, relationshipCount
RETURN graphName, nodeCount, relationshipCount;

// Selected connected pair observed in the practical top-50k graph.
MATCH (source:User {userId: 4169})
WITH source
MATCH (target:User {userId: 4277})
CALL gds.shortestPath.dijkstra.stream(
  'userGraph',
  {
    sourceNode: source,
    targetNodes: target,
    relationshipWeightProperty: 'cost'
  }
)
YIELD index, sourceNode, targetNode, totalCost, nodeIds, costs
RETURN index,
       gds.util.asNode(sourceNode).userId AS sourceUser,
       gds.util.asNode(targetNode).userId AS targetUser,
       totalCost,
       size(nodeIds) - 1 AS hops,
       [nodeId IN nodeIds | gds.util.asNode(nodeId).userId] AS userPath,
       costs;

// Evidence visualization — selected pair.
MATCH (u1:User {userId: 4169})-[r:SIMILAR]->(u2:User {userId: 4277})
RETURN u1, r, u2;

// Multi-pair small-world check
UNWIND [
  [4169, 4277],
  [2237, 3658],
  [5054, 5047],
  [3512, 4279],
  [2244, 5239],
  [5636, 5684],
  [1119, 3681],
  [5809, 5077],
  [817, 4484],
  [5458, 5722]
] AS pair
MATCH (source:User {userId: pair[0]})
WITH pair, source
MATCH (target:User {userId: pair[1]})
CALL gds.shortestPath.dijkstra.stream(
  'userGraph',
  {
    sourceNode: source,
    targetNodes: target,
    relationshipWeightProperty: 'cost'
  }
)
YIELD sourceNode, targetNode, totalCost, nodeIds
RETURN gds.util.asNode(sourceNode).userId AS sourceUser,
       gds.util.asNode(targetNode).userId AS targetUser,
       totalCost,
       size(nodeIds) - 1 AS hops,
       [nodeId IN nodeIds | gds.util.asNode(nodeId).userId] AS userPath
ORDER BY hops ASC, sourceUser ASC, targetUser ASC;

CALL gds.graph.drop('userGraph');
MATCH ()-[sim:SIMILAR]->() DELETE sim;

// Final cleanup verification
MATCH ()-[r:SIMILAR]->()
RETURN count(r) AS similarRelationships;