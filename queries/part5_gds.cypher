// ====================================================================
// 5.1. PageRank НА ГРАФІ ФІЛЬМІВ
// ====================================================================
// Крок 1: Матеріалізація ребер фільм-фільм
MATCH (m1:Movie)<-[r1:RATED]-(u:User)-[r2:RATED]->(m2:Movie)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND id(m1) < id(m2)
WITH m1, m2, count(u) AS weight
WHERE size([(m1)<-[:RATED]-() | 1]) > 20
  AND size([(m2)<-[:RATED]-() | 1]) > 20
WITH m1, m2, weight
ORDER BY weight DESC
LIMIT 50000
MERGE (m1)-[co:CO_RATED]-(m2)
SET co.weight = weight;

// Крок 2: Проєкція в пам'ять GDS
CALL gds.graph.project(
  'movieGraph',
  'Movie',
  { CO_RATED: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// Крок 3: Запуск PageRank
CALL gds.pageRank.stream('movieGraph', {
  relationshipWeightProperty: 'weight'
})
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).title AS movieTitle, round(score, 4) AS pageRankScore
ORDER BY score DESC
LIMIT 10;

// Крок 4: Очищення
CALL gds.graph.drop('movieGraph');
MATCH ()-[co:CO_RATED]-() DELETE co;


// ====================================================================
// 5.2. ВИЯВЛЕННЯ СПІЛЬНОТ (LOUVAIN) НА ГРАФІ КОРИСТУВАЧІВ
// ====================================================================
// Крок 1: Матеріалізація ребер схожості користувачів
MATCH (u1:User)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND id(u1) < id(u2)
WITH u1, u2, count(m) AS weight
ORDER BY weight DESC
LIMIT 50000
MERGE (u1)-[sim:SIMILAR]-(u2)
SET sim.weight = weight;

// Крок 2: Проєкція в пам'ять
CALL gds.graph.project(
  'userSimilarity',
  'User',
  { SIMILAR: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// Крок 3: Запуск Louvain, аналіз кластерів та ТОП-3 жанри для кожної спільноти
CALL gds.louvain.stream('userSimilarity', {
  relationshipWeightProperty: 'weight'
})
YIELD nodeId, communityId
WITH communityId, collect(gds.util.asNode(nodeId)) AS users, count(*) AS communitySize
ORDER BY communitySize DESC
LIMIT 10
UNWIND users AS u
MATCH (u)-[r:RATED]->(m:Movie)-[:HAS_GENRE]->(g:Genre)
WHERE r.rating >= 4
WITH communityId, communitySize, g.name AS genre, count(*) AS genreCount
ORDER BY communityId, genreCount DESC
WITH communityId, communitySize, collect(genre)[..3] AS top3Genres
RETURN communityId, communitySize, top3Genres
ORDER BY communitySize DESC;

// Крок 4: Очищення (Залишаємо ребра SIMILAR для задачі 5.3)
CALL gds.graph.drop('userSimilarity');


// ====================================================================
// 5.3. НАЙКОРОТШИЙ ШЛЯХ (DIJKSTRA) МІЖ КОРИСТУВАЧАМИ
// ====================================================================
// Крок 1: Створення проєкції з існуючих ребер SIMILAR
CALL gds.graph.project(
  'userGraph',
  'User',
  { SIMILAR: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// Крок 2: Пошук найкоротшого шляху між користувачем 1 та 100
MATCH (u1:User {userId: 1}), (u2:User {userId: 100})
CALL gds.shortestPath.dijkstra.stream('userGraph', {
  sourceNode: id(u1),
  targetNode: id(u2),
  relationshipWeightProperty: 'weight'
})
YIELD index, sourceNode, targetNode, totalCost, nodeIds, costs, path
RETURN totalCost, [nodeId in nodeIds | gds.util.asNode(nodeId).userId] AS userPath;

// Крок 3: Фінальне очищення
CALL gds.graph.drop('userGraph');
MATCH ()-[sim:SIMILAR]-() DELETE sim;