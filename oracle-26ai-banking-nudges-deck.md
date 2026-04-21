---
title: Proactive Banking Nudges on Oracle Database 26ai
subtitle: Converged Relational + Vector + Graph + Agentic AI
audience: Internal + Oracle Account Team
---

---
## Slide 1 — Title

# Proactive Banking Nudges on Oracle 26ai
### Converged Relational + Vector + Graph for Real-Time Customer Engagement

Online Banking | Marketing Offers | Conversational AI
Prepared for discussion with Oracle

---
## Slide 2 — The Business Problem

**We want to nudge customers in the moment, with context.**

Three target moments:
1. 🟦 **Browsing** a credit card page → offer help comparing/applying
2. 🟨 **Abandoned application** → re-engage where they dropped off
3. 🟥 **Declined transaction** → proactively explain & offer a path forward

Goal: make every chat / call / in-app message **personal, timely, and grounded in the customer's actual data**.

---
## Slide 3 — What We Have Today

- **Oracle Database 26ai** (relational core)
- Wide relational schema **+ BLOB columns** for:
  - Customer conversation transcripts
  - Marketing offers & insights content
- Existing systems of record for accounts, transactions, applications

**Gap:** no semantic search, no graph traversal, no agent layer to assemble context for a live conversation.

---
## Slide 4 — The Vision

> One database. Relational + Vector + Graph + Agentic AI in the same row, the same query, the same transaction.

No bolt-on vector DB. No separate graph DB. No fragile ETL.

**Augment** existing tables — don't replace them.

---
## Slide 5 — Data Model Evolution

| Existing | Add in 26ai | Purpose |
|---|---|---|
| Customer / Account / Txn / Application tables | — (stay as-is) | System of record |
| Conversation transcripts (BLOB/CLOB) | `VECTOR` column + chunk table | Semantic search over chats |
| Offers & product docs (BLOB) | `VECTOR` column | RAG retrieval |
| FK relationships across entities | **Property Graph (SQL/PGQ)** view | Traverse customer ↔ product ↔ offer |

→ Same table can hold **relational + JSON + BLOB + VECTOR**.

---
## Slide 6 — Oracle AI Features in Scope

1. **AI Vector Search** — embeddings & similarity in-DB
2. **Hybrid Vector Indexes** — vector + keyword + relational filters in one index
3. **Property Graph / SQL-PGQ** — graph queries over relational data
4. **Agentic RAG** — multi-step, tool-using retrieval agents
5. **MCP Server** — exposes the DB as tools to any LLM/agent
6. **GoldenGate 23ai Distributed AI** — streaming CDC + embeddings across regions
7. **Exadata Smart Scan for Vectors** — vector distance pushed to storage

---
## Slide 7 — Feature: AI Vector Search

**What:** `VECTOR` datatype, `VECTOR_EMBEDDING()`, `VECTOR_DISTANCE()` — all native SQL.

**For us:**
- Embed conversation chunks → find similar past chats
- Embed product pages & offers → match to live browsing context
- Embed knowledge-base articles → ground LLM answers

**Why it matters:** no data movement, no separate vector store, transactional consistency with relational data.

---
## Slide 8 — Feature: Hybrid Vector Indexes (NEW in 26ai)

**What:** combines **vector similarity + keyword (BM25) + relational predicates** in a single index/query.

**Why critical for banking:**
- Pure semantic search loses precision on product names, account #s, regulatory terms
- We must filter by segment, region, eligibility before ranking

**Example:**
```sql
WHERE customer_segment = 'Prime'
  AND product_family   = 'Credit Card'
  AND VECTOR_DISTANCE(page_vec, :viewed_page_vec) < 0.2
```
One query. One index. Filtered ANN.

---
## Slide 9 — Feature: Property Graph (SQL/PGQ)

**What:** query existing relational tables as a graph using SQL/PGQ — no separate graph DB.

