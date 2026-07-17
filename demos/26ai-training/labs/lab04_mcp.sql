-- lab04_mcp.sql
-- Module 4 — MCP and SQLcl -mcp
-- Verifies NUDGE_AGENT least-priv and the suppression/opt-out enforcement points.

DECLARE
  v_cnt NUMBER;
  v_priv_cnt NUMBER := 0;
BEGIN
  -- ---- NUDGE_AGENT user --------------------------------------------------

  SELECT COUNT(*) INTO v_cnt FROM all_users WHERE username = 'NUDGE_AGENT';
  lab_assert('M4', 'NUDGE_AGENT user exists', v_cnt = 1, NULL);

  -- Destructive system privileges -- the agent must not have these.
  BEGIN
    EXECUTE IMMEDIATE q'[
      SELECT COUNT(*)
      FROM dba_sys_privs
      WHERE grantee = 'NUDGE_AGENT'
        AND privilege IN ('DROP ANY TABLE','DROP ANY VIEW','ALTER SYSTEM',
                          'CREATE ANY DIRECTORY','GRANT ANY PRIVILEGE',
                          'SELECT ANY TABLE','EXECUTE ANY PROCEDURE',
                          'CREATE ANY PROCEDURE','CREATE ANY TABLE')
    ]' INTO v_priv_cnt;

    lab_assert('M4', 'NUDGE_AGENT lacks destructive/excessive system privileges',
               v_priv_cnt = 0, 'risky privileges granted=' || v_priv_cnt);
  EXCEPTION
    WHEN OTHERS THEN
      lab_manual('M4', 'Review NUDGE_AGENT system privileges',
                 'DBA view access unavailable in current schema. Confirm NUDGE_AGENT has zero ANY-style or ALTER SYSTEM privileges.');
  END;

  -- ---- Wrapper package: PKG_NUDGE_AI.GENERATE ---------------------------

  SELECT COUNT(*) INTO v_cnt
  FROM user_procedures
  WHERE object_name = 'PKG_NUDGE_AI'
    AND procedure_name = 'GENERATE';

  IF v_cnt = 0 THEN
    lab_manual('M4', 'Expose only PKG_NUDGE_AI.GENERATE for content generation',
               'No direct DBMS_CLOUD_AI grant to NUDGE_AGENT. Only wrapper package execute should be granted.');
  ELSE
    lab_assert('M4', 'PKG_NUDGE_AI.GENERATE wrapper exists', TRUE, NULL);
  END IF;

  -- ---- Suppression / opt-out / do-not-contact (the enforcement surface) -

  SELECT COUNT(*) INTO v_cnt FROM user_tables WHERE table_name = 'OFFER_SUPPRESSION';
  IF v_cnt = 0 THEN
    lab_manual('M4', 'Create OFFER_SUPPRESSION table',
               'Per-customer per-channel suppression list. Required for TCPA/CAN-SPAM/UDAAP and per-offer suppression.');
  ELSE
    lab_assert('M4', 'OFFER_SUPPRESSION table exists', TRUE, NULL);
  END IF;

  SELECT COUNT(*) INTO v_cnt FROM user_tables WHERE table_name = 'DO_NOT_CONTACT';
  IF v_cnt = 0 THEN
    lab_manual('M4', 'Create DO_NOT_CONTACT table',
               'Account-level no-contact authoritative list (TCPA do-not-call, CAN-SPAM unsubscribe, account holds).');
  ELSE
    lab_assert('M4', 'DO_NOT_CONTACT table exists', TRUE, NULL);
  END IF;

  SELECT COUNT(*) INTO v_cnt FROM user_tables WHERE table_name = 'MARKETING_POLICY';
  IF v_cnt = 0 THEN
    lab_manual('M4', 'Create MARKETING_POLICY table (frequency cap, quiet hours)',
               'Frequency cap window/limit and quiet-hours enforced by pkg_nudge_policy.is_suppressed.');
  ELSE
    lab_assert('M4', 'MARKETING_POLICY table exists', TRUE, NULL);
  END IF;

  -- ---- Suppression function: pkg_nudge_policy.is_suppressed -------------

  SELECT COUNT(*) INTO v_cnt
  FROM user_procedures
  WHERE object_name = 'PKG_NUDGE_POLICY'
    AND procedure_name = 'IS_SUPPRESSED';

  IF v_cnt = 0 THEN
    lab_manual('M4', 'Create PKG_NUDGE_POLICY.IS_SUPPRESSED function',
               'Single enforcement point combining personalization_opt_in, OFFER_SUPPRESSION, DO_NOT_CONTACT, frequency cap, quiet hours, and the SERVICING vs MARKETING distinction (Reg E vs CAN-SPAM/TCPA).');
  ELSE
    lab_assert('M4', 'PKG_NUDGE_POLICY.IS_SUPPRESSED enforcement function exists', TRUE, NULL);
  END IF;

  -- ---- Manual evidence items -------------------------------------------

  lab_manual('M4', 'MCP tool catalog reviewed: no raw NPI accessor in any tool',
             'Confirm no tool returns transcript, full_name, account number, PAN, SSN, DOB.');
  lab_manual('M4', 'No MCP tool can deny credit (FCRA)',
             'Confirm there is no tool the agent can call that issues an adverse credit decision.');
  lab_manual('M4', 'Per-tool invocation log present (caller, tool, params, trace_id, result, elapsed)',
             'Show per-tool log table and a sample invocation row.');
  lab_manual('M4', 'NUDGE_AGENT inbound network restricted to MCP server (ACL/mTLS)',
             'Provide ACL/mTLS configuration evidence.');
  lab_manual('M4', 'Resource Manager consumer group caps NUDGE_AGENT CPU/parallelism',
             'Provide consumer-group plan definition.');
  lab_manual('M4', 'End-to-end suppression test: a customer in DO_NOT_CONTACT receives no AI_CALL_LOG row',
             'Run synthetic test; capture OFFER_DECISION_LOG row with decision=SUPPRESSED and zero new AI_CALL_LOG rows.');
END;
/
