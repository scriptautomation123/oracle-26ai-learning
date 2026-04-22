# Module 5 — Putting It All Together (the Offer Lifecycle)

> **Regulatory regimes that shape this module:** all of them. This is the
> module where the controls from Modules 1–4 compose into one defensible
> end-to-end flow per use case. If something in this module isn't in your
> production design, you cannot ship.

## The end-to-end offer lifecycle

This is the model of every nudge in this stack. Every UC — UC1, UC2, UC3 —
follows it. The only differences are the trigger and the channel-of-record
designation.

```text
 1. TRIGGER          page_event / abandoned application / declined txn
 2. RELATIONAL SCOPE customer state, account, segment, last interaction
 3. GRAPH CONTEXT    SQL/PGQ peer / look-alike candidates (UC1)
 4. VECTOR RETRIEVAL similar past conversation snippets (all UCs)
 5. ELIGIBILITY      deterministic OFFER.eligibility_rule check
 6. SUPPRESSION      opt-in + do-not-contact + offer-suppression list
 7. FREQUENCY CAP    rolling-window send count by channel
 8. CHANNEL OF RECORD  marketing vs. servicing routing
 9. CONTROL GROUP    holdout assignment (causal attribution)
10. GENERATION       PKG_NUDGE_AI.GENERATE with approved template
11. DISCLOSURE SUB.  Reg Z / Reg DD approved language injection
12. UDAAP REVIEW     route to queue if sampled / new template / new model
13. DELIVERY         channel-specific dispatch (with quiet hours, throttle)
14. ATTRIBUTION      response/conversion captured for post-event analytics
15. ARCHIVAL         AI_CALL_LOG retention + legal-hold awareness
```

Steps 1–4 are *candidate generation*. Steps 5–7 are *gating*. Step 8 picks
the rulebook for steps 9–13. Steps 14–15 are *the record*. Skipping any
step is a compliance finding.

## Per-use-case execution pattern

### UC1 — credit-card page view

- Trigger: `page_event` on `/products/cash-plus-visa`.
- Graph: peer-product expansion (Module 2) → candidate offers in the
  card family.
- Vector: rank conversation snippets by relevance to "credit card
  comparison help" (or the customer's own recent chat language, narrowed
  by `customer_id`).
- Eligibility: check `OFFER.eligibility_rule` — `Cash+ Visa Intro APR`
  requires `segment in (Prime, Affluent)`. **A `Mass`-segment customer is
  not eligible** and the pipeline must not generate the nudge for them.
- Channel of record: marketing.
- Disclosure: APR language from `APPROVED_DISCLOSURES`.

### UC2 — abandoned application

- Trigger: nightly/intra-day sweep for `application.status = 'STARTED'`
  and `updated_at < SYSTIMESTAMP - INTERVAL '1' HOUR`.
- Vector: snippets relevant to "application abandoned income verification
  step" — narrowed by `customer_id`.
- Eligibility: matches the offer for the application's `product_id`. The
  Personal Loan Cashback offer (`product_id = 2`, `purpose =
  'debt_consolidation'`) draws ECOA scrutiny — Compliance must approve
  the eligibility rule and any segment used in the prompt.
- Channel of record: marketing. Email/SMS only with channel consent.
- Disclosure: Reg Z for credit, Reg DD for the Term Deposit case
  (`product_id = 3`, `new_to_bank = Y`).

### UC3 — declined transaction

- Trigger: `txn.status = 'DECLINED'` within last N minutes.
- Vector: snippets relevant to the `decline_reason` value
  (`SUSPECTED_FRAUD`, `LIMIT_EXCEEDED`).
- Eligibility: not an offer — this is **servicing**.
- Channel of record: **servicing** (Reg E). Marketing opt-out does not block.
- BSA/AML constraint: when `decline_reason = 'SUSPECTED_FRAUD'`, the
  customer-facing language must not reveal SAR-relevant detail. Use the
  generic approved template (`decline_explanation` tool); the LLM is
  *only* allowed to phrase the next-step recommendation, not the reason.

