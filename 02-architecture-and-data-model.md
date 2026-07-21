# Architecture and Data Model

This chapter explains the banking demo as a converged Oracle Database 26ai system. The point is not to flatten the architecture into a slogan. The point is to show how the relational model, vector search, property graph, Select AI, MCP, and the front-end surfaces all fit into one operational surface.

## Design principle

Keep the source of truth in Oracle Database 26ai.

That means:

- Extend the existing schema rather than replacing it.
- Store vectors in the same database as the source rows.
- Expose graph semantics as an overlay on relational data.
- Use APEX and MCP as delivery surfaces, not as separate systems of record.

This matters because the bank already has a perimeter, an audit model, and a backup story for its relational systems. The demo stays inside that model instead of creating a new one.

## Banking and marketing operating model

This architecture is designed to support two business functions in one governed path.

- Banking function: enforce eligibility, servicing classification, and auditable decision records.
- Marketing function: improve nudge relevance, timing, and channel execution while honoring suppression policy.

The same technical path supports both functions because relational filters, policy checks, and logs are executed before and after generation.

## What Oracle 26ai adds

| Primitive | Practical role |
| --- | --- |
| `VECTOR` column | Stores embeddings for conversation chunks, offer content, and related text artifacts |
| ONNX embedding model | Generates embeddings inside the database |
| ANN vector index | Supports low-latency nearest-neighbor retrieval |
| `VECTOR_EMBEDDING` and `VECTOR_DISTANCE` | SQL operators for embedding and semantic distance |
| SQL/PGQ property graph | Traverses relationships across the existing relational schema |
| `DBMS_CLOUD_AI` Select AI profile | Governs natural language to SQL generation for UC3 |
| SQLcl MCP server | Exposes database capabilities as tools to an external agent |

The architecture is useful because each primitive solves a different part of the same problem:

- vectors for meaning,
- graphs for relationships,
- relational predicates for governance and filtering,
- Select AI for governed natural-language generation,
- MCP for a tool surface that can be explicitly controlled.

## Data model evolution

| Existing asset | Addition in 26ai | Outcome |
| --- | --- | --- |
| Customer, account, transaction, application tables | No structural replacement | Preserve the system of record |
| Conversation transcripts and offer content | Chunking plus vector columns | Semantic retrieval over unstructured text |
| Foreign-key relationships across entities | Property graph definition | Traverse customer, product, offer, and event relationships |

The same table can hold relational attributes, JSON or CLOB content, and vector data. The AI features augment the row structure instead of forcing a new datastore.

## Execution pattern

The request path is intentionally layered.

1. A trigger event enters from web, mobile, or core banking systems.
2. Relational filters narrow the candidate set.
3. Property graph traversal expands the relevant relationships.
4. Vector search ranks the text artifacts that best match the live context.
5. The nudge is composed and delivered through APEX, chat, or agent tooling.

That sequence is deliberate. It keeps the final decision deterministic enough for audit replay while still allowing retrieval to use all available context.

## Use-case execution through the banking and marketing lens

### UC1: credit-card page view

- Business class: marketing.
- Banking requirement: offer must still pass deterministic eligibility boundaries.
- Marketing requirement: the nudge should be contextual and in-session.

### UC2: abandoned application

- Business class: marketing with workflow recovery intent.
- Banking requirement: application state and customer context must remain consistent and explainable.
- Marketing requirement: re-engagement should be relevant, channel-safe, and frequency-controlled.

### UC3: declined transaction

- Business class: servicing.
- Banking requirement: explanation and next-step guidance must remain policy-safe and auditable.
- Marketing requirement: do not misclassify this flow as promotional outreach.

## Query shape

Precision comes from the business filters. Semantic ranking resolves the tie-breaks.

```sql
SELECT /*+ expected: filter-first, then ANN */
       o.offer_id,
       o.offer_name,
       VECTOR_DISTANCE(o.offer_vec, :context_vec, COSINE) AS score
FROM   offers o
JOIN   customer_profile p ON p.customer_id = :customer_id
WHERE  p.segment = o.target_segment
  AND  o.product_family = 'CREDIT_CARD'
  AND  o.region = p.region
ORDER  BY score
FETCH FIRST 5 ROWS ONLY;
```

The same pattern applies to conversation retrieval, offer ranking, and policy-text grounding. The business filter determines what is allowed. The semantic score only resolves which allowed option is best.

## Delivery surfaces

- APEX provides the banker-facing chat surface.
- SQLcl MCP exposes the same database functions as tools to a model or agent.
- The SQL use cases remain the canonical executable examples.

The delivery surface changes, but the data path does not.

## What the reader should notice

A human reader should be able to follow the system from trigger to decision without leaving this chapter:

- where the trigger enters,
- how relational filtering limits exposure,
- how graph traversal adds structure,
- how vector search adds semantic retrieval,
- how the final response is produced,
- and where the bank keeps the audit trail.

## Next phase handoff

Next phase: database build.

Read next:

- [03-dba-and-query-patterns.md](03-dba-and-query-patterns.md)

Run next:

- `./scripts/db/start_oracle_container.sh`
- `./scripts/db/run_sql_sequence.sh --connect user/password@dsn sql/foundation/01_schema.sql sql/foundation/02_staging_ddl.sql sql/foundation/03_load_onnx_model.sql sql/foundation/04_copy_data.sql sql/foundation/05_transform.sql sql/ai/06_embed_and_index.sql sql/ai/07_property_graph.sql sql/ai/08_select_ai_profile.sql`
- `./scripts/db/run_sql_sequence.sh --connect user/password@dsn sql/runtime/12_app_runtime_tables.sql`
