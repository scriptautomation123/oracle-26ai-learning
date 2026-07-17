# Oracle 26ai Banking Nudges — Self-Contained Training Notebook Plan

## Goal

Produce a single Jupyter notebook that replaces the entire `26ai-banking-demo` folder as the primary artifact. The notebook must teach the full demo, run the full demo, and explain the concepts, architecture, and operational considerations. It should inline every script and SQL statement that is reasonable to run from Python, and only externalize large assets that truly belong outside (raw dataset downloaders, APEX application export, Spring code examples). A reader who opens only this notebook should be able to understand the business problem, provision or connect to an Oracle 26ai database, load data, build the vector/graph/select-ai layers, run UC1/UC2/UC3, and extend the work.

## Target Audience

Technical practitioners who need to learn and deliver the demo: staff engineers, DBAs, platform leads, solution architects, and data engineers. The tone is precise, practical, and opinionated. No unnecessary marketing language. No references to "principal engineer" or similar role labels.

## Scope Boundaries

- In scope: relational schema, staging data loaders, ONNX embedding model load, vector indexes, property graph, Select AI profile, the three nudge use cases, MCP configuration, APEX API, operational notes, cost guardrails, and extension guidance.
- Externalized: raw dataset download scripts (Kaggle/OCI), APEX application export file, Spring/Java example code, and the MCP server binary (SQLcl) installation. These are referenced with exact paths and instructions, not duplicated.

## Required Reading to Synthesize

- `26ai-banking-demo/README.md` for the quick start, run order, and build plan.
- `26ai-banking-demo/docs/architecture.md` for the data flow diagram.
- `26ai-banking-demo/docs/demo-script.md` for the 10–15 minute demo steps.
- `26ai-banking-demo/docs/dataset-licenses.md` for compliance notes.
- All files under `26ai-banking-demo/sql/01_schema.sql` through `11_uc3_declined_txn.sql`.
- All files under `26ai-banking-demo/scripts/`.
- `26ai-banking-demo/mcp/README.md`, `mcp/tools/peer_products.sql`, and `examples/mcp/claude_desktop_config.json`.
- `26ai-banking-demo/apex/nudge_chat_app.sql`.
- `26ai-banking-demo/examples/spring/*.java`, `application.yml`, and `pom-otel-snippet.xml`.
- The three markdown decks: `oracle-26ai-banking-nudges-deck.md`, `oracle-26ai-deep-dive-for-dbas.md`, `oracle-26ai-principal-engineering-deck.md`.
- Existing notebooks: `onnx_embeddings_oracle_ai_database.ipynb` and `oracle_26ai_unique_features_demo.ipynb` for Oracle connection, ONNX load, vector search, and LangChain integration patterns.

## Notebook Structure

### Cell 1 — Title and Why This Exists

A concise title and a short paragraph stating that this notebook is a self-contained training and runnable demo for proactive banking nudges on Oracle Database 26ai. Mention that it replaces the need to open multiple docs and SQL files, while still pointing to external scripts only for dataset acquisition and APEX/Spring artifacts.

### Cell 2 — What You Will Learn

A bulleted list of capabilities the reader will understand by the end:
- How Oracle 26ai unifies relational, vector, graph, and AI in one database.
- How to load and use an ONNX embedding model inside Oracle.
- How to build a property graph overlay on existing relational tables.
- How to configure Select AI for natural-language SQL generation.
- How to wire the database to an MCP-compatible agent and to an APEX chat UI.
- How to implement three real-time nudge use cases.
- Operational considerations: latency, capacity, security, and graceful degradation.

### Cell 3 — The Business Problem and Target Moments

Explain the three trigger classes from the banking-nudges deck:
1. Credit card product page view — assist while intent is fresh.
2. Application abandonment — recover before intent decays.
3. Declined transaction — resolve quickly with a concrete next action.

State the success condition: decision latency low enough to act before the session or context is lost.

### Cell 4 — Core Design Principle

One operational surface. Keep the source of truth where it already is. Extend existing schema with vector columns and graph overlays, avoid separate vector and graph stores unless proven scale or autonomy requires it, and execute mixed retrieval in one query path with ACID guarantees.