**Model:**
```
Customer —[VIEWED]→ Product
Customer —[STARTED]→ Application
Customer —[HAD]→ DeclinedTxn
Offer    —[TARGETS]→ Segment
```

**Use:**
- "Customers who viewed *this* card AND have checking > $X → which offer converted best?"
- Graph **narrows candidates**, vector **ranks semantically**.

---
## Slide 10 — Feature: Agentic RAG

**What:** an agent **plans multi-step retrieval** instead of single-shot RAG.

**For UC3 (declined txn):**
1. Look up the declined txn (SQL)
2. Check limit history & spending pattern (SQL)
3. Retrieve policy doc (vector)
4. Find similar past resolutions (vector + graph)
5. Decide: explain limit / offer increase / fraud check
6. Compose the nudge

**Why:** real banking decisions need *reasoning over multiple sources*, not one similarity hit.

---
## Slide 11 — Feature: MCP Server

**What:** Oracle ships an **MCP (Model Context Protocol) server** that exposes the database as tools to any MCP-compatible LLM (Claude, Copilot, LangChain, custom).

**For us:**
- Front-end chat/voice agent calls tools like:
  - `get_recent_account_events(customer_id)`
  - `find_similar_conversations(text)`
  - `traverse_offer_graph(customer_id)`
- No need to build/maintain a custom API layer per tool

**Win:** drastically shorter path from "LLM idea" to "production tool call."

---
## Slide 12 — Feature: GoldenGate 23ai Distributed AI

**What:** real-time CDC across regions / on-prem ↔ OCI, with **vector replication** and **in-pipeline embedding generation**.

**For us:**
- UC1 page-view & UC3 declined-txn events originate in OLTP systems → GG streams them to the AI DB in seconds
- New conversation transcripts are auto-embedded as they land
- Multi-region active-active with vector conflict resolution

**Win:** nudges fire **within seconds** of the trigger.

---
## Slide 13 — Feature: Exadata Smart Scan for Vectors

**What:** vector distance + filter pushed **down into Exadata storage cells**, in parallel, on columnar/HCC data.

**For us:**
- 3 nudges × millions of customers × sub-second SLA
- Hybrid query (`WHERE segment=… AND VECTOR_DISTANCE(...)`) scans billions of rows without pulling to compute nodes

**Win:** sub-100ms hybrid queries at full customer scale.

---
## Slide 14 — Use Case 1: Credit Card Browsing

**Trigger:** user lands on a credit card product page.

**Flow:**
```
Page-view event ──GoldenGate──► 26ai
                                   │
                          Agentic RAG (via MCP)
                          ├─ SQL: profile, recent txns
                          ├─ PGQ: similar viewers, top-converting offers
                          └─ Hybrid Vector: page semantics + filters
                                   │
                                   ▼
"I see you were just looking at the Cash+ Visa —
 want me to compare it to the Travel Rewards card
 you applied for last month?"
```

---
## Slide 15 — Use Case 2: Abandoned Application

**Trigger:** application started, fields populated, never submitted.

**How features combine:**
- **Relational:** which fields were filled / which were not
- **Vector:** find prior conversations where similar customers abandoned — what objection patterns?
- **Graph:** what nudge unblocked customers with the same drop-off pattern?
- **Agentic RAG:** decides between "offer help finishing," "address likely objection," or "schedule a call"

**Result:** highly specific re-engagement, not a generic reminder.

---
## Slide 16 — Use Case 3: Declined Transaction

**Trigger:** transaction declined because daily limit reached.

**How features combine:**
- **Relational:** the declined txn, limit history
- **Graph:** linked merchant category → eligible offers (limit increase, premium card)
- **Vector:** retrieve right policy / explanation copy
- **Agentic RAG:** reasons over all three to choose the next best action
- **Exadata Smart Scan:** keeps it under SLA at scale

**Nudge:** *"I noticed a recent declined transaction. Want to review your limit options?"*

