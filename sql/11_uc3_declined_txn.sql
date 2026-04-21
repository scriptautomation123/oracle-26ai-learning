-- 11_uc3_declined_txn.sql
-- Purpose: UC3 Select AI agentic nudge generation for declined transactions.
-- Prerequisite: Run after 08_select_ai_profile.sql.

SELECT DBMS_CLOUD_AI.GENERATE(prompt => 'Customer 1001 just had a declined transaction...', action => 'chat')
FROM dual;
