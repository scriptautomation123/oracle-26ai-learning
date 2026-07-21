# Module 6 — Operations and Observability (for Regulators, Not Just SREs)

> **Regulatory regimes that shape this module:** SR 11-7 / OCC 2011-12
> (model monitoring is mandatory, not optional), GLBA + records management
> (audit trail retention, legal hold), Reg B / ECOA (disparate-impact
> monitoring on offer presentation), UDAAP (review-queue SLAs), NYDFS Part
> 500 (incident reporting clock — usually 72 hours), SOX (ITGC over
> attribution and cost reporting), CCPA/GDPR (DSAR fulfillment SLA).

## What changes when "ops" is also "audit"

In a regulated bank, the ops dashboard is also evidence. A regulator will
ask:

- "Show me, for this customer, every nudge they were shown and every nudge
  they were *not* shown, with reasons."
- "Show me your model monitoring for the last 12 months."
- "Show me the time-to-resolution distribution of your UDAAP review queue."
- "Show me proof that opt-out was honored on date X."
- "Show me the disparate-impact analysis on offer presentation by
  protected-class proxy."

Module 6's job is to make those answers come back as a single SQL or
single dashboard, not as a forensic project.

## Golden signals — mapped to this stack

- **Latency:** UC pipeline (steps 1–13) end-to-end + each component (vector,
  graph, eligibility, suppression, generate, dispatch).
- **Traffic:** requests per UC, per channel, per offer; top-K size
  distribution.
- **Errors:** SQL failures, wrapper exceptions (separated by control:
  eligibility, suppression, disclosure, LLM provider), fallback rate.
- **Saturation:** DB CPU/IO/memory, HikariCP utilization, MCP tool
  concurrency, LLM provider rate-limit headers.

Plus three banking-specific signals:

- **Suppression-bypass count** (must be exactly 0; any value pages on-call).
- **Disclosure-substitution-failure count** (placeholder missing or
  numeric leak — pages on-call).
- **UDAAP-review-queue depth and oldest pending** (breach of policy SLA
  pages PMO).

## Vector plan inspection

`EXPLAIN PLAN` on the canonical top-K query and confirm the vector index
operation is selected. Capture this plan into SQL Plan Management as a
baseline:

```sql
DBMS_SPM.LOAD_PLANS_FROM_CURSOR_CACHE(sql_id => '...');
```

Repeat per release. A regression to a non-vector path on a top-K query
is a Sev-2 (latency hit) and a soft-availability event for the offers
team.

## Recall canary

Have a fixed list of (query_text, expected_chunk_id) canary pairs. Per
release, measure recall@K for the ANN index against the exact-distance
ground truth. A drop > X% (set policy threshold) blocks release. This is
how you satisfy SR 11-7's "ongoing monitoring" requirement on the
embedding model.

## AWR / ASH focus areas

- Top SQL by DB time for vector queries and `GRAPH_TABLE` queries.
- Wait profile shifts during marketing-burst windows (UC2 sweep).
- Parse/exec frequency for `DBMS_CLOUD_AI` calls.
- Plan changes flagged by SPM.

## Resource Manager containment

`NUDGE_AGENT` (interactive agent) and `NUDGE_APP` (Spring service) belong
to consumer groups with bounded CPU and parallel servers. The OLTP
banking workload is in a higher-priority group. An ad-hoc agent question
must not throttle a customer's transaction posting.

## OpenTelemetry integration

- Wrap `DataSource` with `JdbcTelemetry.create(otel).wrap(raw)` (see
  `26ai-banking-demo/examples/spring/OtelDataSourceConfig.java`).
- Span attributes per nudge:
  - `nudge.customer_id`
  - `nudge.use_case`
  - `nudge.offer_id`
  - `nudge.candidates`
  - `nudge.length_chars`
  - `nudge.channel`
  - `nudge.channel_of_record`
  - `nudge.control_group`
  - `nudge.suppression_result`
- Propagate W3C `traceparent` into `AI_CALL_LOG` (`trace_id`, `span_id`)
  and `OFFER_DECISION_LOG` for one-to-one APM↔DB correlation. This is
  what makes a "show me everything for this customer" query feasible
  across tiers.

## Micrometer metrics

- Counters: `nudge.requests.total{uc,channel}`,
  `nudge.suppressed.total{reason}`,
  `nudge.eligibility.fail.total{offer}`,
  `nudge.fallback.total{component}`,
  `nudge.errors.total{component}`,
  `nudge.suppression.bypass.total` (alarm > 0).
- Timers: `nudge.latency`, `nudge.db.vector.latency`,
  `nudge.db.graph.latency`, `nudge.llm.latency`.
- Gauges: `nudge.review.queue.depth`,
  `nudge.review.queue.oldest_pending_seconds`.

## Disparate-impact monitoring (Reg B / ECOA + Fair Lending)

Schedule this. It's not optional for credit-product offers.

- Daily / weekly job samples `OFFER_DECISION_LOG` joined to `CUSTOMER`.
- Compute presentation-rate by `segment` (and any other monitored
  attribute approved by Compliance) for each `chosen_offer_id` in the
  credit family.
