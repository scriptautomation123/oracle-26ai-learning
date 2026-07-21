# DBA and Query Patterns

This chapter is the long-form DBA and implementation view of the banking demo. It maps AI concepts to database concepts, explains the run order, and shows why the query shape is the way it is.

## Operational taxonomy

The repository is now organized around operational phases rather than a flat numbered script list. That is the right shape for a team that spans DBA, application, operations, and demo ownership.

| Phase | Purpose | Primary paths |
| --- | --- | --- |
| Setup | Local environment bootstrap and credentials readiness | `scripts/setup/` |
| Data preparation | Dataset download, shaping, and upload | `scripts/data/` |
| Database build | Schema, staging, model load, transform, graph, and runtime support | `sql/foundation/`, `sql/ai/`, `sql/runtime/`, `scripts/db/` |
| Use-case run | Execute UC1, UC2, and UC3 directly against the built database | `sql/use-cases/`, `docs/demo-script.md` |
| Integration | Install MCP/APEX SQL surfaces and run Spring/MCP consumers | `sql/integration/`, `scripts/db/`, `spring/`, `mcp/` |
| Cleanup | Remove generated data, local build output, and local Oracle container state | `scripts/cleanup/` |

## The core mental shift

The banking demo does not introduce a new class of system. It introduces new operators and new index types on top of the same database the team already knows how to operate.

| New thing | What it really is in DBA terms |
| --- | --- |
| `VECTOR` column | A fixed-length float array stored with the row |
| ONNX embedding model | A stored function that converts text to a vector |
| Vector index | A new index type optimized for nearest-neighbor search |
| `VECTOR_EMBEDDING` | SQL operator that materializes embeddings at query time |
| `VECTOR_DISTANCE` | SQL operator that measures semantic proximity |
| SQL/PGQ graph | A view-like overlay on existing tables |
| Select AI profile | `DBMS_CLOUD_AI` configuration for natural language to SQL |
| MCP server | A listener-like surface that exposes DB tools to external clients |

That framing matters because the operational burden stays familiar. The database is still the system to patch, monitor, back up, secure, and tune.

## Why the run order matters

The SQL run order creates the dependencies in the right sequence.

1. Schema first.
2. Staging and transform next.
3. Embeddings and vector index after the data is clean.
4. Property graph after the relational keys are available.
5. Select AI profile after the target schema is complete.
6. UC1, UC2, and UC3 only after the prerequisites are in place.

That sequence keeps the derived layers stable and makes the demo repeatable.

## Phase-by-phase operating path

### 1. Setup

Use setup only for local workstation or Codespaces preparation.

Commands:

```bash
source scripts/setup/setup_venv.sh
./scripts/setup/setup_kaggle.sh
```

Purpose:

- create or refresh the local Python environment,
- install CLI dependencies,
- validate Kaggle credentials before any data operation starts.

### 2. Data preparation

This phase exists so raw acquisition and shaping are separate from database build.

Commands:

```bash
./scripts/data/download_datasets.sh
python3 scripts/data/trim_lending.py --input data/raw/lendingclub/accepted_2007_to_2018Q4.csv --output data/processed/lendingclub_5k.csv
python3 scripts/data/generate_conversations.py --input data/raw/banking77/banking77.csv --output data/processed/banking77_conversations.csv
OCI_NAMESPACE=<ns> OCI_BUCKET_NAME=<bucket> ./scripts/data/upload_to_oci.sh
```

Purpose:

- acquire the public datasets,
- shape them into demo-scale assets,
- optionally upload them to OCI Object Storage for Autonomous Database loading.

### 3. Database build

This is the core DBA phase and it should remain linear.

SQL groups:

- `sql/foundation/01_schema.sql`
- `sql/foundation/02_staging_ddl.sql`
- `sql/foundation/03_load_onnx_model.sql`
- `sql/foundation/04_copy_data.sql`
- `sql/foundation/05_transform.sql`
- `sql/ai/06_embed_and_index.sql`
- `sql/ai/07_property_graph.sql`
- `sql/ai/08_select_ai_profile.sql`
- `sql/runtime/12_app_runtime_tables.sql`

Helper commands:

```bash
./scripts/db/start_oracle_container.sh
./scripts/db/run_sql_sequence.sh --connect user/password@dsn sql/foundation/01_schema.sql sql/foundation/02_staging_ddl.sql
```

Purpose:

