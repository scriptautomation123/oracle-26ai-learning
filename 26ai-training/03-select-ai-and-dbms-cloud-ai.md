# Module 3 — Select AI and `DBMS_CLOUD_AI` (for the Offers Team)

> **Regulatory regimes that shape this module:** UDAAP (every generated
> string is a consumer communication), Reg Z / Reg DD (cost-of-credit and
> APY language is approved-disclosure-only — the LLM does not paraphrase it),
> FCRA (no LLM-authored adverse-action reasons), Reg E (UC3 declined-txn
> messaging is servicing, not marketing — different rules), GLBA (NPI in
> prompts is NPI in transit to the model provider — review the contract),
> SR 11-7 (the LLM is a model in the inventory), records management
> (prompts and outputs are records).

## Objective

Use Oracle's `DBMS_CLOUD_AI` to generate offer-content nudges with controls
that survive a regulator data request. The generation step is the **last and
most-controlled** step in the pipeline. By the time you call `GENERATE`, the
offer has already been chosen, the customer has already been confirmed
eligible, suppression and opt-out have already passed, and the channel-of-
record decision has already been made (Module 5). The LLM's job is to
phrase a pre-approved decision — not to make one.

If you remember one rule from this module: **the LLM never decides anything
that requires a defensible reason.**

## Files in scope

- `26ai-banking-demo/sql/08_select_ai_profile.sql` — defines the
  `NUDGE_BOT` profile.
- `26ai-banking-demo/sql/11_uc3_declined_txn.sql` — UC3 generation call.

## Walkthrough — `sql/08_select_ai_profile.sql`

```sql
DBMS_CLOUD_AI.CREATE_PROFILE(
  profile_name => 'NUDGE_BOT',
  attributes   => '{
    "provider":"oci",
    "credential_name":"OCI_GENAI_CRED",
    "model":"cohere.command-r-plus",
    "object_list":[
      {"owner":"ADMIN","name":"CUSTOMER"},
      {"owner":"ADMIN","name":"TXN"},
      {"owner":"ADMIN","name":"APPLICATION"},
      {"owner":"ADMIN","name":"CONVERSATION_CHUNK"}
    ]
  }'
);
EXEC DBMS_CLOUD_AI.SET_PROFILE('NUDGE_BOT');
```

What a principal engineer flags here:

1. **`object_list` is a data-minimization control.** It is the
   allow-list of tables the profile can see for NL→SQL grounding. Treat it
   like a privacy data map: every table on this list must have a documented
   reason. **Remove `CUSTOMER.full_name`** from the surface (use a view
   that exposes only `customer_id`, `segment`).
2. **`ADMIN` ownership in the demo is a Free-Tier convenience.** In a real
   bank, the profile's grants resolve through a least-privilege role, never
   `ADMIN`. Module 4 walks the `NUDGE_AGENT` role.
3. **The model name (`cohere.command-r-plus`) is a model-inventory entry.**
   Owner, version, vendor, intended use, region (data residency!), tested
   limitations. SR 11-7 says so.
4. **The provider call leaves the bank.** Even on OCI GenAI, prompt + grounded
   data egress to the model service. Confirm the contractual data-handling
   terms cover NPI; confirm the region is approved by the privacy office.
5. **No content/safety configuration in the profile.** The profile alone does
   not give you UDAAP-grade content filtering. That comes from your wrapper
   package (next section) and from the disclosure-substitution step
   (further below).

## The wrapper-package pattern (`PKG_NUDGE_AI`)

Direct calls to `DBMS_CLOUD_AI.GENERATE` from application SQL are a
control-failure waiting to happen. Every call must go through a wrapper
package that:

- enforces the **opt-in / suppression / frequency-cap** check one more time
  (defense in depth — the upstream check may have been bypassed),
- enforces the **channel-of-record split** (servicing vs. marketing),
- looks up the **approved disclosure language** for the offer's product
  (Reg Z APR, Reg DD APY) and **substitutes** it into the LLM output
  rather than letting the LLM author it,
- inserts an `AI_CALL_LOG` row *before* and *after* the call, with W3C
  trace context attached,
- routes the output to the **UDAAP review queue** when policy says so
  (e.g., new offer, new template, sampled at X%),
- catches errors and returns a **safe deterministic fallback string**
  (never surface a stack trace or a raw provider error to the customer).

The wrapper is the policy enforcement point. Auditors will read it line by
line.

## `AI_CALL_LOG` — the records-of-record table

This is the record that lets you answer a regulator data request of the form
"show me everything you ever sent to customer 1001":

