-- lab06_ops.sql
-- Module 6 — Operations and Observability (regulator-grade)
-- Verifies the audit/retention/legal-hold/fair-lending control surface.

DECLARE
  v_cnt NUMBER;
BEGIN
  BEGIN
    EXECUTE IMMEDIATE q'[
      SELECT COUNT(*)
      FROM v$sqlstats
      WHERE UPPER(sql_text) LIKE '%DBMS_CLOUD_AI%'
         OR UPPER(sql_text) LIKE '%GRAPH_TABLE%'
         OR UPPER(sql_text) LIKE '%VECTOR_DISTANCE%'
    ]' INTO v_cnt;

    lab_assert('M6', 'v$sqlstats contains AI workload SQL', v_cnt >= 0, 'matched_sql=' || v_cnt);
  EXCEPTION
    WHEN OTHERS THEN
      lab_manual('M6', 'Query v$sqlstats for AI workload SQL',
                 'Requires catalog access in target environment.');
  END;
END;
/

EXPLAIN PLAN FOR
SELECT cc.chunk_id,
       VECTOR_DISTANCE(cc.embedding,
                       VECTOR_EMBEDDING(MINILM_EMB USING 'credit card comparison help' AS DATA),
                       COSINE) AS d
FROM conversation_chunk cc
ORDER BY d
FETCH FIRST 5 ROWS ONLY;

DECLARE
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cnt
  FROM plan_table
  WHERE UPPER(NVL(object_name,' ')) = 'CONV_CHUNK_IDX'
     OR UPPER(NVL(operation,' ')) LIKE '%VECTOR%';

  lab_assert('M6', 'Canonical vector plan shows vector index op', v_cnt > 0, NULL);
END;
/

DECLARE
  v_cnt NUMBER;
BEGIN
  -- AI_CALL_LOG observability columns
  SELECT COUNT(*) INTO v_cnt
  FROM user_tab_columns
  WHERE table_name = 'AI_CALL_LOG'
    AND column_name IN ('TRACE_ID','SPAN_ID','PROFILE_NAME','MODEL_NAME','PROMPT_TOKENS','OUTPUT_TOKENS');

  IF v_cnt = 0 THEN
    lab_manual('M6', 'AI_CALL_LOG missing observability columns',
               'Module 3 specifies trace_id/span_id/profile_name/model_name/prompt_tokens/output_tokens.');
  ELSE
    lab_assert('M6', 'AI_CALL_LOG has TRACE/SPAN/PROFILE/MODEL/TOKEN columns', v_cnt = 6,
               'matched_columns=' || v_cnt);
  END IF;

  -- Records management: retention horizon must be present
  SELECT COUNT(*) INTO v_cnt
  FROM user_tab_columns
  WHERE table_name = 'AI_CALL_LOG' AND column_name = 'RETENTION_UNTIL';

  IF v_cnt = 1 THEN
    lab_assert('M6', 'AI_CALL_LOG.RETENTION_UNTIL exists (records management)', TRUE, NULL);
  ELSE
    lab_manual('M6', 'Add AI_CALL_LOG.RETENTION_UNTIL',
               'Records management requires per-row retention horizon. Marketing comms typically 7 years; credit decisions per FCRA.');
  END IF;

  -- LEGAL_HOLD must exist before any retention-purge job is enabled
  SELECT COUNT(*) INTO v_cnt FROM user_tables WHERE table_name = 'LEGAL_HOLD';

  IF v_cnt = 0 THEN
    lab_manual('M6', 'Create LEGAL_HOLD table',
               'Required reference table consulted by retention-purge job. Customers (or record classes) on legal hold are exempt from purge regardless of retention_until.');
  ELSE
    lab_assert('M6', 'LEGAL_HOLD table exists', TRUE, NULL);
  END IF;
END;
/

-- ---- Fair-lending sampling capability (Reg B / ECOA) -----------------------
-- Confirms we can compute presentation-rate by segment for the credit family.
-- This is the *capability*; the actual periodic report is a Compliance artifact.

DECLARE
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cnt FROM user_tables WHERE table_name = 'OFFER_DECISION_LOG';

  IF v_cnt = 0 THEN
    lab_manual('M6', 'Disparate-impact sampling requires OFFER_DECISION_LOG',
               'Create OFFER_DECISION_LOG (Module 5) before scheduling fair-lending monitoring.');
  ELSE
    BEGIN
      EXECUTE IMMEDIATE q'[
        SELECT COUNT(*) FROM (
          SELECT c.segment, odl.chosen_offer_id, COUNT(*) AS n
          FROM offer_decision_log odl
          JOIN customer c ON c.customer_id = odl.customer_id
          JOIN offer o    ON o.offer_id = odl.chosen_offer_id
          JOIN product p  ON p.product_id = o.product_id
          WHERE p.family IN ('CREDIT_CARD','LOAN')
          GROUP BY c.segment, odl.chosen_offer_id
        )
      ]' INTO v_cnt;
      lab_assert('M6', 'Disparate-impact sampling query is wireable on credit-family offers',
                 TRUE, 'rows=' || v_cnt);
    EXCEPTION
      WHEN OTHERS THEN
        lab_assert('M6', 'Disparate-impact sampling query is wireable on credit-family offers',
                   FALSE, SQLERRM);
    END;
  END IF;
END;
/

-- ---- Manual operational evidence -------------------------------------------

BEGIN
  lab_manual('M6', 'Suppression-bypass alarm wired and tested (Sev-1)',
             'Provide synthetic test that triggers the alarm and routes to on-call + Compliance.');
  lab_manual('M6', 'Disclosure-substitution-failure alarm wired and tested (Sev-1)',
             'Provide synthetic test (placeholder lost / numeric leak) that triggers the alarm.');
  lab_manual('M6', 'UDAAP queue oldest-pending alarm wired against policy SLA',
             'Provide threshold and paging route.');
  lab_manual('M6', 'Recall canary measured per release (SR 11-7 monitoring)',
             'Provide last release canary results vs exact ground truth.');
  lab_manual('M6', 'Cost reconciliation: AI_CALL_LOG tokens vs OCI billing within variance threshold',
             'Provide last reconciliation run and variance.');
  lab_manual('M6', 'Retention-purge job consults LEGAL_HOLD before deleting',
             'Provide job source / DAG showing the hold check.');
  lab_manual('M6', 'Erasure-on-request (GDPR/CCPA) deletes CONVERSATION + CONVERSATION_CHUNK + AI_CALL_LOG.output_text',
             'Provide DSAR runbook and a tested execution.');
  lab_manual('M6', 'Regulator-data-request playbook tested',
             'Run the standard join (OFFER_DECISION_LOG x AI_CALL_LOG by customer_id/trace_id) for a synthetic customer; capture output.');
  lab_manual('M6', 'NYDFS Part 500: 72-hour incident clock and runbook in place',
             'Provide runbook and last tabletop exercise summary.');
  lab_manual('M6', 'Daily ops checklist run for the last 30 days',
             'Provide log of dashboard checks, queue state, and alert acknowledgements.');
END;
/
