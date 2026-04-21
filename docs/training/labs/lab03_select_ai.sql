-- lab03_select_ai.sql

DECLARE
  v_cnt NUMBER;
BEGIN
  BEGIN
    EXECUTE IMMEDIATE q'[SELECT COUNT(*) FROM user_cloud_ai_profiles WHERE profile_name = 'NUDGE_BOT']' INTO v_cnt;
  EXCEPTION
    WHEN OTHERS THEN
      v_cnt := 0;
  END;
  lab_assert('M3', 'NUDGE_BOT profile exists', v_cnt = 1, NULL);

  BEGIN
    EXECUTE IMMEDIATE q'[
      SELECT COUNT(*)
      FROM user_cloud_ai_profiles
      WHERE profile_name = 'NUDGE_BOT'
        AND UPPER(attributes) LIKE '%"OBJECT_LIST"%'
        AND UPPER(attributes) LIKE '%CUSTOMER%'
        AND UPPER(attributes) LIKE '%TXN%'
        AND UPPER(attributes) LIKE '%APPLICATION%'
        AND UPPER(attributes) LIKE '%CONVERSATION_CHUNK%'
    ]' INTO v_cnt;
  EXCEPTION
    WHEN OTHERS THEN
      v_cnt := 0;
  END;
  lab_assert('M3', 'NUDGE_BOT object_list contains expected tables', v_cnt = 1, NULL);

  SELECT COUNT(*) INTO v_cnt
  FROM user_tables
  WHERE table_name = 'AI_CALL_LOG';

  lab_assert('M3', 'AI_CALL_LOG table exists', v_cnt = 1, NULL);

  SELECT COUNT(*) INTO v_cnt
  FROM user_tab_columns
  WHERE table_name = 'AI_CALL_LOG'
    AND column_name IN (
      'CALL_ID','CREATED_AT','CUSTOMER_ID','USE_CASE','PROFILE_NAME','MODEL_NAME',
      'TRACE_ID','SPAN_ID','PROMPT_TOKENS','OUTPUT_TOKENS','STATUS'
    );

  lab_assert('M3', 'AI_CALL_LOG has minimum SOX/governance columns', v_cnt >= 11,
             'matched columns=' || v_cnt);

  lab_manual('M3', 'Validate prompt policy controls', 'Show prompt templates and deny-list coverage.');
  lab_manual('M3', 'Validate token-cost governance', 'Show weekly cost report tied to AI_CALL_LOG.');
  lab_manual('M3', 'Run human review for generated content quality', 'Capture examples per use case.');
END;
/
