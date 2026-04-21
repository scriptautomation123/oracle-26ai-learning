# 10–15 Minute Demo Script (UC1/UC2/UC3)

1. Open Database Actions SQL Worksheet in ADB 26ai Free Tier.
2. Run schema/setup SQL in order `01 -> 08`.
3. Confirm row counts:
   ```sql
   SELECT (SELECT COUNT(*) FROM customer) c,
          (SELECT COUNT(*) FROM txn) t,
          (SELECT COUNT(*) FROM application) a,
          (SELECT COUNT(*) FROM conversation_chunk) cc
   FROM dual;
   ```
4. Show vector retrieval sanity check:
   ```sql
   SELECT chunk_text
   FROM conversation_chunk
   ORDER BY VECTOR_DISTANCE(
     embedding,
     VECTOR_EMBEDDING(MINILM_EMB USING 'card comparison request' AS DATA),
     COSINE)
   FETCH FIRST 3 ROWS ONLY;
   ```
5. UC1 setup: create a recent card page event for a customer.
6. Run `sql/09_uc1_card_view.sql` with `:cid` and show peer products + conversation snippets.
7. Explain graph + vector blend in one SQL flow.
8. UC2 setup: identify applications with `status='STARTED'` and `updated_at` older than 1 hour.
9. Run `sql/10_uc2_abandoned_app.sql` and show returned nudge context snippets.
10. UC3 setup: verify a declined transaction exists in `TXN`.
11. Run `sql/11_uc3_declined_txn.sql` and show Select AI generated nudge.
12. Open APEX page/procedure (`apex/nudge_chat_app.sql`) and run a sample request.
13. Optional: start SQLcl MCP server and show agent prompt calling DB tools.
14. Close with cost guardrails and Free Tier scope.
