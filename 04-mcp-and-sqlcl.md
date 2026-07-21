# Module 4 — MCP and SQLcl `-mcp` (for the Offers Team)

> **Regulatory regimes that shape this module:** GLBA (the agent is a new
> data path to NPI — least privilege, encryption, audit), SR 11-7 (an LLM
> agent calling tools is a model system; control its action surface),
> NYDFS Part 500 (the agent and its provider are third-party access),
> UDAAP (any tool that produces customer-facing text is a UDAAP surface),
> Reg E (servicing tools are governed differently from marketing tools),
> records management (every tool invocation is a record).

## MCP in one sentence

MCP (Model Context Protocol) is a standard interface that lets an LLM
agent call **explicitly defined tools** with explicit parameters and
explicit returns — instead of letting the LLM write arbitrary SQL or
arbitrary HTTP calls into the bank.

For the offers team this matters because it turns the agent integration
from "an LLM with a database password" (which Compliance will not approve)
into "an LLM with a fixed catalog of named, parameter-typed, audited,
least-privilege actions" (which Compliance can approve, with conditions).

## Repo anchor

- `26ai-banking-demo/mcp/README.md` — SQLcl MCP server startup + client wiring
- `26ai-banking-demo/mcp/tools/peer_products.sql` — example named tool

## The named-tool catalog

The tool catalog is the **policy enforcement point**. Each named tool is a
wrapper around a stored procedure or view that has already had every
control attached. The agent calls the tool by name with typed parameters;
it cannot reach past the tool to the underlying tables.

A defensible initial catalog for the offers stack:

| Tool | Purpose | UC | Channel of record |
|------|---------|-----|-------------------|
| `peer_products(cid, limit)` | UC1 candidate-generation: peer-viewed products via `BANKING_GRAPH` | UC1 | Marketing |
| `recent_card_view(cid)` | UC1 trigger lookup (last `page_event` on a card product) | UC1 | Marketing |
| `abandoned_apps(lookback_hours)` | UC2 trigger sweep | UC2 | Marketing |
| `app_context(app_id)` | UC2 grounding — pulls `application.fields_json` minus PII | UC2 | Marketing |
| `recent_declines(cid, lookback_hours)` | UC3 trigger lookup | UC3 | **Servicing** |
| `decline_explanation(txn_id)` | UC3 grounding — deterministic mapping of `decline_reason` to approved customer-facing language | UC3 | **Servicing** |
| `similar_chunks(query_text, top_k, customer_id)` | Vector retrieval — *requires* customer_id so opt-in/suppression are enforced | All | Inherits from caller |
| `is_eligible(cid, offer_id)` | Deterministic eligibility check against the `OFFER.eligibility_rule` (Mass/Prime/Affluent, debt_consolidation, new_to_bank) | All | n/a |
| `is_suppressed(cid, channel)` | Suppression-list + opt-out + frequency-cap check | All | n/a |
| `generate_nudge(cid, offer_id, use_case, channel)` | Calls `PKG_NUDGE_AI.GENERATE` (Module 3 wrapper). Re-runs `is_eligible` and `is_suppressed` defense-in-depth | All | Per use_case |
| `record_decision(...)` | Writes to `OFFER_DECISION_LOG` (Module 5) | All | n/a |

Tools the catalog **must not** contain:

- Anything that returns raw `transcript`, `full_name`, account number, PAN,
  SSN, or DOB.
- Anything that bypasses `is_suppressed` for marketing channels.
- Anything that bypasses approved disclosures.
- Anything the credit-decision path could use to *deny* an application
  based on graph or vector output (FCRA: the agent does not deny credit).
- Anything with `EXECUTE IMMEDIATE` or arbitrary SQL passthrough.

## Hardening recipe — `NUDGE_AGENT` role

The DB user that the SQLcl MCP server connects as:

- Dedicated user (`NUDGE_AGENT`), **never** `ADMIN`.
- No system privileges. Specifically: no `CREATE TABLE`, no
  `CREATE PROCEDURE`, no `EXECUTE ANY PROCEDURE`, no `SELECT ANY TABLE`,
  no `ALTER SESSION` other than what `connection-init-sql` requires.
