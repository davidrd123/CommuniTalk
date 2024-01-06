SELECT  p.*, 
        GREATEST(p.created_at, c.created_at) as gr_created_at 
  FROM posts p
  LEFT join comments c
  ON p.id = c.post_id
  WHERE p.id = 1
  ORDER BY GREATEST(p.created_at, c.created_at) DESC
  LIMIT 1;

SELECT MAX(c.created_at) FROM comments c
  LEFT JOIN posts p
  ON p.id = c.post_id
  WHERE p.id = 1;

SELECT p.*,
      (SELECT CASE WHEN MAX(c.created_at) IS NULL THEN p.created_at ELSE MAX(c.created_at) END
       FROM comments c WHERE c.post_id = p.id) as last_comment_activity
  FROM posts p;