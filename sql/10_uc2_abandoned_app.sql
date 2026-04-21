-- 10_uc2_abandoned_app.sql
-- Purpose: UC2 abandoned application nudge using vector retrieval + Select AI summary.
-- Run order: 10
-- Dependencies: sql/06_embed_and_index.sql, sql/08_select_ai_profile.sql

VAR cid NUMBER;
EXEC :cid := 1;

WITH abandoned_context AS (
  SELECT a.app_id,
         a.updated_at,
         JSON_SERIALIZE(a.fields_json PRETTY) AS fields_text
  FROM application a
  WHERE a.customer_id = :cid
    AND a.status = 'ABANDONED'
  ORDER BY a.updated_at DESC
  FETCH FIRST 1 ROW ONLY
),
similar_chunks AS (
  SELECT cc.chunk_text,
         VECTOR_DISTANCE(
           cc.embedding,
           VECTOR_EMBEDDING(MINILM_EMB USING 'abandoned loan application follow-up help' AS DATA),
           COSINE
         ) AS distance
  FROM conversation_chunk cc
  ORDER BY distance
  FETCH FIRST 5 ROWS ONLY
)
SELECT app_id, updated_at, fields_text
FROM abandoned_context;

SELECT chunk_text, distance
FROM similar_chunks;

SELECT DBMS_CLOUD_AI.GENERATE(
  prompt => 'Create one empathetic nudge for customer ' || :cid ||
            ' who abandoned a loan application. Use the most likely objections from similar conversations.',
  action => 'chat'
) AS nudge_text
FROM dual;