### Cell 5 — The "AI" Is Just New Datatypes and Operators

Use the DBA-framing from the deep-dive deck:
- `VECTOR` column = fixed-length FLOAT array.
- ONNX model = stored function loaded into the DB.
- Vector index = new index type for nearest neighbor.
- `VECTOR_EMBEDDING(... USING ... AS DATA)` and `VECTOR_DISTANCE(..., ..., COSINE)` = new SQL operators.
- Property Graph = view-like overlay on relational tables.
- Select AI profile = DBMS package config.
- MCP server = listener exposing DB tools to an LLM.

### Cell 6 — Architecture Diagram

Include a mermaid flowchart matching `architecture.md`:
- Datasets → Scripts → OCI Object Storage → DBMS_CLOUD.COPY_DATA → Staging → Transform → Core tables.
- Core tables branch to Vector, Graph, and Select AI.
- APEX and MCP connect back to Core.

### Cell 7 — Environment Prerequisites

List exactly what must exist before running the notebook:
- Python 3.10+, `oracledb`, `pandas`, `numpy`, `python-dotenv`, and optionally `langchain-oracledb`.
- Oracle Database 26ai (local Docker, ADB Free Tier, or ADB-S / dedicated).
- For ADB: wallet directory and `TNS_ADMIN` set.
- For model download: container runtime (`docker` or `podman`) if running local Oracle, or `DBMS_CLOUD.GET_OBJECT` if using ADB.
- For Select AI: an OCI GenAI credential (`OCI_GENAI_CRED`) configured in the database.
- For MCP: SQLcl 24+ installed.
- For dataset ingestion: Kaggle API key and optionally OCI CLI for uploads.

Provide a `.env` template:
```
ORACLE_USER=testuser
ORACLE_PASSWORD=TestPass123
ORACLE_DSN=localhost:1521/FREEPDB1
ORACLE_MODEL_NAME=MINILM_EMB
ORACLE_ONNX_FILE=all_MiniLM_L12_v2.onnx
ORACLE_DIRECTORY_NAME=ONNX_DIR
BANKING_DEMO_ROOT=/workspaces/oracle-26ai-learning/26ai-banking-demo
TNS_ADMIN=/path/to/wallet
```

### Cell 8 — Install Python Dependencies

A code cell that runs:
```python
import subprocess, sys
subprocess.run([sys.executable, '-m', 'pip', 'install', '-q',
                'oracledb', 'pandas', 'numpy', 'python-dotenv',
                'langchain', 'langchain-core', 'langchain-oracledb'],
               check=False)
```

### Cell 9 — Connect to Oracle

A code cell that loads `.env`, builds the connection, defines a `run_sql(sql, params, fetch)` helper, and prints the resolved DSN and Oracle version. Include a clear warning if defaults are used.

### Cell 10 — Download and Stage Public Datasets

Explain that the repo provides scripts for this because Kaggle credentials and large downloads belong outside the notebook. Provide the exact commands:
```bash
./26ai-banking-demo/scripts/00_setup_kaggle.sh
./26ai-banking-demo/scripts/01_download_all.sh
python3 26ai-banking-demo/scripts/02_trim_lending.py \
  --input 26ai-banking-demo/data/raw/lendingclub/accepted_2007_to_2018Q4.csv \
  --output 26ai-banking-demo/data/processed/lendingclub_5k.csv
python3 26ai-banking-demo/scripts/03_gen_conversations.py \
  --input 26ai-banking-demo/data/raw/banking77/banking77.csv \
  --output 26ai-banking-demo/data/processed/banking77_conversations.csv
```

Then add a Python helper cell that verifies the expected files exist and reports row counts for the trimmed datasets.

### Cell 11 — Upload to OCI Object Storage (Optional)

Explain that for ADB you must upload the processed CSVs to an OCI bucket and provide the command from `04_upload_to_oci.sh`:
```bash
OCI_NAMESPACE=<ns> OCI_BUCKET_NAME=<bucket> ./26ai-banking-demo/scripts/04_upload_to_oci.sh
```
For local Docker Oracle, explain that you can skip this and instead load via external table or direct `pandas` inserts shown later.

