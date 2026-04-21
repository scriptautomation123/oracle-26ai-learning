-- nudge_chat_app.sql
-- Purpose: Minimal APEX-facing PL/SQL API for nudge generation by use case.
-- Prerequisite: Run after SQL files 01..11. Call this procedure from an APEX page process.

CREATE OR REPLACE PACKAGE nudge_chat_api AS
  FUNCTION get_nudge(p_use_case IN VARCHAR2, p_customer_id IN NUMBER) RETURN CLOB;
END nudge_chat_api;
/

CREATE OR REPLACE PACKAGE BODY nudge_chat_api AS
  FUNCTION get_nudge(p_use_case IN VARCHAR2, p_customer_id IN NUMBER) RETURN CLOB IS
    l_out CLOB;
  BEGIN
    IF p_use_case = 'UC1' THEN
      SELECT TO_CLOB('I see you viewed a card product recently. Want a quick comparison?')
      INTO l_out
      FROM dual;
    ELSIF p_use_case = 'UC2' THEN
      SELECT TO_CLOB('Looks like your application is still in progress. Need help to finish it?')
      INTO l_out
      FROM dual;
    ELSIF p_use_case = 'UC3' THEN
      SELECT DBMS_CLOUD_AI.GENERATE(
               prompt => 'Customer ' || p_customer_id || ' just had a declined transaction. Craft a one-sentence proactive nudge.',
               action => 'chat'
             )
      INTO l_out
      FROM dual;
    ELSE
      l_out := TO_CLOB('Unsupported use case. Use UC1, UC2, or UC3.');
    END IF;

    RETURN l_out;
  END get_nudge;
END nudge_chat_api;
/
