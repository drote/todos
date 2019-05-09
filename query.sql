SELECT l.*, 
    COUNT(td.id) AS todos_count,
    COUNT(NULLIF(td.completed, true)) AS todos_remaining
  FROM lists AS l
  LEFT JOIN todos AS td ON td.list_id = l.id
 GROUP BY l.id;