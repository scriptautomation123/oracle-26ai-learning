# Module 5 — Putting It All Together

## End-to-end architecture

1. Event arrives (page view, abandoned app, declined txn).
2. Relational lookup scopes customer state.
3. SQL/PGQ traversal expands graph context.
4. Vector retrieval ranks semantically relevant snippets.
5. Select AI wrapper generates final nudge.
6. Telemetry + audit record observability and governance.

## Unified UC execution pattern

- UC1: peer product + semantic phrasing for card comparison opener
- UC2: abandoned application reason + empathetic completion nudge
- UC3: declined transaction explanation + safe next-step recommendation

## Reference Spring integration

- `NudgeRepository` executes SQL/PGQ/vector and wrapper calls.
- `NudgeService` adds OpenTelemetry spans + attributes.
- `OtelDataSourceConfig` wraps JDBC with `JdbcTelemetry`.

## Deployment topology

- Spring service in OCI compute/container
- ADB 26ai as converged data + AI engine
- Optional MCP client/server path for agent interactions

## SLO suggestions

- P95 end-to-end nudge latency < 1200ms
- P99 DB retrieval latency < 400ms
- Availability target >= 99.9%
- Recall sanity threshold for canary prompts

## Capacity + rollback

- Capacity tests by UC traffic mix and top-K size.
- Keep model/index/profile changes deployable behind feature flags.
- Rollback path includes profile reset + prior package version.

## Demo walkthrough anchor

Use `docs/demo-script.md` as the board-level story:
- show all 3 UCs,
- show observability and cost guardrails,
- close with governance controls.

## Final review-board checklist

- [ ] Architecture approved (data flow + controls)
- [ ] Security model approved (RBAC + wrappers)
- [ ] Performance baseline captured
- [ ] Cost dashboard and budgets configured
- [ ] On-call runbook validated