---
## Slide 17 — End-to-End Reference Architecture

```
┌────────────────────┐    CDC + embeddings    ┌──────────────────────────┐
│  OLTP / Web / Core │ ─────GoldenGate─────► │   Oracle Database 26ai    │
│  banking systems   │                        │ ───────────────────────── │
└────────────────────┘                        │ Relational + JSON + BLOB  │
                                              │ + VECTOR (Hybrid Index)   │
┌────────────────────┐                        │ + Property Graph (PGQ)    │
│  Chat / IVR / App  │ ◄──── MCP tools ────► │ + Agentic RAG              │
│  LLM front-end     │                        │ on Exadata (Smart Scan)   │
└────────────────────┘                        └──────────────────────────┘
```

One DB. Multiple AI modalities. Same transaction boundary.

---
## Slide 18 — Why Converged > Best-of-Breed

| Concern | Best-of-breed stack | Oracle 26ai converged |
|---|---|---|
| Data movement | ETL to vector DB + graph DB | None — same row |
| Consistency | Eventual, app-managed | ACID across vector + relational |
| Security / PII | Multiple perimeters | One — VPD, redaction, audit |
| Latency | Network hops between stores | Single SQL, Smart Scan |
| Ops | 3–4 systems to run | 1 |
| Skills | New stacks | SQL + PL/SQL the team knows |

---
## Slide 19 — Phased Rollout

**Phase 1 (4–6 wks):** Pilot UC1
- Add VECTOR cols to product/conversation tables
- Stand up Hybrid Vector Index
- MCP server → existing chat front-end

**Phase 2 (6–8 wks):** UC3
- GoldenGate stream of declined-txn events
- Property Graph view + agentic RAG flow

**Phase 3 (8–10 wks):** UC2
- Application abandonment patterns
- Multi-region GG, Exadata Smart Scan tuning

**Phase 4:** expand to additional triggers, A/B test offers.

---
## Slide 20 — Asks for Oracle

1. **Schema design** for VECTOR columns on wide relational + BLOB tables
2. **Hybrid Vector Index** — sizing, distance metrics, filter pushdown
3. **SQL/PGQ** — querying FK graph directly vs. materialized
4. **Agentic RAG + MCP** reference architecture for chat / IVR
5. **GoldenGate 23ai** — pattern for CDC + auto-embedding
6. **Exadata Smart Scan for vectors** — required SW/HW level, observed latency
7. **Governance** — row-level security, redaction, audit on vector data (PII / banking)
8. **Embedding models** — in-DB ONNX vs. OCI Generative AI (cost/latency)

---
## Slide 21 — Success Metrics

- ⏱ **Time-to-nudge:** < 2s from trigger event
- 🎯 **Click-through on nudge:** +X% vs. generic message
- 💬 **Chat containment / deflection:** +X%
- 📝 **Application completion rate** post-nudge: +X%
- 💳 **Limit-increase acceptance** post-decline: +X%
- 🛠 **Engineering velocity:** new use case live in < 4 weeks (no new datastore)

---
## Slide 22 — Summary

- **One converged DB** holds relational, BLOB, vector, and graph
- **Hybrid Vector Index + PGQ + Smart Scan** = fast, filtered, contextual retrieval at scale
- **Agentic RAG over MCP** = real reasoning, plug-and-play with our chat/voice front-end
- **GoldenGate 23ai** = real-time triggers and always-fresh embeddings
- All three nudge use cases are achievable on **Oracle 26ai with no new datastores**

> **Next step:** working session with Oracle to validate architecture and scope Phase 1 pilot.

---
## Slide 23 — Q&A / Discussion

**Open questions for the room:**
- Which use case do we pilot first? (Recommend UC1 — lowest integration risk)
- Embedding model choice: in-DB ONNX vs. OCI GenAI?
- Where does the conversational front-end live today, and is it MCP-ready?
- What is our PII redaction policy for transcripts before embedding?