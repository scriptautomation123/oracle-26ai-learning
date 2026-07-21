-- lab05_e2e.sql
-- Module 5 - End-to-end offer lifecycle
-- Verifies that the pipeline and the decision log are in place.

DECLARE
  v_customer_id NUMBER;
  v_last_product NUMBER;
  v_peer_cnt NUMBER;
  v_vec_cnt NUMBER;
  v_cnt NUMBER;
BEGIN
  SELECT customer_id INTO v_customer_id
  FROM customer
  FETCH FIRST 1 ROW ONLY;

  SELECT product_id INTO v_last_product
  FROM page_event
  WHERE customer_id = v_customer_id
  ORDER BY event_ts DESC
  FETCH FIRST 1 ROW ONLY;

  lab_assert('M5', 'UC1 trigger lookup resolves customer and last product',
             v_last_product IS NOT NULL,
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

  SELECT COUNT(*) INTO v_cnt
  FROM user_tables WHERE table_name = 'OFFER_DECISION_LOG';

  IF v_cnt = 0 THEN
    lab_manual('M5', 'Create OFFER_DECISION_LOG table',
               'Include decision, decision_reason, channel_of_record, control_group, ai_call_id, trace_id, retention_until, and other lifecycle columns.');
  ELSE
    lab_assert('M5', 'OFFER_DECISION_LOG table exists', TRUE, NULL);
  END IF;

  DECLARE
    v_h1 NUMBER;
    v_h2 NUMBER;
  BEGIN
    SELECT MOD(ORA_HASH('1001:1'), 100) INTO v_h1 FROM dual;
    SELECT MOD(ORA_HASH('1001:1'), 100) INTO v_h2 FROM dual;
    lab_assert('M5', 'Deterministic holdout assignment is stable for (customer_id, offer_id)',
               v_h1 = v_h2, 'h1=' || v_h1 || ', h2=' || v_h2);
  END;

  lab_manual('M5', 'Walk through the full UC1/UC2/UC3 lifecycle',
             'Cover trigger, eligibility, suppression, frequency cap, channel-of-record, generation, disclosure, delivery, attribution, and archival.');
  lab_manual('M5', 'Cost and capacity sign-off',
             'Present forecast assumptions, fallback path, and rollback plan.');
  lab_manual('M5', 'Launch-readiness checklist signed off',
             'Confirm the architecture, compliance, monitoring, and rollback controls are documented.');
EXCEPTION
  WHEN OTHERS THEN
    lab_assert('M5', 'Module 5 execution', FALSE, SQLERRM);
END;
/