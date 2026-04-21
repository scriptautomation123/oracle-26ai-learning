-- 06_embed_and_index.sql
-- Purpose: Generate embeddings for conversations and create vector index.
-- Run order: 6
-- Dependencies: sql/03_load_onnx_model.sql, sql/05_transform.sql

INSERT INTO conversation_chunk (conv_id, chunk_text, embedding)
SELECT c.conv_id,
       SUBSTR(c.transcript, 1, 3500) AS chunk_text,
       VECTOR_EMBEDDING(MINILM_EMB USING SUBSTR(c.transcript, 1, 3500) AS DATA) AS embedding
FROM conversation c;

CREATE VECTOR INDEX conv_chunk_idx
ON conversation_chunk (embedding)
ORGANIZATION NEIGHBOR PARTITIONS
DISTANCE COSINE
WITH TARGET ACCURACY 90;

COMMIT;
