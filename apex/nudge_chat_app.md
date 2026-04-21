# APEX nudge chat app (documentation-only)

## Goal
Build a single-page APEX app that lets an operator trigger UC1/UC2/UC3 and display generated nudges.

## Suggested page structure

1. **Region: Customer Context**
   - Items: `P1_CUSTOMER_ID`, `P1_CHANNEL`, `P1_LAST_EVENT`
   - SQL source: `customer`, `account`, recent `txn` summary.

2. **Region: Trigger Buttons**
   - Button `UC1_CARD_VIEW`: inserts a `page_event` row and calls `sql/09_uc1_card_view.sql` logic.
   - Button `UC2_ABANDONED_APP`: runs `sql/10_uc2_abandoned_app.sql` logic.
   - Button `UC3_DECLINED_TXN`: runs `sql/11_uc3_declined_txn.sql` logic.

3. **Region: Conversation / Nudge Output**
   - Classic report over a session collection or temp table containing retrieved snippets + generated nudge text.

4. **Process recommendations**
   - Use a page process (PL/SQL) to set Select AI profile: `DBMS_CLOUD_AI.SET_PROFILE('NUDGE_BOT')`.
   - Add exception handling that falls back to deterministic templated messages when LLM credentials are unavailable.

5. **Security**
   - Store OCI credentials in DB credential objects only.
   - Do not store API keys in APEX page source.