- Object grants only on the named-tool wrappers — **not** on the
  underlying tables, **not** on `DBMS_CLOUD_AI` directly.
- Resource Manager consumer group cap so a runaway agent can't starve the
  OLTP lane (Module 6).
- Connection from the MCP server only (DB-side access control by client
  IP / ACL / mTLS).
- Full unified audit on the `NUDGE_AGENT` schema; ship audit to SIEM.

## Suppression and opt-out — wrappers, not advice

These get their own section because every team gets them wrong eventually.

```sql
CREATE OR REPLACE FUNCTION pkg_nudge_policy.is_suppressed(
  p_customer_id NUMBER,
  p_channel     VARCHAR2,                  -- IN_APP / EMAIL / SMS / PUSH
  p_use_case    VARCHAR2 DEFAULT 'MARKETING' -- MARKETING / SERVICING
) RETURN VARCHAR2;                          -- 'Y' if suppressed, 'N' otherwise
```

Rules baked into the function (not the caller):

- If `p_use_case = 'SERVICING'` (UC3 declined-txn), marketing opt-out is
  ignored, but channel-specific consent is still enforced (no SMS without
  SMS consent for servicing).
- If `customer.personalization_opt_in = 'N'` and `p_use_case = 'MARKETING'`
  → suppressed.
- If `EXISTS` row in `offer_suppression(customer_id, channel)` → suppressed.
- If `EXISTS` row in `do_not_contact(customer_id)` → suppressed (covers
  TCPA do-not-call, CAN-SPAM unsubscribe, account-level holds).
- Frequency-cap: count `ai_call_log` rows for `(customer_id, channel)` in
  the rolling window from `marketing_policy.freq_cap` → suppressed if over.
- Quiet-hours: check `customer.timezone` against
  `marketing_policy.quiet_hours_start/end` for time-of-day-sensitive channels.

The agent has **no ability** to bypass this function. The catalog tool
`generate_nudge` calls it; if it returns 'Y' the tool returns a
deterministic "suppressed" response and writes a `SUPPRESSED` row to the
decision log — it never calls the LLM.

## Per-tool logging

Every tool invocation writes:

- caller identity (the MCP session's authenticated principal),
- tool name + version,
- input parameters (PII redacted at the log layer if applicable),
- W3C traceparent,
- result summary (row counts, decision codes — not raw NPI),
- elapsed time,
- error class if any.

This log feeds the same SIEM stream as `AI_CALL_LOG`. A regulator data
request joins them on `customer_id` + `trace_id`.

## Spring integration patterns

- The Spring service remains the system-of-record orchestrator for
  triggered (UC2 sweep, UC3 fanout) flows.
- The MCP path is for **interactive** uses: a banker assistant in a chat UI
  asking questions like "what offers is customer 1001 eligible for right
  now and which ones did we suppress, and why?" — the agent answers using
  the same tools that produced the production decision, so its answer is
  by construction consistent.
- Never expose `generate_nudge` to a banker without the same suppression
  and disclosure controls. A banker sending an LLM-authored SMS via the
  agent is still bound by Reg E / TCPA.

## Verify yourself

- `NUDGE_AGENT` exists, has **zero** system privileges, and has object
  privileges only on the named-tool wrappers.
- `pkg_nudge_policy.is_suppressed` exists and is called by every
  marketing-channel tool. (Lab 4 enforces.)
- `pkg_nudge_ai.generate` is the only callable that touches `DBMS_CLOUD_AI`.
- `do_not_contact`, `offer_suppression`, `marketing_policy` tables exist.
- A test invocation of `generate_nudge(cid, ...)` for a customer in
  `do_not_contact` returns the suppressed response and writes a
  `SUPPRESSED` decision-log row, with **zero** rows added to `AI_CALL_LOG`
  for that call.
- The MCP tool catalog does not include any tool returning `full_name`
  or `transcript`.
