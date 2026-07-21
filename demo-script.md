# 10–15 Minute Demo Script (UC1/UC2/UC3)

Use this script after the SQL run order in [docs/architecture.md](architecture.md) is complete.

## Demo objective

Tell one integrated story: banking decision quality plus marketing execution quality.

- Banking narrative: the system uses trusted data, applies eligibility and servicing rules, and produces auditable decisions.
- Marketing narrative: the system improves timing, relevance, and channel discipline while enforcing suppression and frequency controls.

1. Open Database Actions SQL Worksheet in Oracle Autonomous Database 26ai Free Tier.
2. Run the schema and setup SQL in order `01 -> 08`.
3. Run `sql/runtime/12_app_runtime_tables.sql` if you are demoing the Spring Boot API service.
4. Confirm that the core tables contain data.

   ```sql
   SELECT (SELECT COUNT(*) FROM customer) c,
          (SELECT COUNT(*) FROM txn) t,
          (SELECT COUNT(*) FROM application) a,
          (SELECT COUNT(*) FROM conversation_chunk) cc
   FROM dual;
   ```

5. Show the vector retrieval path with a simple semantic query.

   ```sql
   SELECT chunk_text
   FROM conversation_chunk
   ORDER BY VECTOR_DISTANCE(
     embedding,
     VECTOR_EMBEDDING(MINILM_EMB USING 'card comparison request' AS DATA),
     COSINE)
   FETCH FIRST 3 ROWS ONLY;
   ```

6. Prepare UC1 by creating a recent card-page event for a customer.
7. Run `sql/use-cases/09_uc1_card_view.sql` with `:cid` and show the peer products and conversation snippets returned by the combined graph and vector flow.
   Explain this as a high-intent marketing moment where relevance and conversion quality improve without bypassing eligibility.
8. Prepare UC2 by selecting an application with `status = 'STARTED'` and an `updated_at` value older than one hour.
9. Run `sql/use-cases/10_uc2_abandoned_app.sql` and show the nudge context snippets returned for the abandoned application.
   Explain this as recovery marketing with compliant re-engagement and channel controls.
10. Prepare UC3 by verifying a declined transaction in `TXN`.
11. Run `sql/use-cases/11_uc3_declined_txn.sql` and show the Select AI generated nudge.
   Explain this as a servicing communication, not marketing, and call out why this classification matters.
12. Open the APEX page or procedure in `sql/integration/14_apex_nudge_chat_api.sql` and run a sample request through the chat surface.
13. Optionally start the SQLcl MCP server and show an agent prompt calling the database tools.
14. Optionally run the Spring Boot nudge API endpoints and show `offer_decision_log` plus `mcp_tool_invocation_log` rows.
15. Close by restating the cost guardrails and Free Tier scope.

## Close with measurable outcomes

- Banking outcomes: faster response in live customer windows, defensible decision trails, lower servicing friction.
- Marketing outcomes: better contextual nudges, stronger abandonment recovery, cleaner suppression and channel compliance.

## Demo Notes

- UC1 demonstrates graph narrowing plus semantic ranking over customer context.
- UC2 demonstrates re-engagement based on application state and prior conversation text.
- UC3 demonstrates governed generation with Select AI and policy context.
- Keep the story technical and direct; do not switch into slide-style framing during the run-through.
- Explicitly state, at each UC, whether the communication is marketing or servicing and why.

## Next phase handoff

Next phase: integration and teardown.

Run next if you are extending the live demo surface:

- `./scripts/db/install_app_sql_extensions.sh --connect user/password@dsn`
- review [../mcp/README.md](../mcp/README.md)
- review [../spring/README.md](../spring/README.md)

Run next if you are done with the environment:

- `./scripts/demo/orchestrate.sh --mode container --stage cleanup`
