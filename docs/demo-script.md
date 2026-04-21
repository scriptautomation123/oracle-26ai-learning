# 5-day build and demo walkthrough

| Day | Focus | Outcome |
|---|---|---|
| Day 1 | Provision ADB + Object Storage, run schema/staging SQL, seed baseline rows | Core relational model ready |
| Day 2 | Load ONNX model, run embedding job, build vector index | Semantic retrieval working |
| Day 3 | Create property graph and validate UC1/UC2 SQL patterns | Graph + vector + relational fusion demonstrated |
| Day 4 | Configure Select AI profile and SQLcl MCP endpoint | Agentic RAG and NL tooling enabled |
| Day 5 | Build APEX page and record demo for UC1/UC2/UC3 | End-to-end demo artifact complete |

## Recorded-demo script

1. Show README run order and resource limits.
2. Execute UC1 query after inserting a new card `page_event`.
3. Execute UC2 query for an `ABANDONED` application.
4. Execute UC3 declined-transaction prompt.
5. Show MCP invocation (`sql -mcp`) and one NL request.
6. Conclude with cost guardrails and free-tier boundaries.
