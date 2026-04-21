-- 09_uc1_card_view.sql
-- Purpose: UC1 query combining last card page view, graph-based peer product traversal, and vector retrieval.
-- Prerequisite: Run after 06_embed_and_index.sql and 07_property_graph.sql.

WITH last_view AS (
  SELECT product_id
  FROM page_event
  WHERE customer_id = :cid
  ORDER BY event_ts DESC
  FETCH FIRST 1 ROW ONLY
),
peer_products AS (
  SELECT *
  FROM GRAPH_TABLE(
    banking_graph
    MATCH (c1 IS customer)-[:viewed]->(p IS product)<-[:viewed]-(c2 IS customer)-[:viewed]->(p2 IS product)
    WHERE c1.customer_id = :cid
      AND p.product_id = (SELECT product_id FROM last_view)
    COLUMNS (
      p2.product_id AS peer_product_id,
      p2.name AS peer_product
    )
  )
)
SELECT p.peer_product,
       cc.chunk_text,
       VECTOR_DISTANCE(
         cc.embedding,
         VECTOR_EMBEDDING(MINILM_EMB USING 'credit card comparison help' AS DATA),
         COSINE
       ) AS distance
FROM conversation_chunk cc
CROSS JOIN peer_products p
ORDER BY distance
FETCH FIRST 5 ROWS ONLY;