### Cell 12 — Schema Creation

Inline the full `01_schema.sql` as a runnable Python string and execute it. After execution, print the list of created tables. Explain each table's role in one sentence.

### Cell 13 — Staging DDL

Inline the full `02_staging_ddl.sql` and execute it. Explain that staging tables land raw CSV data before normalization.

### Cell 14 — Load the ONNX Embedding Model

Provide two paths:

Path A (local Docker Oracle): download the augmented ONNX model and copy it into the container, then load via `DBMS_VECTOR.LOAD_ONNX_MODEL`. Reuse the logic from `onnx_embeddings_oracle_ai_database.ipynb`, adapted to `all_MiniLM_L6_v2.onnx` or `L12_v2` as appropriate.

Path B (Oracle ADB / cloud): use `DBMS_CLOUD.GET_OBJECT` to pull the model into `DATA_PUMP_DIR` and then load it. Inline the exact SQL from `03_load_onnx_model.sql` and note the `credential_name => NULL` caveat.

Verify the model is registered by querying `USER_MINING_MODELS`.

### Cell 15 — Copy Staging Data from Object Storage

Inline `04_copy_data.sql` with explicit placeholders for `credential_name`, `username`, `password`, and the four `file_uri_list` values. Provide instructions for filling them in. If running local Oracle without object storage, provide an alternative code path that uses `pandas.read_csv` and `cursor.executemany` to populate the staging tables directly.

### Cell 16 — Transform Staging to Core Tables

Inline the full `05_transform.sql` and execute it. After running, print row counts for `customer`, `account`, `txn`, `application`, `conversation`, `page_event`, `product`, and `offer`. Explain how PaySim drives transactions, LendingClub drives applications, and Banking77 drives conversations.

### Cell 17 — Create Conversation Embeddings and Vector Index

Inline `06_embed_and_index.sql` and execute it. Explain:
- Why embeddings are generated inside Oracle (`VECTOR_EMBEDDING`).
- Why the chunk size is capped at 3500 characters.
- Why `ORGANIZATION NEIGHBOR PARTITIONS` with `TARGET ACCURACY 90` was chosen for this scale.

After execution, print the row count in `conversation_chunk` and confirm the index exists.

### Cell 18 — Create the Property Graph

Inline `07_property_graph.sql` and execute it. Explain that no data is duplicated: the graph is a SQL/PGQ overlay on `customer`, `product`, `account`, `page_event`, and `application`. Show a simple `GRAPH_TABLE` sanity query.

### Cell 19 — Create and Activate Select AI Profile

Inline `08_select_ai_profile.sql` with placeholders for `credential_name` and model. Execute it if the credential exists; otherwise show a clear fallback message. Explain what `object_list` does and why column comments matter for generated SQL.

### Cell 20 — Demo Script Step: Sanity Checks

Run the exact sanity checks from `demo-script.md`:
- Row counts across core tables.
- Vector retrieval sanity check ordering by `VECTOR_DISTANCE`.

Display results as DataFrames.

### Cell 21 — Use Case 1: Card Page View

Teach the concept first: a customer views a card product; the system finds peer products via graph traversal and ranks relevant conversation snippets via vector similarity. Then execute `09_uc1_card_view.sql` with a bind variable for `customer_id`. Show the result. Add a short interpretation cell explaining what each column means.

### Cell 22 — Use Case 2: Abandoned Application

Teach the concept: applications in `STARTED` status older than one hour are matched to similar past conversation snippets to craft a recovery nudge. Execute `10_uc2_abandoned_app.sql`. Show and interpret results.

### Cell 23 — Use Case 3: Declined Transaction

Teach the concept: a declined transaction triggers Select AI to generate an explainable, policy-safe nudge. Execute `11_uc3_declined_txn.sql` with a richer prompt that includes the actual decline reason and customer context. Wrap in a try/except so the notebook does not fail if Select AI is not configured.

### Cell 24 — APEX Integration

