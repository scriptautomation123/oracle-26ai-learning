-- lab06_ops.sql

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
      lab_manual('M6', 'Query v$sqlstats for AI workload SQL', 'Requires catalog access in target environment.');
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
  SELECT COUNT(*) INTO v_cnt
  FROM user_tab_columns
  WHERE table_name = 'AI_CALL_LOG'
    AND column_name IN ('TRACE_ID','SPAN_ID','PROFILE_NAME','MODEL_NAME','PROMPT_TOKENS','OUTPUT_TOKENS');

  lab_assert('M6', 'AI_CALL_LOG has TRACE/SPAN/PROFILE/MODEL/TOKEN columns', v_cnt = 6,
             'matched_columns=' || v_cnt);
END;
/