## The decision-log table

Module 3 introduced `AI_CALL_LOG`. Module 4 introduced per-tool logging.
Module 5 unifies them with `OFFER_DECISION_LOG`, the table that proves the
pipeline ran:

```sql
CREATE TABLE offer_decision_log (
  decision_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  decided_at         TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  customer_id        NUMBER,
  use_case           VARCHAR2(30),
  trigger_event_id   NUMBER,             -- page_event_id / app_id / txn_id
  candidate_offers   VARCHAR2(400),      -- comma-separated offer_ids from steps 3–4
  chosen_offer_id    NUMBER,             -- NULL if no offer chosen
  decision           VARCHAR2(30),       -- ELIGIBLE / NOT_ELIGIBLE / SUPPRESSED / FREQ_CAPPED / HOLDOUT / SENT / FALLBACK / ERROR
  decision_reason    VARCHAR2(400),      -- specific reason (FCRA-grade)
  channel            VARCHAR2(20),
  channel_of_record  VARCHAR2(20),
  control_group      VARCHAR2(20),       -- TREATMENT / HOLDOUT
  ai_call_id         NUMBER,             -- FK -> ai_call_log when generated
  trace_id           VARCHAR2(64),
  retention_until    DATE
);

CREATE INDEX odl_cust_ix    ON offer_decision_log(customer_id, decided_at);
CREATE INDEX odl_trace_ix   ON offer_decision_log(trace_id);
CREATE INDEX odl_offer_ix   ON offer_decision_log(chosen_offer_id, decided_at);
```

`decision_reason` is the column that has to be populated even on negative
outcomes (`NOT_ELIGIBLE`, `SUPPRESSED`, `FREQ_CAPPED`). On a regulator
data request you must be able to answer **"why didn't customer 1001 see
the offer?"** as readily as **"why did they?"**.

## Control groups and attribution

Every offer has a holdout. Without a holdout you cannot prove the offer
caused the outcome — and without that proof, attribution claims may
overstate value (a SOX issue if revenue recognition relies on attribution,
and an internal-audit issue regardless).

- Holdout assignment is deterministic from `(customer_id, offer_id)` —
  e.g., `MOD(ORA_HASH(customer_id || ':' || offer_id), 100) < holdout_pct`.
  Deterministic so a customer's holdout status is stable across triggers.
- Holdout customers go through every step *except* generation+delivery.
  Their `OFFER_DECISION_LOG` row has `control_group = 'HOLDOUT'`,
  `decision = 'HOLDOUT'`, `ai_call_id IS NULL`.
- Attribution joins `OFFER_DECISION_LOG` to downstream outcome events
  (application started, account opened, transaction successful) within an
  attribution window.

## Reference Spring integration (anchored to the demo)

- `NudgeRepository.java` — runs SQL/PGQ + vector retrieval + wrapper calls.
- `NudgeService.java` — owns the lifecycle (steps 1–14), emits OTel spans,
  inserts `OFFER_DECISION_LOG` and `AI_CALL_LOG` rows, propagates traceparent.
- `OtelDataSourceConfig.java` — wraps `DataSource` so every JDBC call
  carries trace context the wrapper logs.
- `application.yml` — HikariCP `connection-init-sql` sets `NUDGE_BOT`
  profile per session.

## Deployment topology

- Spring service in OCI compute / container — stateless, horizontally scalable.
- ADB 26ai as the converged data + AI engine — single perimeter for NPI.
- SQLcl MCP server as a separate, narrowly scoped service for interactive
  agent flows; not on the customer-facing path.
- LLM provider (OCI GenAI) accessed only via `NUDGE_BOT`; no direct app
  egress to a model API.

## SLOs (defensible starting numbers — calibrate to your bank)

