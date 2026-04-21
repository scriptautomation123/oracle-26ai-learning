# Module 6 — Operations and Observability

## Golden signals mapped to this stack

- Latency: UC query chain + generation time
- Traffic: requests per use case + top-K volumes
- Errors: SQL failures, wrapper exceptions, LLM provider errors
- Saturation: DB CPU/IO/memory + pool utilization

## Vector plan inspection

Use `EXPLAIN PLAN` and validate vector index operations. Control recall/latency tradeoff with `APPROX TARGET ACCURACY` and a canary recall sanity check.

## AWR/ASH focus areas

- High DB time SQL IDs for vector and `GRAPH_TABLE` statements
- Wait profile shifts during workload spikes
- Parse/exec frequency for generated SQL paths

## SQL Plan Management for vector SQL

Capture known-good plans for canonical top-K statements and monitor plan regressions.

## Resource Manager containment

Constrain `NUDGE_AGENT` consumer group so ad-hoc agent/tool activity cannot starve transactional lanes.

## Audit wrapper + table

Use `pkg_nudge_ai.generate` wrapper and `ai_call_log` to capture:
- profile/model
- prompt/output token counts
- trace/span IDs
- status/error details

## OpenTelemetry integration

Wrap `DataSource` with `JdbcTelemetry.create(otel).wrap(raw)`.
Attach span attributes:
- `nudge.customer_id`
- `nudge.use_case`
- `nudge.candidates`
- `nudge.length_chars`

Propagate W3C `traceparent` into `ai_call_log` (`trace_id`, `span_id`) for one-to-one APM↔DB correlation.

## Micrometer metrics

- Counters: `nudge.requests.total`, `nudge.errors.total`
- Timers: `nudge.latency`, `nudge.db.vector.latency`, `nudge.db.graph.latency`

## OCI cost controls

- Apply cost-tracking tags per env/use case.
- Cost Analysis dashboard widgets by service + tag.
- Budget thresholds at 50/80/100% with notifications.

## In-DB reconciliation query

Join app-level call counts/tokens with OCI billing exports for periodic variance checks.

## Initial alert set

- P95 latency breach
- Error-rate anomaly
- Token/cost spike
- Vector recall canary failure

## Incident playbooks

1. Slow nudges: isolate bottleneck (pool vs SQL vs LLM) and shed load.
2. Cost spike: disable high-cost model/profile path and enforce lower-cost fallback.
3. Recall degradation: compare canary hit sets, verify model/index drift, rebuild as needed.

## Operations checklist

- [ ] On-call dashboards green
- [ ] Budget alerts verified
- [ ] Canaries passing
- [ ] Plan baselines healthy
- [ ] Audit ingestion complete

## Verify yourself

- Query `v$sqlstats` for AI workload SQL IDs.
- Re-run canonical vector `EXPLAIN PLAN` and verify vector index op.
- Confirm `AI_CALL_LOG` contains trace/token/model/profile columns.
