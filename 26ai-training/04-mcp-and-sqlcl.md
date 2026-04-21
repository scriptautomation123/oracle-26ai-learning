# Module 4 — MCP and SQLcl `-mcp`

## MCP in one sentence

MCP is a protocol that lets LLM agents call database-backed tools with explicit interfaces.

## Repo anchor

`mcp/README.md` shows SQLcl MCP server startup and client wiring.

## Named tool example

See `mcp/tools/peer_products.sql` for a parameterized graph-query tool.

## Recommended initial tool catalog

1. `peer_products(cid, limit)`
2. `recent_declines(cid, lookback_hours)`
3. `similar_chunks(query_text, top_k)`
4. `generate_nudge_uc3(cid, txn_id)` (via wrapper)

## Hardening recipe

- Dedicated DB user (`NUDGE_AGENT`) with least privilege.
- Remove destructive system privileges.
- Expose vetted wrappers/packages, not arbitrary SQL.
- Enable full audit and per-tool logging.

## Spring integration patterns

- Agent tier invokes MCP tools.
- Spring app remains system-of-record orchestrator.
- DB package wrappers enforce policy and audit.

## Verify yourself

- `NUDGE_AGENT` exists.
- Destructive system privileges are absent.
- `PKG_NUDGE_AI.GENERATE` wrapper is present.
