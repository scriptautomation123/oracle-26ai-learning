-- lab04_mcp.sql

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
        AND privilege IN ('DROP ANY TABLE','DROP ANY VIEW','ALTER SYSTEM','CREATE ANY DIRECTORY','GRANT ANY PRIVILEGE')
    ]' INTO v_priv_cnt;

    lab_assert('M4', 'NUDGE_AGENT lacks destructive system privileges', v_priv_cnt = 0,
               'destructive privileges=' || v_priv_cnt);
  EXCEPTION
    WHEN OTHERS THEN
      lab_manual('M4', 'Review NUDGE_AGENT system privileges', 'DBA view access unavailable in current schema.');
  END;

  SELECT COUNT(*) INTO v_cnt
  FROM user_procedures
  WHERE object_name = 'PKG_NUDGE_AI'
    AND procedure_name = 'GENERATE';

  lab_assert('M4', 'PKG_NUDGE_AI.GENERATE wrapper exists', v_cnt = 1, NULL);

  lab_manual('M4', 'Validate MCP tool catalog', 'Demonstrate only approved named tools are exposed.');
  lab_manual('M4', 'Validate MCP auditability', 'Show per-tool invocation logging with actor and timestamp.');
END;
/
