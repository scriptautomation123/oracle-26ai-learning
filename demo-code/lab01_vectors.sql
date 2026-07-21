-- lab01_vectors.sql
-- Module 1 - Vectors, Embeddings, and ANN Indexes
-- Verifies the banking-demo vector surface and flags governance items.

DECLARE
  v_dim NUMBER := 0;
  v_fmt VARCHAR2(30) := 'UNKNOWN';
  v_cnt NUMBER;
BEGIN
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
  WHERE UPPER(NVL(operation,' ')) LIKE '%VECTOR%'
     OR UPPER(NVL(options,' ')) LIKE '%VECTOR%'
     OR UPPER(NVL(object_name,' ')) = 'CONV_CHUNK_IDX';

  lab_assert('M1', 'Canonical top-K plan shows vector index activity', v_cnt > 0, NULL);

  SELECT COUNT(*) INTO v_cnt
  FROM user_tab_columns
  WHERE table_name = 'CUSTOMER'
    AND column_name = 'PERSONALIZATION_OPT_IN';

  IF v_cnt = 1 THEN
    lab_assert('M1', 'CUSTOMER.PERSONALIZATION_OPT_IN exists (consent gate)', TRUE, NULL);
  ELSE
    lab_manual('M1', 'Add CUSTOMER.PERSONALIZATION_OPT_IN consent column',
               'Use this to narrow vector retrieval by consent before any customer-facing nudge is generated.');
  END IF;

  SELECT COUNT(*) INTO v_cnt
  FROM user_triggers
  WHERE table_name = 'CONVERSATION'
    AND triggering_event LIKE '%DELETE%';

  IF v_cnt > 0 THEN
    lab_assert('M1', 'Erasure cascade trigger present on CONVERSATION', TRUE, 'trigger_count=' || v_cnt);
  ELSE
    lab_manual('M1', 'Add erasure cascade for CONVERSATION_CHUNK',
               'Deleting a conversation must propagate to conversation_chunk because the embedding is derived data.');
  END IF;

  lab_manual('M1', 'MINILM_EMB is in the model inventory',
             'Provide owner, version, validation report, intended use, and monitoring plan.');
  lab_manual('M1', 'Embedding file hash and signature stored as release artifact',
             'Provide SHA-256 and signing evidence in the release manifest.');
  lab_manual('M1', 'No raw PII appears in conversation_chunk samples',
             'Scan a recent sample for SSN, DOB, account number, and PAN before embedding.');
END;
/