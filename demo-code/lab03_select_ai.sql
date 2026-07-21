-- lab03_select_ai.sql
-- Module 3 - Select AI / DBMS_CLOUD_AI
-- Verifies NUDGE_BOT and the records-of-record surface.

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
  lab_assert('M3', 'NUDGE_BOT object_list contains the expected tables', v_cnt = 1, NULL);

  BEGIN
    EXECUTE IMMEDIATE q'[
      SELECT COUNT(*)
      FROM user_cloud_ai_profiles
      WHERE profile_name = 'NUDGE_BOT'
        AND UPPER(attributes) LIKE '%FULL_NAME%'
    ]' INTO v_cnt;
  EXCEPTION
    WHEN OTHERS THEN
      v_cnt := 0;
  END;
  lab_assert('M3', 'NUDGE_BOT object_list does not enumerate FULL_NAME', v_cnt = 0,
             'data minimization: expose CUSTOMER via a view that omits full_name');

  SELECT COUNT(*) INTO v_cnt
  FROM user_tables WHERE table_name = 'AI_CALL_LOG';

  IF v_cnt = 0 THEN
    lab_manual('M3', 'Create AI_CALL_LOG table',
               'Provide call_id, customer_id, use_case, profile_name, model_name, trace_id, span_id, prompt_tokens, output_tokens, output_text, retention_until.');
  ELSE
    lab_assert('M3', 'AI_CALL_LOG table exists', TRUE, NULL);
  END IF;

  SELECT COUNT(*) INTO v_cnt
  FROM user_tables WHERE table_name = 'UDAAP_REVIEW_QUEUE';

  IF v_cnt = 0 THEN
    lab_manual('M3', 'Create UDAAP_REVIEW_QUEUE table',
               'Route new templates, new offers, and sampled calls through a review queue.');
  ELSE
    lab_assert('M3', 'UDAAP_REVIEW_QUEUE table exists', TRUE, NULL);
  END IF;

  SELECT COUNT(*) INTO v_cnt
  FROM user_tables WHERE table_name = 'APPROVED_DISCLOSURES';

  IF v_cnt = 0 THEN
    lab_manual('M3', 'Create APPROVED_DISCLOSURES table',
               'Use it to substitute approved APR/APY language instead of paraphrasing disclosures in the model.');
  ELSE
    lab_assert('M3', 'APPROVED_DISCLOSURES table exists', TRUE, NULL);
  END IF;

  SELECT COUNT(*) INTO v_cnt
  FROM user_procedures
  WHERE object_name = 'PKG_NUDGE_AI'
    AND procedure_name = 'GENERATE';

  IF v_cnt = 0 THEN
    lab_manual('M3', 'Create PKG_NUDGE_AI.GENERATE wrapper',
               'All generation must flow through a wrapper that enforces opt-in, suppression, disclosure substitution, logging, and fallback.');
  ELSE
    lab_assert('M3', 'PKG_NUDGE_AI.GENERATE wrapper exists', TRUE, NULL);
  END IF;

  lab_manual('M3', 'The model is in the inventory',
             'Provide vendor terms, data-handling terms, region, validation, and monitoring plan.');
  lab_manual('M3', 'Direct EXECUTE on DBMS_CLOUD_AI is not granted to the application role',
             'Only the wrapper package should be callable by the application role.');
END;
/