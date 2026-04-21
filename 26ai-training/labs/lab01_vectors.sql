-- lab01_vectors.sql
-- Module 1 — Vectors, Embeddings, ANN Indexes
-- Verifies in-place demo objects and flags governance items the bank must add.

DECLARE
  v_dim NUMBER := 0;
  v_fmt VARCHAR2(30) := 'UNKNOWN';
  v_cnt NUMBER;
BEGIN
  -- ---- Automated: demo-shipped objects ----------------------------------

  BEGIN
    EXECUTE IMMEDIATE
      'SELECT dimension_count, format FROM user_vector_columns WHERE table_name = ''CONVERSATION_CHUNK'' AND column_name = ''EMBEDDING'''
      INTO v_dim, v_fmt;
  EXCEPTION
    WHEN OTHERS THEN
      v_dim := 0;
      v_fmt := 'UNKNOWN';
  END;

  lab_assert('M1', 'conversation_chunk.embedding is VECTOR(384, FLOAT32)',
             v_dim = 384 AND UPPER(v_fmt) LIKE 'FLOAT32%',
             'dimension=' || v_dim || ', format=' || v_fmt);

  SELECT COUNT(*) INTO v_cnt
  FROM user_indexes
  WHERE index_name = 'CONV_CHUNK_IDX'
    AND UPPER(index_type) LIKE '%VECTOR%';

  lab_assert('M1', 'CONV_CHUNK_IDX exists as vector index', v_cnt = 1, NULL);

  SELECT COUNT(*) INTO v_cnt
  FROM user_indexes
  WHERE index_name = 'CONV_CHUNK_IDX'
    AND UPPER(parameters) LIKE '%NEIGHBOR PARTITIONS%';

  lab_assert('M1', 'CONV_CHUNK_IDX uses NEIGHBOR PARTITIONS (IVF)', v_cnt = 1, NULL);
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
  WHERE UPPER(NVL(operation,' ')) LIKE '%VECTOR%'
     OR UPPER(NVL(options,' ')) LIKE '%VECTOR%'
     OR UPPER(NVL(operation,' ')) LIKE '%INDEX%'
        AND UPPER(NVL(object_name,' ')) = 'CONV_CHUNK_IDX';

  lab_assert('M1', 'Canonical top-K plan shows vector index op', v_cnt > 0, NULL);
END;
/

EXPLAIN PLAN FOR
SELECT cc.chunk_id,
       VECTOR_DISTANCE(cc.embedding,
                       VECTOR_EMBEDDING(MINILM_EMB USING 'credit card comparison help' AS DATA),
                       EUCLIDEAN) AS d
FROM conversation_chunk cc
ORDER BY d
FETCH FIRST 5 ROWS ONLY;

DECLARE
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cnt
  FROM plan_table
  WHERE UPPER(NVL(object_name,' ')) = 'CONV_CHUNK_IDX';

  lab_assert('M1', 'Wrong-metric query does not use CONV_CHUNK_IDX', v_cnt = 0,
             'expected metric mismatch fallback');
END;
/

-- ---- Governance / regulatory items (mostly MANUAL until the bank adds them) -

DECLARE
  v_cnt NUMBER;
BEGIN
  -- GLBA: CONVERSATION_CHUNK is derived NPI. Confirm the column the team is
  -- supposed to gate retrieval on is present (consent flag on customer).
  SELECT COUNT(*) INTO v_cnt
  FROM user_tab_columns
  WHERE table_name = 'CUSTOMER'
    AND column_name = 'PERSONALIZATION_OPT_IN';

  IF v_cnt = 1 THEN
    lab_assert('M1', 'CUSTOMER.PERSONALIZATION_OPT_IN exists (GLBA/CCPA consent gate)', TRUE, NULL);
  ELSE
    lab_manual('M1', 'Add CUSTOMER.PERSONALIZATION_OPT_IN consent column',
               'Module 1 narrows vector retrieval by opt-in. Add VARCHAR2(1) Y/N column and source from consent system of record.');
  END IF;

  -- GDPR/CCPA erasure cascade hook (trigger or view that propagates
  -- conversation deletes into conversation_chunk).
  SELECT COUNT(*) INTO v_cnt
  FROM user_triggers
  WHERE table_name = 'CONVERSATION'
    AND triggering_event LIKE '%DELETE%';

  IF v_cnt > 0 THEN
    lab_assert('M1', 'Erasure cascade trigger present on CONVERSATION', TRUE,
               'trigger_count=' || v_cnt);
  ELSE
    lab_manual('M1', 'Add erasure cascade for CONVERSATION_CHUNK',
               'GDPR/CCPA: deleting CONVERSATION must propagate to CONVERSATION_CHUNK. Add ON DELETE CASCADE FK or AFTER DELETE trigger.');
  END IF;
END;
/

-- ---- Manual evidence items ---------------------------------------------------

BEGIN
  lab_manual('M1', 'MINILM_EMB is in the bank model inventory (SR 11-7)',
             'Provide model-inventory record: owner, version, validation report, intended use, monitoring plan.');
  lab_manual('M1', 'Embedding model file hash and signature stored as release artifact',
             'Provide ONNX file SHA-256 and signing evidence in the release manifest.');
  lab_manual('M1', 'CONVERSATION_CHUNK is in the same TDE-encrypted tablespace as CONVERSATION',
             'Provide tablespace + encryption settings.');
  lab_manual('M1', 'Recall@K canary measured for the current release',
             'Capture canary query results vs exact ground truth and document delta.');
  lab_manual('M1', 'p50/p95/p99 latency baselined under representative load',
             'Capture AWR/SQL Monitor evidence.');
  lab_manual('M1', 'No raw PII (SSN/DOB/PAN) appears in CONVERSATION_CHUNK.chunk_text sample',
             'Run a redaction-canary scan on a recent sample and document results.');
END;
/
