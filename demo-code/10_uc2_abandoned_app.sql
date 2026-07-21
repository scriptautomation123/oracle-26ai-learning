-- 10_uc2_abandoned_app.sql
-- Purpose: UC2 query finding abandoned applications (>1 hour) and similar past conversation snippets.
-- Prerequisite: Run after 06_embed_and_index.sql.

WITH abandoned AS (
  SELECT a.app_id,
         a.customer_id,
         a.product_id,
         a.updated_at,
         a.fields_json
  FROM application a
  WHERE a.status = 'STARTED'
    AND a.updated_at < SYSTIMESTAMP - INTERVAL '1' HOUR
)
SELECT ab.app_id,
       ab.customer_id,
       p.name AS product_name,
       cc.chunk_text,
       VECTOR_DISTANCE(
         cc.embedding,
         VECTOR_EMBEDDING(MINILM_EMB USING 'application abandoned income verification step' AS DATA),
         COSINE
       ) AS distance
FROM abandoned ab
JOIN product p ON p.product_id = ab.product_id
CROSS JOIN conversation_chunk cc
ORDER BY distance
FETCH FIRST 10 ROWS ONLY;
