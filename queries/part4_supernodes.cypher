// Пошук ТОП-20 вузлів з аномально великою кількістю зв'язків
MATCH (n)
RETURN labels(n) AS nodeType, 
       coalesce(n.title, n.name, toString(n.userId)) AS identifier, 
       count{ (n)--() } AS degree
ORDER BY degree DESC
LIMIT 20;