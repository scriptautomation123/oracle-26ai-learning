# Module 3 — Select AI and `DBMS_CLOUD_AI`

## Objective

Use governed NL→SQL / RAG-style generation paths from Oracle, with auditable controls.

## Files in scope

- `sql/08_select_ai_profile.sql`
- `sql/11_uc3_declined_txn.sql`

## Profile setup recap

`DBMS_CLOUD_AI.CREATE_PROFILE` defines:
- provider
- credential
- model
- object allow-list (`object_list`)

`DBMS_CLOUD_AI.SET_PROFILE('NUDGE_BOT')` activates it per session.

## Governance table (recommended)

| Control | Recommendation |
|---|---|
| Least privilege | Use restricted app schema + wrapper package |
| Object scope | Keep `object_list` minimal |
| Prompt policy | Restrict to approved templates |
| Auditability | Persist prompt/response metadata in `AI_CALL_LOG` |
| Cost | Track tokens and model per call |

## `AI_CALL_LOG` (recommended)

```sql
CREATE TABLE ai_call_log (
  call_id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  customer_id     NUMBER,
  use_case        VARCHAR2(30),
  profile_name    VARCHAR2(128),
  model_name      VARCHAR2(256),
  trace_id        VARCHAR2(64),
  span_id         VARCHAR2(32),
  prompt_hash     VARCHAR2(128),
  prompt_tokens   NUMBER,
  output_tokens   NUMBER,
  status          VARCHAR2(20),
  error_text      VARCHAR2(4000)
);
```

## Wrapper pattern

Expose `pkg_nudge_ai.generate(...)` and keep direct `DBMS_CLOUD_AI.GENERATE` calls out of application SQL.

## Spring integration

- Set Select AI profile once at session init (`connection-init-sql`).
- Call wrapper PL/SQL for generation.
- Attach trace/span IDs for cross-tier correlation.

## Verify yourself

- `NUDGE_BOT` exists.
- Expected `object_list` members are present.
- `AI_CALL_LOG` has baseline SOX/governance columns.
