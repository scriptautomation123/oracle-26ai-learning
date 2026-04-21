# Oracle 26ai Training Track — For the Senior Java/Spring + Oracle DBA

This track teaches the AI surface of Oracle Autonomous Database 26ai using the
**Proactive Banking Nudges POC** in this repo as the running example.

It is written for an audience that:
- Already writes production-grade Java + Spring Boot (JDBC, transactions, connection pools).
- Already operates Oracle as a DBA (init params, AWR, indexes, partitioning, RMAN).
- Is **new to AI primitives**: vectors, embeddings, ANN indexes, RAG, agents, MCP.

Every concept is anchored to something you already know. We use the actual files
in this repo at commit `4b7ab11f0a1954def45bbd4fd5bbe6bb33b4c388`.

## Modules

| # | File | Topic | Repo files covered |
|---|------|-------|--------------------|
| 1 | `01-vectors-and-embeddings.md` | VECTOR datatype, ONNX embeddings, ANN indexes, hybrid search | `sql/03_load_onnx_model.sql`, `sql/06_embed_and_index.sql` |
| 2 | `02-sql-pgq-property-graphs.md` | SQL/PGQ (ISO 2023), graph views over relational tables | `sql/07_property_graph.sql`, `sql/09_uc1_card_view.sql` |
| 3 | `03-select-ai-and-dbms-cloud-ai.md` | NL→SQL, RAG, `DBMS_CLOUD_AI`, governance | `sql/08_select_ai_profile.sql`, `sql/11_uc3_declined_txn.sql` |
| 4 | `04-mcp-and-sqlcl.md` | Model Context Protocol, SQLcl `-mcp`, agent integration | `mcp/README.md` |
| 5 | `05-putting-it-all-together.md` | End-to-end architecture, Spring Boot integration, ops & SLOs | `docs/architecture.md`, `docs/demo-script.md`, all UC files |
| 6 | `06-operations-and-observability.md` | AWR/ASH for vector + SQL/PGQ, OTel `JdbcTemplate`, OCI cost dashboards, playbooks | All of the above + ops |

## Companion code

| File | What it shows |
|------|---------------|
| `examples/spring/NudgeRepository.java` | Spring `JdbcTemplate` calling vector search + SQL/PGQ + Select AI |
| `examples/spring/NudgeService.java` | OpenTelemetry-instrumented service layer |
| `examples/spring/OtelDataSourceConfig.java` | Wraps `DataSource` with `JdbcTelemetry` |
| `examples/spring/application.yml` | HikariCP `connection-init-sql` for `SET_PROFILE` |
| `examples/spring/pom-otel-snippet.xml` | OTel JDBC + Spring Boot starter deps |
| `examples/mcp/claude_desktop_config.json` | Working MCP client config for SQLcl `-mcp` |
| `mcp/tools/peer_products.sql` | Example SQLcl MCP named tool |

## Hands-on lab

| File | What it does |
|------|--------------|
| `docs/training/labs/00-LAB-README.md` | Lab overview + how to run |
| `docs/training/labs/lab_setup.sql` | Creates `lab_results` scoring table + asserter procs + prereq guard |
| `docs/training/labs/lab01_vectors.sql` | Module 1 self-checks |
| `docs/training/labs/lab02_graphs.sql` | Module 2 self-checks |
| `docs/training/labs/lab03_select_ai.sql` | Module 3 self-checks |
| `docs/training/labs/lab04_mcp.sql` | Module 4 self-checks |
| `docs/training/labs/lab05_e2e.sql` | Module 5 self-checks |
| `docs/training/labs/lab06_ops.sql` | Module 6 self-checks |
| `docs/training/labs/lab_report.sql` | Final pass/fail/manual scoreboard |

## How to use this track

1. Read modules 1→6 in order. Each one builds on the previous.
2. Run the corresponding SQL file in ADB while you read.
3. At the end, run the hands-on lab for self-grading PASS/FAIL/MANUAL.
4. Module 5 includes the production checklist; Module 6 the on-call checklist.

## Mental model — keep this in your head the whole time

> Oracle 26ai does **not** add a new database. It adds:
>   - one new **datatype** (`VECTOR`),
>   - one new **index kind** (vector ANN: HNSW / IVF),
>   - a couple of new **SQL operators** (`VECTOR_EMBEDDING`, `VECTOR_DISTANCE`),
>   - a **graph view layer** (SQL/PGQ) over existing tables,
>   - and two **PL/SQL packages** (`DBMS_VECTOR`, `DBMS_CLOUD_AI`) that wrap models and LLM providers.
>
> Everything else — transactions, RBAC, partitioning, backup, replication, RAC,
> Data Guard, AWR, SQL plan management — works exactly the way it already does.
