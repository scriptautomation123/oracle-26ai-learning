# Deep Dive: Oracle 26ai Proactive Banking Nudges — For a DBA New to AI

You already think in tables, indexes, optimizer stats, and execution plans. I'll map every AI concept here to something you already know, then explain *why* the design is shaped the way it is.

---

## 1. The Core Mental Shift: "AI" Is Just Three New Datatypes + Two New Operators

Forget the hype. In Oracle 26ai, everything in this POC reduces to:

| New thing | What it really is (DBA framing) |
|---|---|
| `VECTOR` column | A fixed-length `FLOAT` array (e.g., 384 or 768 dims) stored inline or out-of-line like a `BLOB`. |
| ONNX embedding model | A **stored function** loaded into the DB that takes `CLOB` → returns `VECTOR`. Think of it as a deterministic PL/SQL function that runs C++ under the hood. |
| Vector index (HNSW / IVF) | A **new index type**, like a B-tree or domain index, but optimized for "nearest neighbor" instead of equality/range. |
| `VECTOR_EMBEDDING(model USING text)` | New SQL operator. Converts text → vector at query time. |
| `VECTOR_DISTANCE(v1, v2, COSINE)` | New SQL operator. Returns a number; smaller = more semantically similar. |
| Property Graph (SQL/PGQ) | A **view-like overlay** on existing tables that lets you write `MATCH (a)-[:KNOWS]->(b)` instead of 4-table joins. No data is duplicated. |
| Select AI profile | A **DBMS package config** (`DBMS_CLOUD_AI`) that says "when someone calls `SELECT AI ...`, route the natural-language question to *this* LLM with *these* tables as context." |
| MCP server | A **listener** (think: like the SQL*Net listener) that exposes DB capabilities as "tools" an external LLM can call. |

That's it. Everything in the README is built from these primitives.

---

## 2. What an "Embedding" Actually Is (the one concept everything depends on)

An **embedding** is a vector of floats that represents the *meaning* of a piece of text. Texts with similar meaning produce vectors that are close together in N-dimensional space.

```
"my card was declined at the gas station"   →  [0.12, -0.44, 0.88, ..., 0.03]   (384 floats)
"transaction failed at the pump"            →  [0.14, -0.41, 0.85, ..., 0.05]   (very close)
"apply for a mortgage"                       →  [-0.71, 0.22, 0.10, ..., 0.66]  (far away)
```

**DBA analogy:** It's like a hash, but instead of collision-avoidance, similar inputs *intentionally* produce similar outputs. You then index those vectors and do "nearest-neighbor" lookups instead of "equality" lookups.

The **ONNX model** loaded by `sql/03_load_onnx_model.sql` is the function that produces these floats. It runs *in-process* inside the database — no callout, no network — so embedding 20,000 rows is basically a `CREATE TABLE ... AS SELECT VECTOR_EMBEDDING(...) FROM ...`.

---

## 3. Walking the Repo Top-to-Bottom (and *why* each step exists)

### `sql/01_schema.sql` — Plain old relational
Customers, accounts, transactions, applications, conversations. Nothing AI here. This is your system of record. **Design rationale:** AI features in 26ai *augment* relational; they don't replace it. You'll add a `VECTOR` column to `CONVERSATIONS` later, not a new database.

### `sql/02_staging_ddl.sql` — External tables / staging
Lands the Kaggle CSVs from OCI Object Storage. Standard ETL pattern (`DBMS_CLOUD.COPY_DATA`).

### `sql/03_load_onnx_model.sql` — Load the embedding model into the DB
Uses `DBMS_VECTOR.LOAD_ONNX_MODEL` to register an ONNX file (likely `all-MiniLM-L6-v2`, 384 dims) as a database object.

**Why in-DB?** Two reasons a DBA will appreciate:
1. **No data egress.** Embedding millions of CLOBs without sending them to an external API.
2. **It's just a function call.** `VECTOR_EMBEDDING(MY_MODEL USING txt AS data)` — usable in `SELECT`, `INSERT`, triggers, MVs.

