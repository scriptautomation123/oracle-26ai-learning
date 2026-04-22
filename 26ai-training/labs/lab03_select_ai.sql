-- lab03_select_ai.sql
-- Module 3 — Select AI / DBMS_CLOUD_AI
-- Verifies NUDGE_BOT and the records-of-record / governance surface.

DECLARE
  v_cnt NUMBER;
BEGIN
  -- ---- NUDGE_BOT profile ------------------------------------------------

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

  -- Data-minimization on the NL->SQL surface: object_list should NOT directly
  -- expose CUSTOMER.full_name. We can only check the attributes string for
  -- the column reference; absence is the correct state.
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
  lab_assert('M3', 'NUDGE_BOT object_list does not enumerate FULL_NAME column',
             v_cnt = 0,
             'data minimization: expose CUSTOMER via a view that omits full_name');

  -- ---- AI_CALL_LOG (records-of-record) ---------------------------------

  SELECT COUNT(*) INTO v_cnt
  FROM user_tables WHERE table_name = 'AI_CALL_LOG';

  IF v_cnt = 0 THEN
    lab_manual('M3', 'Create AI_CALL_LOG table per Module 3 schema',
               'Module 3 specifies columns: call_id, created_at, customer_id, use_case, offer_id, channel, channel_of_record, profile_name, model_name, model_version, trace_id, span_id, prompt_template_id, prompt_hash, prompt_tokens, output_tokens, output_hash, output_text, disclosure_id, suppression_check, optin_check, freq_cap_check, control_group, review_queue_id, status, error_text, retention_until.');
  ELSE
    lab_assert('M3', 'AI_CALL_LOG table exists', TRUE, NULL);

    -- Baseline observability columns
    SELECT COUNT(*) INTO v_cnt
    FROM user_tab_columns
    WHERE table_name = 'AI_CALL_LOG'
      AND column_name IN (
        'CALL_ID','CREATED_AT','CUSTOMER_ID','USE_CASE','PROFILE_NAME','MODEL_NAME',
        'TRACE_ID','SPAN_ID','PROMPT_TOKENS','OUTPUT_TOKENS','STATUS'
      );
    lab_assert('M3', 'AI_CALL_LOG has baseline observability columns', v_cnt >= 11,
               'matched columns=' || v_cnt);

    -- Bank-grade columns: channel-of-record, control-of-record checks,
    -- approved disclosure id, retention horizon
    SELECT COUNT(*) INTO v_cnt
    FROM user_tab_columns
    WHERE table_name = 'AI_CALL_LOG'
      AND column_name IN (
        'CHANNEL_OF_RECORD','SUPPRESSION_CHECK','OPTIN_CHECK','FREQ_CAP_CHECK',
        'DISCLOSURE_ID','RETENTION_UNTIL','PROMPT_TEMPLATE_ID','OUTPUT_TEXT'
      );
    lab_assert('M3', 'AI_CALL_LOG has bank-grade governance columns (UDAAP/Reg E/Reg Z/records-mgmt)',
               v_cnt = 8, 'matched columns=' || v_cnt);
  END IF;

  -- ---- UDAAP review queue ----------------------------------------------

  SELECT COUNT(*) INTO v_cnt
  FROM user_tables WHERE table_name = 'UDAAP_REVIEW_QUEUE';

  IF v_cnt = 0 THEN
    lab_manual('M3', 'Create UDAAP_REVIEW_QUEUE table',
               'Module 3 specifies a queue table with review_id, call_id, reason, state, reviewer, reviewed_at, notes. Required for new templates / new offers / new model versions / sampled review.');
  ELSE
    lab_assert('M3', 'UDAAP_REVIEW_QUEUE table exists', TRUE, NULL);
  END IF;

  -- ---- Approved disclosures (Reg Z / Reg DD) ---------------------------

  SELECT COUNT(*) INTO v_cnt
  FROM user_tables WHERE table_name = 'APPROVED_DISCLOSURES';

  IF v_cnt = 0 THEN
    lab_manual('M3', 'Create APPROVED_DISCLOSURES table for Reg Z / Reg DD substitution',
               'LLM must not paraphrase APR/APY/fee language. Wrapper must substitute approved disclosure text by offer_id and effective date.');
  ELSE
    lab_assert('M3', 'APPROVED_DISCLOSURES table exists', TRUE, NULL);
  END IF;

  -- ---- Wrapper package -------------------------------------------------

  SELECT COUNT(*) INTO v_cnt
  FROM user_procedures
  WHERE object_name = 'PKG_NUDGE_AI'
    AND procedure_name = 'GENERATE';

  IF v_cnt = 0 THEN
    lab_manual('M3', 'Create PKG_NUDGE_AI.GENERATE wrapper',
               'No application code may call DBMS_CLOUD_AI.GENERATE directly. Wrapper enforces opt-in/suppression/freq-cap, channel-of-record, disclosure substitution, AI_CALL_LOG insert, and fallback.');
  ELSE
    lab_assert('M3', 'PKG_NUDGE_AI.GENERATE wrapper exists', TRUE, NULL);
  END IF;

  -- ---- Manual evidence items -------------------------------------------

  lab_manual('M3', 'cohere.command-r-plus is in the bank model inventory (SR 11-7)',
             'Provide vendor data-handling terms, region, validation, monitoring plan.');
  lab_manual('M3', 'OCI GenAI region approved by Privacy Office (data residency)',
             'Provide written approval for the region selected for NUDGE_BOT.');
  lab_manual('M3', 'Direct EXECUTE on DBMS_CLOUD_AI is NOT granted to the application role',
             'Only the wrapper package owner has EXECUTE; application role has EXECUTE on the wrapper only.');
  lab_manual('M3', 'Disclosure-substitution test produces correct insertion and rejects on placeholder loss',
             'Capture two test cases: (1) placeholder present -> substitution; (2) placeholder removed -> wrapper rejects.');
  lab_manual('M3', 'UC3 calls are logged with channel_of_record = SERVICING',
             'Capture an AI_CALL_LOG row from a UC3 test where channel_of_record = SERVICING.');
END;
/
