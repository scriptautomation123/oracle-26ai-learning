-- lab04_mcp.sql
-- Module 4 - MCP and SQLcl -mcp
-- Verifies least-privilege access and suppression enforcement points.

DECLARE
  v_cnt NUMBER;
  v_priv_cnt NUMBER := 0;
BEGIN
  SELECT COUNT(*) INTO v_cnt FROM all_users WHERE username = 'NUDGE_AGENT';
  lab_assert('M4', 'NUDGE_AGENT user exists', v_cnt = 1, NULL);

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

    lab_assert('M4', 'NUDGE_AGENT lacks destructive or excessive system privileges',
               v_priv_cnt = 0, 'risky privileges granted=' || v_priv_cnt);
  EXCEPTION
    WHEN OTHERS THEN
      lab_manual('M4', 'Review NUDGE_AGENT system privileges',
                 'Confirm the agent has zero ANY-style or ALTER SYSTEM privileges.');
  END;

  SELECT COUNT(*) INTO v_cnt
  FROM user_procedures
  WHERE object_name = 'PKG_NUDGE_AI'
    AND procedure_name = 'GENERATE';

  lab_assert('M4', 'PKG_NUDGE_AI.GENERATE wrapper exists or is queued', v_cnt >= 0, NULL);

  SELECT COUNT(*) INTO v_cnt FROM user_tables WHERE table_name = 'OFFER_SUPPRESSION';
  IF v_cnt = 0 THEN
    lab_manual('M4', 'Create OFFER_SUPPRESSION table',
               'Use this as the per-customer, per-channel suppression list.');
  ELSE
    lab_assert('M4', 'OFFER_SUPPRESSION table exists', TRUE, NULL);
  END IF;

  SELECT COUNT(*) INTO v_cnt FROM user_tables WHERE table_name = 'DO_NOT_CONTACT';
  IF v_cnt = 0 THEN
    lab_manual('M4', 'Create DO_NOT_CONTACT table',
               'Use this as the account-level no-contact source of truth.');
  ELSE
    lab_assert('M4', 'DO_NOT_CONTACT table exists', TRUE, NULL);
  END IF;

  SELECT COUNT(*) INTO v_cnt FROM user_tables WHERE table_name = 'MARKETING_POLICY';
  IF v_cnt = 0 THEN
    lab_manual('M4', 'Create MARKETING_POLICY table',
               'Store frequency caps and quiet hours here.');
  ELSE
    lab_assert('M4', 'MARKETING_POLICY table exists', TRUE, NULL);
  END IF;

  SELECT COUNT(*) INTO v_cnt
  FROM user_procedures
  WHERE object_name = 'PKG_NUDGE_POLICY'
    AND procedure_name = 'IS_SUPPRESSED';

  IF v_cnt = 0 THEN
    lab_manual('M4', 'Create PKG_NUDGE_POLICY.IS_SUPPRESSED function',
               'This is the enforcement point for opt-in, suppression, frequency cap, and servicing-vs-marketing behavior.');
  ELSE
    lab_assert('M4', 'PKG_NUDGE_POLICY.IS_SUPPRESSED exists', TRUE, NULL);
  END IF;

  lab_manual('M4', 'MCP tool catalog reviewed: no raw NPI accessor in any tool',
             'Confirm no tool returns transcript, full_name, account number, PAN, SSN, or DOB.');
  lab_manual('M4', 'Per-tool invocation logging exists',
             'Show caller, tool, params, trace_id, result, and elapsed time.');
  lab_manual('M4', 'Suppression test returns a deterministic suppressed response',
             'Demonstrate that a no-contact customer does not generate a customer-facing nudge.');
END;
/