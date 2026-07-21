# Operations and Controls

This chapter covers the production concerns that make the banking demo defensible: latency, retention, audit, model monitoring, fallback behavior, and the evidence required for review.

## Banking and marketing control objectives

Operations in this demo has to satisfy both banking control quality and marketing execution quality.

- Banking control objectives: decision traceability, policy-safe servicing behavior, retention discipline, legal-hold compliance, and replayable audit evidence.
- Marketing control objectives: relevant in-session nudges, suppression-safe delivery, frequency and channel discipline, and measurable attribution quality.

The system is healthy only when both objective sets are healthy.

## What changes when ops is also audit

In a regulated bank, the ops dashboard is also evidence. The system must answer questions such as:

- What did this customer see?
- Why was one offer chosen and another suppressed?
- Which model or template was used?
- What was retained, and for how long?
- Which controls were checked before delivery?

That is why the operational path has to preserve traceability from the start.

## Golden signals

The stack should be monitored like a production system and like a regulated records system.

- Latency: end-to-end nudge latency and component latency for vector, graph, eligibility, suppression, generation, and dispatch.
- Traffic: requests by use case, by channel, by offer family, and by top-K size.
- Errors: SQL failures, wrapper exceptions, LLM provider errors, fallback rate.
- Saturation: DB CPU, IO, memory, connection pool utilization, MCP concurrency, provider rate limits.

Bank-specific signals matter just as much:

- suppression-bypass count,
- disclosure-substitution-failure count,
- UDAAP review-queue depth and oldest pending item.

## Monitoring split: banking posture and marketing posture

Use one dashboard with two explicit sections.

- Banking posture: servicing correctness, decision-log integrity, retention-job success, legal-hold bypass rate, regulator-query readiness.
- Marketing posture: UC1/UC2 conversion lift, suppression hit-rate quality, channel compliance, abandonment recovery trend, fallback impact on campaign outcomes.

This keeps operations from optimizing conversion while accidentally degrading control quality, or vice versa.

## Reliability model

Failure handling should be graceful instead of brittle.

- CDC lag: serve a stale but safe profile view and suppress risky nudges.
- Embedding or index lag: fall back to relational rules with conservative templates.
- Graph timeout: continue with the relational and vector candidate set.
- Channel delivery failure: persist the decision envelope for retry and replay.

The aim is to preserve safety and auditability even when a subsystem is degraded.

## Audit retention and legal hold

Retention is part of the control design.

- `AI_CALL_LOG.retention_until` and `OFFER_DECISION_LOG.retention_until` are computed at insert time.
- The purge job must consult `LEGAL_HOLD` before deleting anything.
- Erasure-on-request works only when legal hold does not apply.
- Regulator data requests should be satisfiable by a controlled join across decision and call logs.

A system that retains too much is a privacy risk. A system that retains too little is an audit risk.

## Cost controls

Cost control belongs in operations, not in a separate finance-only appendix.

- Tag by environment, use case, and offer family.
- Monitor token usage and reconcile it against provider billing.
- Use fallback templates if the provider degrades or costs spike.
- Keep budget thresholds visible to the team that owns the customer-facing path.

## Disparate-impact monitoring

If the system touches credit-product presentation, monitoring for fairness is required.

- Sample `OFFER_DECISION_LOG` by segment and product family.
- Measure presentation rate and suppression outcomes.
- Compare by the approved monitoring dimensions.
- Route exceptions into a controlled compliance artifact, not an ad hoc dashboard.

## Delivery and rollback

The operational design should make rollback simple.

- Keep templates versioned.
- Keep the Select AI profile swappable.
- Keep the wrapper package versioned.
- Keep a prior-approved path ready in case a new model, template, or rule needs to be reversed.

The operator should be able to recover the system without redesigning the data path.

## What the reader should notice

A human reading this chapter should understand:

- what the main failure modes are,
- which signals prove the system is healthy,
- how the bank proves it obeyed retention and legal-hold policy,
- how fairness monitoring fits into operations,
- and how rollback preserves both safety and continuity.
- how banking controls and marketing outcomes are jointly managed, not treated as separate systems.

## Next phase handoff

Next phase: cleanup.

Read next:

- [90-finish-and-readiness.md](90-finish-and-readiness.md)

Run next:

- `./scripts/cleanup/purge_workspace_artifacts.sh`
- `./scripts/cleanup/purge_generated_data.sh`
- `./scripts/cleanup/stop_oracle_container.sh --remove`
- `./scripts/demo/orchestrate.sh --mode container --stage cleanup`
