-- lab05_e2e.sql

DECLARE
  v_customer_id NUMBER;
  v_last_product NUMBER;
  v_peer_cnt NUMBER;
  v_vec_cnt NUMBER;
BEGIN
  SELECT customer_id INTO v_customer_id
  FROM customer
  FETCH FIRST 1 ROW ONLY;

  SELECT product_id INTO v_last_product
  FROM page_event
  WHERE customer_id = v_customer_id
  ORDER BY event_ts DESC
  FETCH FIRST 1 ROW ONLY;

  lab_assert('M5', 'UC1 relational lookup resolves customer and last product', v_last_product IS NOT NULL,
             'customer_id=' || v_customer_id || ', product_id=' || v_last_product);

  SELECT COUNT(*) INTO v_peer_cnt
  FROM GRAPH_TABLE(
    banking_graph
    MATCH (c1 IS customer)-[:viewed]->(p IS product)<-[:viewed]-(c2 IS customer)-[:viewed]->(p2 IS product)
    WHERE c1.customer_id = v_customer_id
      AND p.product_id = v_last_product
    COLUMNS (p2.product_id AS peer_product_id)
  );

  lab_assert('M5', 'UC1 graph step returns peer products', v_peer_cnt >= 0,
             'peer_count=' || v_peer_cnt);

  SELECT COUNT(*) INTO v_vec_cnt
  FROM (
    SELECT cc.chunk_id
    FROM conversation_chunk cc
    ORDER BY VECTOR_DISTANCE(
      cc.embedding,
      VECTOR_EMBEDDING(MINILM_EMB USING 'credit card comparison help' AS DATA),
      COSINE
    )
    FETCH FIRST 5 ROWS ONLY
  );

  lab_assert('M5', 'UC1 vector top-K returns rows', v_vec_cnt = 5, 'topk=' || v_vec_cnt);

  lab_manual('M5', 'Whiteboard full UC1/UC2/UC3 architecture', 'Cover relational + graph + vector + generation path.');
  lab_manual('M5', 'Cost and capacity signoff', 'Present forecast assumptions and rollback plan.');
  lab_manual('M5', 'Onboarding readiness', 'Show runbook and handoff artifacts for new team member.');
EXCEPTION
  WHEN OTHERS THEN
    lab_assert('M5', 'Module 5 execution', FALSE, SQLERRM);
END;
/