| SLO | Target | Why this number |
|---|---|---|
| P95 end-to-end nudge latency | < 1200 ms | UC1/UC2 — must complete inside the customer's session window |
| P99 DB retrieval latency (vector + graph + lookup) | < 400 ms | Leaves budget for the LLM call |
| UC3 P95 latency | < 800 ms | Servicing message expected near-real-time |
| Availability (decision pipeline) | ≥ 99.9% | Below this, marketing campaigns leak conversions; above this, marginal cost rises sharply |
| Generated-text fallback rate | ≤ 0.5% | Higher means the LLM provider is degrading or templates are broken |
| Suppression-bypass incidents | 0 | Any non-zero count is a Sev-1 — UDAAP / TCPA exposure |

## Capacity + rollback

- Capacity tested per UC traffic mix and `top_K` size — UC1 dominates,
  UC2 is bursty after batch sweep, UC3 follows decline-rate spikes.
- Model / index / profile / template changes are deployable behind feature
  flags. A flag flip falls back to the prior approved template within one
  HTTP request.
- Rollback path: `EXEC DBMS_CLOUD_AI.SET_PROFILE('NUDGE_BOT_PREV')`,
  redeploy prior `PKG_NUDGE_AI` version, set feature flag back. Document
  this in the runbook (Module 6).

## Demo walkthrough anchor

Use `26ai-banking-demo/docs/demo-script.md` as the live story:

- Show all 3 UCs with the offers-team framing (eligibility → suppression
  → generation → log row).
- Show one customer who is *suppressed* — explain that the lack of a
  delivered nudge is itself a logged decision with a specific reason.
- Show the `AI_CALL_LOG` and `OFFER_DECISION_LOG` rows for one
  customer, joined by `trace_id`. This is the regulator-data-request
  answer in one query.
- Close with cost guardrails (Module 6) and the launch-readiness checklist.

## Launch-readiness checklist (the offers PMO will hold you to this)

### Architecture
- [ ] Architecture document approved by Architecture Review.
- [ ] Data-flow inventory updated (Modules 1, 3, 4) — NPI paths and third-party egress identified.
- [ ] Data residency confirmed for OCI GenAI region.

### Models (SR 11-7)
- [ ] `MINILM_EMB` in model inventory (owner, version, validation, monitoring plan).
- [ ] `cohere.command-r-plus` in model inventory + vendor data-handling terms reviewed.
- [ ] Challenger / fallback strategy documented for both.

### Privacy / Security
- [ ] GLBA NPI mapping covers `CONVERSATION`, `CONVERSATION_CHUNK`, `AI_CALL_LOG.output_text`.
- [ ] GDPR/CCPA erasure path deletes from all three.
- [ ] `NUDGE_AGENT` least-priv verified.
- [ ] Encryption at rest (TDE) + in transit (TLS) verified.
- [ ] Audit ingestion to SIEM verified.

### Compliance
- [ ] UDAAP review queue policy approved (sampling rate, gating rules).
- [ ] Reg Z / Reg DD disclosure templates approved + loaded into `APPROVED_DISCLOSURES`.
- [ ] Reg E classification of UC3 confirmed in writing.
- [ ] ECOA / Reg B sign-off on UC1 graph features and UC2 eligibility.
- [ ] FCRA: no LLM-authored adverse-action reasons. Confirmed.
- [ ] CAN-SPAM / TCPA: opt-in evidence available per channel; quiet-hours enforced.

### Operations
- [ ] On-call runbook (Module 6) validated.
- [ ] SLOs and alerts wired.
- [ ] Cost dashboard and budgets configured (Module 6).
- [ ] Suppression-bypass alarm wired with paging.
- [ ] Records-management retention configured on `AI_CALL_LOG` and `OFFER_DECISION_LOG`.

### Decision quality
- [ ] Holdout / control group enabled per offer.
- [ ] Attribution job scheduled.
- [ ] Disparate-impact monitoring scheduled (Module 6).

If any box is unchecked, you don't ship.
