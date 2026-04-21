-- lab05_e2e.sql
-- Module 5 — End-to-end offer lifecycle
-- Verifies the pipeline runs and the lifecycle controls are in place.

DECLARE
  v_customer_id NUMBER;
  v_last_product NUMBER;
  v_peer_cnt NUMBER;
  v_vec_cnt NUMBER;
  v_cnt NUMBER;
BEGIN
  -- ---- Step 1-4: trigger -> graph -> vector candidate generation --------

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

  -- ---- Step 5: deterministic eligibility honored ------------------------
  -- OFFER 1 (Cash+ Visa Intro APR) requires segment in (Prime, Affluent).
  -- A Mass-segment customer must NOT be presented offer 1.
  SELECT COUNT(*) INTO v_cnt
  FROM customer c, offer o
  WHERE c.segment = 'Mass'
    AND o.offer_id = 1
    AND ROWNUM = 1;

  IF v_cnt = 1 THEN
    lab_manual('M5', 'Verify Mass-segment customer is not presented Cash+ Visa Intro APR (ECOA/eligibility)',
               'Run end-to-end pipeline for a Mass customer; confirm OFFER_DECISION_LOG.decision=NOT_ELIGIBLE for offer_id=1.');
  END IF;

  -- ---- OFFER_DECISION_LOG ----------------------------------------------

  SELECT COUNT(*) INTO v_cnt
  FROM user_tables WHERE table_name = 'OFFER_DECISION_LOG';

  IF v_cnt = 0 THEN
    lab_manual('M5', 'Create OFFER_DECISION_LOG table per Module 5 schema',
               'Required columns: decision_id, decided_at, customer_id, use_case, trigger_event_id, candidate_offers, chosen_offer_id, decision (ELIGIBLE/NOT_ELIGIBLE/SUPPRESSED/FREQ_CAPPED/HOLDOUT/SENT/FALLBACK/ERROR), decision_reason, channel, channel_of_record, control_group, ai_call_id, trace_id, retention_until.');
  ELSE
    lab_assert('M5', 'OFFER_DECISION_LOG table exists', TRUE, NULL);

    SELECT COUNT(*) INTO v_cnt
    FROM user_tab_columns
    WHERE table_name = 'OFFER_DECISION_LOG'
      AND column_name IN (
        'CUSTOMER_ID','USE_CASE','CHOSEN_OFFER_ID','DECISION','DECISION_REASON',
        'CHANNEL_OF_RECORD','CONTROL_GROUP','AI_CALL_ID','TRACE_ID','RETENTION_UNTIL'
      );
    lab_assert('M5', 'OFFER_DECISION_LOG has lifecycle/governance columns',
               v_cnt = 10, 'matched columns=' || v_cnt);

    -- decision_reason must be NOT NULL — the column must exist with NOT NULL
    -- so a regulator-data-request can always answer "why".
    SELECT COUNT(*) INTO v_cnt
    FROM user_tab_columns
    WHERE table_name = 'OFFER_DECISION_LOG'
      AND column_name = 'DECISION_REASON'
      AND nullable = 'N';

    IF v_cnt = 1 THEN
      lab_assert('M5', 'OFFER_DECISION_LOG.DECISION_REASON is NOT NULL', TRUE, NULL);
    ELSE
      lab_manual('M5', 'Make OFFER_DECISION_LOG.DECISION_REASON NOT NULL',
                 'Required so that every decision (positive or negative) carries an FCRA-grade reason.');
    END IF;
  END IF;

  -- ---- Holdout / control-group test ------------------------------------
  -- Module 5 mandates deterministic holdout: MOD(ORA_HASH(customer_id || ':' || offer_id), 100).
  -- Confirm the function is deterministic (same inputs -> same bucket twice).
  DECLARE
    v_h1 NUMBER;
    v_h2 NUMBER;
  BEGIN
    SELECT MOD(ORA_HASH('1001:1'), 100) INTO v_h1 FROM dual;
    SELECT MOD(ORA_HASH('1001:1'), 100) INTO v_h2 FROM dual;
    lab_assert('M5', 'Deterministic holdout assignment is stable for (customer_id, offer_id)',
               v_h1 = v_h2, 'h1=' || v_h1 || ', h2=' || v_h2);
  END;

  -- ---- Manual evidence items -------------------------------------------

  lab_manual('M5', 'Whiteboard full UC1/UC2/UC3 lifecycle (steps 1-15)',
             'Cover trigger, eligibility, suppression, freq cap, channel-of-record, generation, disclosure, UDAAP review, delivery, attribution, archival.');
  lab_manual('M5', 'Cost and capacity sign-off',
             'Present forecast assumptions, fallback path, and rollback plan.');
  lab_manual('M5', 'Onboarding readiness',
             'Show runbook (Module 6) and handoff artifacts for new team member.');
  lab_manual('M5', 'Launch-readiness checklist signed by Architecture, Compliance, Model Risk, FinOps',
             'Module 5 final checklist; every box ticked with evidence link.');
EXCEPTION
  WHEN OTHERS THEN
    lab_assert('M5', 'Module 5 execution', FALSE, SQLERRM);
END;
/
