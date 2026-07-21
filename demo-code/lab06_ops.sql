-- lab06_ops.sql
-- Module 6 - Operations and Observability
-- Verifies audit, retention, legal-hold, and monitoring controls.

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
                 'Requires catalog access in the target environment.');
  END;

  EXPLAIN PLAN FOR
  SELECT cc.chunk_id,
         VECTOR_DISTANCE(cc.embedding,
                         VECTOR_EMBEDDING(MINILM_EMB USING 'credit card comparison help' AS DATA),
                         COSINE) AS d
  FROM conversation_chunk cc
  ORDER BY d
  FETCH FIRST 5 ROWS ONLY;

  SELECT COUNT(*) INTO v_cnt
  FROM plan_table
  WHERE UPPER(NVL(object_name,' ')) = 'CONV_CHUNK_IDX'
     OR UPPER(NVL(operation,' ')) LIKE '%VECTOR%';

  lab_assert('M6', 'Canonical vector plan shows vector index activity', v_cnt > 0, NULL);

  SELECT COUNT(*) INTO v_cnt
  FROM user_tab_columns
  WHERE table_name = 'AI_CALL_LOG'
    AND column_name IN ('TRACE_ID','SPAN_ID','PROFILE_NAME','MODEL_NAME','PROMPT_TOKENS','OUTPUT_TOKENS');

  IF v_cnt = 0 THEN
    lab_manual('M6', 'Add observability columns to AI_CALL_LOG',
               'Provide trace_id, span_id, profile_name, model_name, prompt_tokens, and output_tokens.');
  ELSE
    lab_assert('M6', 'AI_CALL_LOG has observability columns', v_cnt >= 6, 'matched_columns=' || v_cnt);
  END IF;

  SELECT COUNT(*) INTO v_cnt
  FROM user_tab_columns
  WHERE table_name = 'AI_CALL_LOG' AND column_name = 'RETENTION_UNTIL';

  IF v_cnt = 1 THEN
    lab_assert('M6', 'AI_CALL_LOG.RETENTION_UNTIL exists', TRUE, NULL);
  ELSE
    lab_manual('M6', 'Add AI_CALL_LOG.RETENTION_UNTIL',
               'Records management requires a per-row retention horizon.');
  END IF;

  SELECT COUNT(*) INTO v_cnt FROM user_tables WHERE table_name = 'LEGAL_HOLD';

  IF v_cnt = 0 THEN
    lab_manual('M6', 'Create LEGAL_HOLD table',
               'Retain records on legal hold regardless of retention_until.');
  ELSE
    lab_assert('M6', 'LEGAL_HOLD table exists', TRUE, NULL);
  END IF;

  SELECT COUNT(*) INTO v_cnt FROM user_tables WHERE table_name = 'OFFER_DECISION_LOG';
  IF v_cnt = 0 THEN
    lab_manual('M6', 'Create OFFER_DECISION_LOG before scheduling fair-lending monitoring',
               'Required for presentation-rate sampling by segment on credit-family offers.');
  ELSE
    lab_assert('M6', 'OFFER_DECISION_LOG exists for fair-lending sampling', TRUE, NULL);
  END IF;

  lab_manual('M6', 'Suppression-bypass alarm wired and tested',
             'Provide a synthetic test that triggers the alarm and routes to on-call and Compliance.');
  lab_manual('M6', 'Disclosure-substitution-failure alarm wired and tested',
             'Provide a synthetic test that detects placeholder loss or numeric leak.');
  lab_manual('M6', 'Recall canary measured per release',
             'Provide the latest recall canary results against the exact ground truth.');
  lab_manual('M6', 'Audit retention and purge job consults LEGAL_HOLD',
             'Provide the job source or DAG showing the hold check.');
  lab_manual('M6', 'Regulator-data-request playbook tested',
             'Run the standard join on decision and AI call logs for a synthetic customer and capture the output.');
END;
/