### `sql/04_copy_data.sql` + `05_transform.sql` — Standard ELT
Moves staging → target, cleans columns. Boring. Good.

### `sql/06_embed_and_index.sql` — The first "AI" step
Two operations:

```sql
-- 1. Materialize embeddings
UPDATE conversations
SET    embedding = VECTOR_EMBEDDING(minilm_model USING transcript AS data);

-- 2. Build a vector index
CREATE VECTOR INDEX conv_hnsw_idx ON conversations(embedding)
ORGANIZATION INMEMORY NEIGHBOR GRAPH
DISTANCE COSINE
WITH TARGET ACCURACY 95;
```

**HNSW (Hierarchical Navigable Small World)** is a graph-based ANN index. DBA framing: like a B-tree it has logarithmic-ish lookup, but the "key comparison" is vector distance instead of `<`/`=`. The `TARGET ACCURACY 95` is your knob — it's the optimizer's analogue of "approximate vs exact." Vector indexes are *approximate* by design (it's how you get sub-ms search over millions of rows).

**Alternative:** `IVF` (inverted file, partition-based). Use IVF when the vector set is huge and disk-resident; HNSW when it fits in memory and you want lowest latency. For a 5k-row POC, HNSW in-memory is the right call.

### `sql/07_property_graph.sql` — The graph layer
This is where DBAs often get confused. **You are not loading data into a graph database.** You are creating a *graph view* over existing tables:

```sql
CREATE PROPERTY GRAPH banking_graph
  VERTEX TABLES (
    customers KEY (cust_id),
    products  KEY (prod_id),
    offers    KEY (offer_id)
  )
  EDGE TABLES (
    transactions
      SOURCE KEY (cust_id) REFERENCES customers
      DESTINATION KEY (prod_id) REFERENCES products
      LABEL viewed,
    ...
  );
```

Then you query with **SQL/PGQ** (ISO SQL 2023):

```sql
SELECT o.name
FROM   GRAPH_TABLE(banking_graph
         MATCH (c:customers)-[:viewed]->(p:products)<-[:viewed]-(c2:customers)-[:accepted]->(o:offers)
         WHERE  c.cust_id = :me
         COLUMNS (o.offer_name AS name))
GROUP BY o.name ORDER BY COUNT(*) DESC;
```

That's "people who looked at what I looked at also accepted these offers" — a 4-way self-join, written in 6 lines. The optimizer rewrites it to relational joins under the hood. **No new storage, no new backup strategy, no replication concern.** This is the killer point for a DBA.

### `sql/08_select_ai_profile.sql` — Natural language → SQL
`DBMS_CLOUD_AI.CREATE_PROFILE` registers a config: "the LLM is OCI GenAI / Llama / etc., the schema it can see is X, the prompt prefix is Y." After that:

```sql
SELECT AI 'who are my top 5 customers by deposits this quarter';
```

…is rewritten by the LLM into actual SQL against your tables, executed, and returned. **DBA caveats you should be ready for:**
- The LLM sees your **DDL + comments**, so column comments suddenly matter. Treat them as documentation contracts.
- Set up a **least-privileged proxy user** for the profile. The generated SQL runs as whoever invokes `SELECT AI`.
- Cache and audit. Every `SELECT AI` should be logged with the generated SQL for review.

### `sql/09–11_*.sql` — The three use cases
Each one is the **same recipe**:
1. Relational filter (narrow candidates) →
2. Graph traversal (find related entities) →
3. Vector search (rank by semantic similarity to live context) →
4. Return top-N with explanation.

This is **agentic RAG done in pure SQL**. The agent (LLM via MCP) doesn't compute anything; it just calls these views/procs as tools.

### `apex/nudge_chat_app.sql` — Front end
APEX page with a chat region. Calls the SQL above. Nothing exotic.

### `mcp/README.md` — How the LLM talks to the DB
SQLcl 24+ ships with `-mcp` mode. Run `sql -mcp` and it exposes the database connection as an MCP server. Claude Desktop / Copilot / a custom agent connects, lists "tools" (your stored procs and named queries), and invokes them as part of a conversation. **DBA framing:** it's like ODBC for LLMs — a standardized protocol so you don't write custom REST endpoints per agent.

---

## 4. Why the SQL Run Order Matters (Dependency Graph)

```
01_schema ──► 02_staging ──► 04_copy ──► 05_transform ──┐
                                                         ├──► 06_embed_and_index ──► 09/10/11_uc*
03_load_onnx_model ──────────────────────────────────────┤
                                                         └──► 07_property_graph ────► 09/10/11_uc*
                                                                                       08_select_ai_profile
```

Two parallel prerequisites converge at step 6 (you need both data *and* the model to embed). Step 7 only needs cleaned relational data. Step 8 is independent but should be last because the profile references the final tables.

---

## 5. Design Choices Worth Questioning

| Choice in repo | Why it's there | What you might push on |
|---|---|---|
| ONNX MiniLM (384-dim) in-DB | Free, fast, no egress | Try `bge-small-en` for better quality at same size; or OCI Cohere embed for top quality (costs $) |
| HNSW in-memory | Sub-ms latency on 5k–500k rows | Switch to IVF when conversation table grows past memory; consider `INMEMORY NEIGHBOR PARTITIONS` for hybrid |
| Property graph over base tables | Zero data duplication | If traversals get hot, materialize a denormalized edge table — same as you'd do for a slow report |
| Select AI profile uses one schema | Simple POC | In prod, create one profile per business domain with row-level security policies attached |
| 5k-row LendingClub trim | Fits Free Tier + fast iteration | Nothing about the design changes at 5M rows; only index choice and Smart Scan matter |
| MCP via SQLcl | Easiest path | For prod, run a dedicated MCP server process behind auth, not an interactive SQLcl |

---

## 6. The "Nudge" Pattern in One Picture

```
Trigger event  ────►  Relational lookup   "what just happened?"
(page view,            (customer, account, recent txns)
 abandoned app,                │
 declined txn)                 ▼
                       Graph traversal     "what's related & what worked before?"
                       (similar customers, offers that converted)
                                │
                                ▼
                       Vector search       "which past conversation/doc fits this context?"
                       (hybrid: filter + ANN)
                                │
                                ▼
                       LLM (via MCP)       "compose a one-sentence nudge using all of the above"
                                │
                                ▼
                       APEX chat UI        Banker sees: "Offer Sarah the Travel+ card —
                                            customers like her converted 38% after this nudge."
```

All three use cases (`uc1_card_view`, `uc2_abandoned_app`, `uc3_declined_txn`) are instances of this same flow with different trigger inputs and filters.

---

## 7. What to Read Next (concept → repo file)

- **Vector basics & `VECTOR_EMBEDDING` syntax** → walk through `sql/06_embed_and_index.sql` line by line
- **SQL/PGQ syntax (ISO 2023)** → `sql/07_property_graph.sql` and Oracle's "Graph Developer's Guide for Property Graph"
- **DBMS_CLOUD_AI / Select AI** → `sql/08_select_ai_profile.sql` and the `DBMS_CLOUD_AI` reference
- **MCP** → `mcp/README.md` and the SQLcl `-mcp` docs
- **Putting it together** → `docs/architecture.md` and `docs/demo-script.md`

---

**Bottom line for you as a DBA:** Nothing here asks you to operate a new database, a new index server, or a new vector store. It's all `CREATE INDEX`, `CREATE VIEW`, `CREATE FUNCTION`, and a couple of new SQL operators. The "AI" is a layer of *operators and indexes* on top of the converged database you already know how to back up, patch, monitor, and tune.