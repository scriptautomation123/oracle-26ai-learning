-- 11_uc3_declined_txn.sql
-- Purpose: UC3 declined transaction nudge generated with Select AI agentic context.
-- Run order: 11
-- Dependencies: sql/08_select_ai_profile.sql, transformed txn data

VAR cid NUMBER;
EXEC :cid := 1;

SELECT DBMS_CLOUD_AI.GENERATE(
  prompt => 'Customer ' || :cid ||
            ' recently had a declined transaction. Review recent txn rows, explain probable reason, and craft one concise proactive nudge.',
  action => 'chat'
) AS nudge_text
FROM dual;
