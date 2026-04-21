-- lab01_vectors.sql

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

BEGIN
  lab_manual('M1', 'Compare recall@5 ANN vs exact on canary prompt', 'Capture canary query results and document delta.');
  lab_manual('M1', 'Record p95 latency under representative load', 'Capture AWR/SQL Monitor evidence.');
END;
/