```sql
CREATE TABLE ai_call_log (
  call_id            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at         TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  customer_id        NUMBER,
  use_case           VARCHAR2(30),     -- UC1 / UC2 / UC3
  offer_id           NUMBER,           -- references OFFER (decision context)
  channel            VARCHAR2(20),     -- IN_APP / EMAIL / SMS / PUSH / SERVICING
  channel_of_record  VARCHAR2(20),     -- MARKETING / SERVICING (Reg E vs. CAN-SPAM)
  profile_name       VARCHAR2(128),    -- NUDGE_BOT
  model_name         VARCHAR2(256),    -- cohere.command-r-plus + version
  model_version      VARCHAR2(64),
  trace_id           VARCHAR2(64),     -- W3C traceparent
  span_id            VARCHAR2(32),
  prompt_template_id VARCHAR2(64),     -- approved template, never free-form
  prompt_hash        VARCHAR2(128),    -- SHA-256 of the rendered prompt
  prompt_tokens      NUMBER,
  output_tokens      NUMBER,
  output_hash        VARCHAR2(128),    -- SHA-256 of generated text
  output_text        CLOB,             -- the actual string shown (for retention)
  disclosure_id      VARCHAR2(64),     -- approved Reg Z/Reg DD insert used
  suppression_check  VARCHAR2(20),     -- PASS / FAIL / SKIPPED (must be PASS)
  optin_check        VARCHAR2(20),     -- PASS / FAIL / SKIPPED (must be PASS)
  freq_cap_check     VARCHAR2(20),     -- PASS / FAIL / SKIPPED (must be PASS)
  control_group      VARCHAR2(20),     -- TREATMENT / HOLDOUT
  review_queue_id    NUMBER,           -- UDAAP review ticket, if sampled
  status             VARCHAR2(20),     -- OK / FALLBACK / ERROR
  error_text         VARCHAR2(4000),
  retention_until    DATE              -- bank records-mgmt schedule
);

CREATE INDEX ai_call_log_cust_ix ON ai_call_log(customer_id, created_at);
CREATE INDEX ai_call_log_trace_ix ON ai_call_log(trace_id);
```

Notes:

- `output_text` is intentionally a CLOB, not just a hash — regulators have
  asked for the literal text. The hash alone has been deemed insufficient.
- `retention_until` is computed from records-management policy at insert
  time. It is then enforced by an `ILM` policy or by a scheduled purge job.
  Do **not** retain forever — over-retention is its own privacy risk.
- All three `*_check` columns must be `PASS` for `status = OK`. The
  wrapper enforces it; an integrity check (Module 6 lab) verifies it.

## UDAAP review queue

A percentage of generated nudges (and 100% of nudges using a new template,
new offer, or new model version) is routed to a human review queue before
or after delivery, per bank policy. The queue is just a table:

```sql
CREATE TABLE udaap_review_queue (
  review_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  call_id      NUMBER REFERENCES ai_call_log(call_id),
  reason       VARCHAR2(40),    -- NEW_TEMPLATE / NEW_OFFER / NEW_MODEL / SAMPLED / FLAGGED
  state        VARCHAR2(20),    -- PENDING / APPROVED / REJECTED / DELIVERED_PRE_REVIEW
  reviewer     VARCHAR2(64),
  reviewed_at  TIMESTAMP,
  notes        VARCHAR2(4000)
);
```

The wrapper inserts into this queue when `reason` applies. Module 6 monitors
queue depth and time-in-state.

## Disclosure substitution — the Reg Z / Reg DD trap

The LLM must **never** paraphrase APR, APY, fees, or rate terms. The wrapper:

1. Renders the prompt from an **approved template** (`prompt_template_id`),
   leaving a placeholder like `{{disclosure_block}}`.
2. Calls `GENERATE`.
3. **Replaces** `{{disclosure_block}}` in the output with the
   pre-approved disclosure text fetched from a controlled
   `APPROVED_DISCLOSURES` table keyed by `offer_id` and effective date.
4. Refuses to emit the result if the placeholder is missing or if the LLM
   output contains a numeric % token outside the placeholder.

This pattern keeps the cost-of-credit text out of LLM hands entirely.

## Use-case-specific governance

| UC | Trigger | Channel of record | Most-relevant rules |
|----|---------|-------------------|---------------------|
| UC1 — credit-card page view | Marketing | Marketing (in-app) | UDAAP, Reg Z (if Cash+ Visa APR mentioned), TCPA/CAN-SPAM if pushed off-page |
| UC2 — abandoned application | Marketing/servicing hybrid | Usually marketing (in-app + email if consented) | UDAAP, Reg Z, ECOA (cannot use protected-class attribute to choose who to nudge), CAN-SPAM/TCPA on email/SMS |
| UC3 — declined transaction | Servicing | **Servicing** (Reg E) | Reg E error/dispute, BSA/AML (no SAR-leakage), GLBA. *Not* a marketing message — opt-out does not block it |

UC3 in particular is *not* a marketing nudge. It is account servicing. The
wrapper knows this from the use-case parameter and:

- bypasses marketing opt-out (servicing communications are required),
- still respects channel preferences (e.g., do not SMS if no SMS consent on
  file for servicing),
- uses an even tighter content template,
- is retained on the **servicing** retention schedule, not marketing.

## Spring integration

- Set the Select AI profile once per session via HikariCP `connection-init-sql`.
- Application code calls `PKG_NUDGE_AI.generate(...)` only — never
  `DBMS_CLOUD_AI.GENERATE` directly.
- W3C traceparent is propagated; the wrapper writes `trace_id`/`span_id`
  into `AI_CALL_LOG` so APM and DB audit join one-to-one (critical for
  regulator data requests, Module 6).

## Verify yourself

- `NUDGE_BOT` exists; `object_list` contains only the minimum tables and
  does **not** include `CUSTOMER.full_name`.
- `AI_CALL_LOG` has the SOX/UDAAP/records-mgmt columns above.
- `UDAAP_REVIEW_QUEUE` exists; the wrapper inserts into it for new
  templates / offers / models.
- `APPROVED_DISCLOSURES` exists and is referenced by `PKG_NUDGE_AI`.
- The wrapper refuses any direct grant of `EXECUTE ON DBMS_CLOUD_AI` to the
  app role (only the wrapper's owner has it).
- A test prompt with a `{{disclosure_block}}` placeholder produces an
  output where the placeholder is replaced; remove the placeholder and the
  wrapper rejects.
- A test in `use_case = 'UC3'` is logged with `channel_of_record = 'SERVICING'`.