- create the base schema,
- load staged data,
- build the vector and graph layers,
- create runtime support objects used by service and tool surfaces.

### 4. Use-case run

This phase is where the demo becomes observable to humans.

SQL group:

- `sql/use-cases/09_uc1_card_view.sql`
- `sql/use-cases/10_uc2_abandoned_app.sql`
- `sql/use-cases/11_uc3_declined_txn.sql`

Purpose:

- validate the business moments directly in SQL,
- demonstrate the separation between marketing and servicing flows,
- provide the canonical demo run path used by [demo-script.md](demo-script.md).

### 5. Integration

This phase installs and documents the non-core delivery surfaces.

SQL group:

- `sql/integration/13_mcp_peer_products_tool.sql`
- `sql/integration/14_apex_nudge_chat_api.sql`

Helper commands:

```bash
./scripts/db/install_app_sql_extensions.sh --connect user/password@dsn
```

Consumer surfaces:

- `mcp/README.md`
- `spring/README.md`

Purpose:

- install MCP named tool SQL,
- install the APEX-facing PL/SQL package,
- bind the database build to the Spring and MCP demo surfaces.

### 6. Cleanup

Cleanup is now explicit instead of being an untracked manual afterthought.

Commands:

```bash
./scripts/cleanup/purge_generated_data.sh
./scripts/cleanup/purge_workspace_artifacts.sh
./scripts/cleanup/stop_oracle_container.sh --remove
./scripts/demo/orchestrate.sh --mode container --stage cleanup
```

Purpose:

- remove staged and generated local data,
- remove build and workspace artifacts,
- stop or remove the local Oracle container used for demo work.

## Query shape and plan shape

The demo uses a business filter first, then semantic ranking.

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

The practical point is that precision comes from the relational predicates. The vector score is used to rank only the rows that already passed the business rules.

## Capacity planning

Use the embedding dimension as the base storage estimate.

- Raw embedding bytes per row = dimensions x 4 for FLOAT32.
- Planned data segment = roughly 1.2x to 1.5x of the raw total.
- Vector index = roughly 0.5x to 1.5x of the raw total, depending on the index type and tuning.
- Add 25% to 40% headroom for growth and rebuild churn.

Example planning for offers only:

- 2,000,000 offers x 384 dimensions x 4 bytes = about 3.07 GB raw.
- A practical data and index envelope often lands between about 5.5 GB and 11 GB before headroom.
- With 30% headroom, the working provision is roughly 7 GB to 14.3 GB.

The right process is to measure a pilot load, build the index, and compare before and after segment usage.

```sql
SELECT COUNT(*) AS offer_rows,
       384 AS dims,
       COUNT(*) * 384 * 4 AS raw_embedding_bytes
FROM   offers;

SELECT segment_name,
       segment_type,
       ROUND(SUM(bytes)/1024/1024, 2) AS mb
FROM   user_segments
WHERE  segment_name IN (
  'OFFERS',
  'OFFERS_EMBED_IDX'
)
GROUP  BY segment_name, segment_type
ORDER  BY mb DESC;
```

## Latency and scale posture

The design target is to act while the customer context is still fresh.

- Time-to-nudge target: less than 2 seconds end to end.
- Retrieval target: sub-100ms for filtered nearest-neighbor paths at scale.
- Throughput model: event bursts tied to traffic spikes and settlement cycles.

Exadata Smart Scan for vectors matters when filtered ANN queries coexist with large scans.

## DBA consequences of the design

A DBA reading this should notice a few things immediately:

- The bank is not introducing a second persistence engine.
- The AI primitives are modelled as DB objects, not as a sidecar application.
- The index and model artifacts deserve change control and versioning.
- The same audit and retention model needs to cover derived data as well as source data.

## What to read next

- [00-start-here.md](00-start-here.md) for the recommended chapter order.
- [README.md](../README.md) for the repository-level phase map and command summary.

## Next phase handoff

Next phase: use-case run.

Read next:

- [demo-script.md](demo-script.md)
- [01-business-and-vision.md](01-business-and-vision.md)

Run next:

- `./scripts/db/run_sql_sequence.sh --connect user/password@dsn sql/use-cases/09_uc1_card_view.sql sql/use-cases/10_uc2_abandoned_app.sql sql/use-cases/11_uc3_declined_txn.sql`
- `./scripts/demo/orchestrate.sh --mode cloud --stage sql-uc --connect user/password@dsn`
