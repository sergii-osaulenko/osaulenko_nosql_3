// ==========================================
// ЗАПИТ 1: Фільми жанру «Thriller» із середнім рейтингом > 4.0
// ==========================================
MATCH (m:Movie)-[:HAS_GENRE]->(:Genre {name: 'Thriller'})
MATCH (u:User)-[r:RATED]->(m)
WITH m, avg(r.rating) AS avgRating, count(r) AS ratingCount
WHERE avgRating > 4.0 AND ratingCount >= 10 // Відсікаємо фільми з 1-2 випадковими оцінками
RETURN m.title AS title, round(avgRating, 2) AS avgRating, ratingCount
ORDER BY avgRating DESC;

// ==========================================
// ЗАПИТ 2: Користувачі, які поставили оцінку 5 більш ніж 50 фільмам
// ==========================================
MATCH (u:User)-[r:RATED {rating: 5}]->(m:Movie)
WITH u, count(r) AS fiveStarCount
WHERE fiveStarCount > 50
RETURN u.userId AS userId, fiveStarCount
ORDER BY fiveStarCount DESC;

// ==========================================
// ЗАПИТ 3: Фільми, які ОБИДВА користувачі (userId: 1 та 2) оцінили >= 4
// ==========================================
MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User {userId: 2})
WHERE r1.rating >= 4 AND r2.rating >= 4
RETURN m.movieId AS movieId, m.title AS title, r1.rating AS user1Rating, r2.rating AS user2Rating;

// ==========================================
// ЗАПИТ 4: Жанри, які стабільно отримують високі оцінки
// ==========================================
MATCH (g:Genre)<-[:HAS_GENRE]-(m:Movie)<-[r:RATED]-(:User)
WITH g, avg(r.rating) AS avgRating, count(r) AS totalRatings
RETURN g.name AS genre, round(avgRating, 3) AS avgRating, totalRatings
ORDER BY avgRating DESC;

// ==========================================
// ЗАПИТ 5: Рекомендація «Користувачі зі схожими смаками також дивилися»
// Для користувача userId = 1 шукаємо фільми через Collaborative Filtering
// ==========================================
MATCH (target:User {userId: 1})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(similar:User)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND target <> similar
WITH target, similar, count(m) AS sharedHighRated
WHERE sharedHighRated >= 3 // Поріг подібності смаків
MATCH (similar)-[r3:RATED]->(rec:Movie)
WHERE r3.rating >= 4 AND NOT (target)-[:RATED]->(rec)
WITH rec, count(DISTINCT similar) AS similarityScore, avg(r3.rating) AS expectedRating
ORDER BY similarityScore DESC, expectedRating DESC
LIMIT 10
RETURN rec.title AS recommendedMovie, similarityScore, round(expectedRating, 2) AS expectedRating;

// ==========================================
// ЗАПИТ 6: Найкоротший ланцюжок зв’язку між двома користувачами через спільні фільми
// ==========================================
MATCH path = shortestPath(
  (u1:User {userId: 1})-[:RATED*..10]-(u2:User {userId: 100})
)
RETURN path, length(path) AS pathLength;