- Compute the same on `decision = 'NOT_ELIGIBLE'` and
  `decision = 'SUPPRESSED'`.
- Statistical test (e.g., proportions test) flags meaningful deltas to
  Compliance.
- Output goes to a controlled report, not a dashboard tile — this is a
  compliance artifact, not an SRE one.

## Cost controls (FinOps + SOX)

- OCI cost-tracking tags per env / use case / offer family.
- Cost dashboard widgets by service + tag.
- Budget thresholds at 50 / 80 / 100% with paging at 80%.
- In-DB reconciliation: join `AI_CALL_LOG.prompt_tokens + output_tokens`
  by day to OCI billing exports for variance check. Variance > X% is
  investigated (a SOX-relevant control if attribution feeds revenue
  reporting).

## Audit retention and legal hold

- `AI_CALL_LOG.retention_until` and `OFFER_DECISION_LOG.retention_until`
  computed at insert time per records-management policy
  (typical: 7 years for marketing communications, longer for credit
  decisions per FCRA).
- Purge job runs on schedule, **but** checks a `LEGAL_HOLD` table first.
  Any `customer_id` (or class of records) on legal hold is exempt from
  purge regardless of `retention_until`. Test this annually.
- Erasure-on-request (GDPR/CCPA) is the *opposite* path: it deletes
  before retention expiry, and only when no legal hold applies.

## Initial alert set

| Alert | Threshold | Page |
|---|---|---|
| P95 latency breach | UC SLO from Module 5 | On-call eng |
| Error-rate anomaly | > policy | On-call eng |
| Token / cost spike | > daily budget projection | FinOps + on-call |
| Recall canary failure | > release-policy delta | Model owner |
| **Suppression bypass** | > 0 | On-call eng + Compliance Sev-1 |
| **Disclosure-substitution failure** | > 0 | On-call eng + Compliance Sev-1 |
| UDAAP-queue oldest-pending | > policy SLA | PMO + Compliance |
| Fair-lending drift | proportions test | Compliance |
| LLM provider 5xx burst | > policy | On-call eng (fallback engages automatically) |
| Audit-log ingestion gap | > 5 min | On-call eng (regulator-evidence integrity) |

## Incident playbooks

1. **Slow nudges.** Identify bottleneck (HikariCP / DB SQL / LLM provider) via
   OTel. Shed load by lowering top-K; engage LLM fallback template; if
   provider is the cause, flip the feature flag to deterministic templates.
2. **Cost spike.** Throttle `nudge.requests` per minute; flip profile to
   lower-cost model variant; pause non-essential UCs; notify FinOps.
3. **Recall degradation.** Compare canary hit sets; check for index
   maintenance; verify model file hash unchanged; rebuild index off-peak;
   open SR 11-7 model-monitoring finding.
4. **Suppression bypass detected.** Halt the affected UC channel
   immediately; snapshot impacted decisions from `OFFER_DECISION_LOG`;
   notify Compliance (Sev-1); write a customer-impact memo with counts;
   begin remediation under change control.
5. **Disclosure-substitution failure.** Halt the affected offer; verify
   no impacted customer received the bad copy (check `AI_CALL_LOG.output_text`);
   if any did, follow Compliance's customer-notification runbook (a
   regulated-disclosure error has its own remediation path).
6. **Regulator data request.** Run the standard query: join
   `OFFER_DECISION_LOG` ⨝ `AI_CALL_LOG` on `customer_id` (and optionally
   on `trace_id`) for the requested time range. Hand the result to
   Compliance; do not interpret.
7. **NYDFS / cyber incident.** Start the 72-hour clock; preserve audit
   logs; isolate LLM provider connectivity if the provider is implicated.

## Operations checklist (daily)

- [ ] On-call dashboards green (latency, errors, suppression-bypass,
      disclosure-substitution, UDAAP queue).
- [ ] Budget burn under projection.
- [ ] Recall canaries passing.
- [ ] SQL plan baselines healthy (no vector regressions).
- [ ] Audit ingestion to SIEM is current.
- [ ] UDAAP queue oldest-pending under SLA.
- [ ] Disparate-impact report from last cycle has no flags.
- [ ] Fallback rate < SLO.

## Verify yourself

- Query `v$sqlstats` for AI-workload SQL IDs and confirm vector index ops.
- Re-run the canonical vector `EXPLAIN PLAN` and verify the vector index
  operation is selected.
- Confirm `AI_CALL_LOG` has `trace_id`, `span_id`, `prompt_template_id`,
  `prompt_hash`, `output_hash`, `output_text`, `disclosure_id`,
  `suppression_check`, `optin_check`, `freq_cap_check`, `control_group`,
  `retention_until` columns.
- Confirm `OFFER_DECISION_LOG` exists with `decision_reason` and
  `retention_until`.
- Confirm `LEGAL_HOLD` is consulted by the retention-purge job (read the
  job's source).
- Run a synthetic suppression-bypass detection test: insert a row that
  *would* be a bypass into a test schema; the alarm fires within the
  policy window.
- Run a fair-lending sampling query against `OFFER_DECISION_LOG` and
  confirm it returns. (You don't need a finding — you need the
  capability to be wired.)
