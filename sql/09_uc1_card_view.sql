-- 09_uc1_card_view.sql
-- Purpose: UC1 proactive nudge retrieval from relational + graph + vector context.
-- Run order: 9
-- Dependencies: sql/06_embed_and_index.sql, sql/07_property_graph.sql

VAR cid NUMBER;
EXEC :cid := 1;

WITH last_view AS (
  SELECT product_id
  FROM page_event
  WHERE customer_id = :cid
  ORDER BY event_ts DESC
  FETCH FIRST 1 ROW ONLY
),
peer_products AS (
  SELECT peer_product_id, peer_product_name
  FROM GRAPH_TABLE(
    banking_graph
    MATCH
      (c1 IS customer)-[v1 IS viewed]->(p1 IS product)<-[v2 IS viewed]-(c2 IS customer)-[v3 IS viewed]->(p2 IS product)
    WHERE c1.customer_id = :cid
      AND p1.product_id = (SELECT product_id FROM last_view)
    COLUMNS (
      p2.product_id AS peer_product_id,
      p2.name AS peer_product_name
    )
  )
)
SELECT pp.peer_product_name,
       cc.chunk_text,
       cc.distance
FROM peer_products pp
CROSS APPLY (
  SELECT chunk_text,
         VECTOR_DISTANCE(
           embedding,
           VECTOR_EMBEDDING(MINILM_EMB USING 'credit card comparison help' AS DATA),
           COSINE
         ) AS distance
  FROM conversation_chunk
  ORDER BY distance
  FETCH FIRST 1 ROW ONLY
) cc
ORDER BY distance
FETCH FIRST 5 ROWS ONLY;