Explain that the APEX application export lives at `26ai-banking-demo/apex/nudge_chat_app.sql` and should be imported into APEX. Then inline the PL/SQL package `nudge_chat_api` as a runnable code cell so the same logic is available from the notebook. Explain how an APEX page process would call `nudge_chat_api.get_nudge('UC1', 1001)`.

### Cell 25 — MCP Integration

Explain MCP as the standard protocol that lets an LLM call database tools. Inline the JSON from `claude_desktop_config.json`. Inline the `peer_products.sql` tool definition. Show example natural-language prompts an agent could run. Note that SQLcl must be installed separately.

### Cell 26 — Spring Integration (Reference Only)

Summarize the Spring example: `application.yml` configures the datasource and sets the Select AI profile on connection; `NudgeRepository.java` runs UC1/UC2/UC3; `NudgeService.java` adds OpenTelemetry spans; `OtelDataSourceConfig.java` instruments the datasource. State that these files are kept in `26ai-banking-demo/examples/spring/` for production wiring and do not need to run inside the notebook.

### Cell 27 — Capacity Planning

Pull in the embedding footprint formula from the principal-engineering deck:
- `embedding_bytes ~= dims x 4`.
- Data segment 1.2x–1.5x raw, vector index 0.5x–1.5x raw, plus 25–40% headroom.
- Provide the example for 2M offers x 384 dims.
- Include the SQL measurement loop for before/after segment snapshots.

### Cell 28 — Operations, Security, and Reliability

Summarize the operations and reliability model from the principal-engineering deck:
- Row-level security and redaction on source text and vectors.
- Audit retrieval inputs, candidates, and decision payloads.
- Deterministic fallbacks when vector/graph paths degrade.
- Failure domains: CDC lag, embedding/index lag, graph timeout, channel delivery failure.
- Graceful degradation paths for each.

### Cell 29 — Build Plan and Review Checklist

Inline the 5-day build plan from the README and the production rollout checklist from the principal-engineering deck: explainability, security, SLOs, operability, testability.

### Cell 30 — Cleanup

Provide a guarded cleanup cell that drops the demo tables, indexes, graph, and optionally the ONNX model. Default the guard to `False` so it is safe to re-run.

### Cell 31 — Summary and Next Steps

Recap what the notebook demonstrated and list clear next actions:
- Run against a real ADB Free Tier instance.
- Replace the synthetic data pipeline with GoldenGate CDC.
- Add hybrid vector indexes when the corpus grows.
- Tune index accuracy/latency for production load.
- Conduct the engineering review checklist before rollout.

## Implementation Notes

- All SQL that runs inside Oracle must be executable from Python via `oracledb`. Use bind variables where the original SQL uses `:cid`.
- The notebook must not fail if optional capabilities are missing. Wrap Select AI, object-storage copy, and model-download cells in try/except with clear fallback messages.
- Use pandas DataFrames for query results so the output is readable.
- Keep markdown cells short and scannable. No walls of text.
- Use exact file paths from the repo when referencing external scripts.
- Avoid duplicating the APEX export and Java code; reference them.
- Do not include the words "principal engineer" anywhere in the notebook.

## External Assets to Keep in the Repo

- `26ai-banking-demo/scripts/00_setup_kaggle.sh`
- `26ai-banking-demo/scripts/01_download_all.sh`
- `26ai-banking-demo/scripts/02_trim_lending.py`
- `26ai-banking-demo/scripts/03_gen_conversations.py`
- `26ai-banking-demo/scripts/04_upload_to_oci.sh`
- `26ai-banking-demo/apex/nudge_chat_app.sql`
- `26ai-banking-demo/examples/spring/*`
- `26ai-banking-demo/examples/mcp/claude_desktop_config.json`
- `26ai-banking-demo/mcp/tools/peer_products.sql`

These are referenced, not duplicated, because they are large binaries, Kaggle-specific, APEX-specific, Java-specific, or MCP-server-configuration-specific.

## Deliverable

A single notebook file at `juoyter-notebooks/oracle_26ai_banking_nudges_training.ipynb` that contains all of the above and can be opened and run from top to bottom in a fresh environment with only Oracle credentials and optionally Kaggle credentials.
