---
title: Proactive Banking Nudges on Oracle Database 26ai
subtitle: Principal Engineering Briefing
audience: Principal Engineers, Staff Engineers, DBAs, Platform Leads
---

---
## Slide 1 - Title

# Proactive Banking Nudges on Oracle 26ai
### Engineering Plan for Relational + Vector + Graph Workloads in One Operational Surface

Scope: web/app triggers, near-real-time decisions, explainable outbound nudges.

---
## Slide 2 - Why This Matters

We have a familiar systems problem, not an AI science project:

- Signals already exist in OLTP systems.
- Context is fragmented across transactions, applications, and conversation history.
- Customer outreach is late and generic because retrieval is slow or disconnected.

The opportunity is to make decisions in the event window, using existing data contracts and controls.

---
## Slide 3 - Target Moments

Three trigger classes for the pilot:

1. Credit card product page view (assist while intent is fresh)
2. Application abandonment (recover before intent decays)
3. Declined transaction (resolve quickly with a concrete next action)

Success condition: decision latency low enough to act before session/context is lost.

---
## Slide 4 - Current State and Gap

Current assets:

- Oracle relational core for accounts, transactions, and applications
- Conversation and content artifacts in CLOB/BLOB form
- Existing integration paths from web/mobile/core systems

Primary gap:

- No first-class semantic retrieval
- No graph traversal over existing relational entities
- No standard tool surface for conversational clients to call into live data

---
## Slide 5 - Design Principle

Keep the source of truth where it already is.

- Extend existing schema with vector columns and indexes.
- Expose graph semantics as overlays on relational tables.
- Execute mixed retrieval in one query path with ACID guarantees.

Goal: avoid adding separate vector and graph datastores unless there is a proven scale or autonomy requirement.

---
## Slide 6 - What Changes in the Data Model

| Existing Asset | Additions | Engineering Outcome |
|---|---|---|
| Customer/account/txn/application tables | No structural replacement | Preserve contracts with upstream systems |
| Conversation transcripts and offer content | Chunking + VECTOR columns | Semantic retrieval over unstructured text |
| Existing FK relationships | Property Graph definition (SQL/PGQ) | Path queries without ETL into a separate graph store |

Net: one platform supports row access patterns, nearest-neighbor lookup, and graph traversal.

---
## Slide 7 - Capability Mapping to Use Cases

- Vector search: find relevant prior conversations, policy text, and offer language
- Hybrid index: combine semantic rank with exact-match/business filters
- Property graph: discover related entities and prior successful paths
- Agent flow over tool calls: orchestrate multi-step retrieval, then render user-safe output

This is retrieval engineering with strict constraints, not open-ended generation.

---
## Slide 8 - Query Shape We Actually Need

Representative pattern:

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

Engineering point: precision comes from business filters; semantic ranking resolves tie-breaks within valid candidates.

---
## Slide 9 - Graph Overlay, Not Graph Migration

Use SQL/PGQ on existing tables to answer:

- Which offers converted for customers with similar recent behavior?
- Which paths from event to resolution have lowest fallout?
- Which related entities should be considered before selecting the nudge?

No second persistence model to operate, replicate, secure, or back up.

---
## Slide 10 - Trigger-to-Decision Pipeline

1. Event emitted by web/core banking systems
2. CDC stream ingested to Oracle target schema
3. Enrichment queries run (relational + graph + vector)
4. Decision object produced with explanation fields
5. Channel adapter delivers message in app/chat/agent console

Keep the decision object deterministic enough for audit replay.

---
## Slide 11 - Use Case 1: Card Page View

Input:

- Product page identifier
- Customer profile/eligibility context
- Recent account and conversation context

Decision output:

- Compare/suggest option with reason code
- Optional agent-assist prompt

Key metric: uplift over baseline generic suggestion for same page cohort.

---
## Slide 12 - Use Case 2: Abandoned Application

Input:

- Last completed step + field completion state
- Segment and channel history
- Similar historical abandonment/resolution traces

Decision output:

- Finish-now prompt vs objection-handling message vs assisted callback offer

Key metric: completion recovery rate within 24h and 7d windows.

---
## Slide 13 - Use Case 3: Declined Transaction

Input:

- Decline reason and limit history
- Merchant/category context
- Relevant policy/explanation text

Decision output:

- Explain decline + propose eligible next step (limit review, card alternative, fraud flow)

Key metric: resolution rate and reduction in support handoff for repeat decline events.

---
## Slide 14 - Latency and Scale Posture

Performance assumptions:

- Time-to-nudge target: less than 2 seconds end-to-end
- Retrieval target: sub-100ms for filtered nearest-neighbor paths at scale
- Throughput model: event bursts tied to traffic spikes and settlement cycles

Exadata Smart Scan for vectors is relevant when filtered ANN and large scans coexist.

---
## Slide 15 - Capacity Planning: Offers Embedding Footprint

How to estimate incremental storage before rollout:

1. Baseline formula per row:

  embedding_bytes ~= dims x 4 (FLOAT32)

2. Total raw embedding size:

  raw_total ~= offer_rows x embedding_bytes

3. Add operational overhead:

  - Row/LOB metadata and block overhead
  - Vector index structures (HNSW/IVF)
  - Segment growth from updates/rebuilds and safety headroom

For planning, start with:

- Data segment: 1.2x to 1.5x of raw_total
- Vector index: 0.5x to 1.5x of raw_total (depends on index type/params)
- Growth and maintenance headroom: +25% to +40%

Example (offers only):

- 2,000,000 offers x 384 dims x 4 bytes ~= 3.07 GB raw
- Planned data + index envelope often lands around 5.5 GB to 11 GB before headroom
- With 30% headroom: provision roughly 7 GB to 14.3 GB

Engineering guidance:

- Run a pilot load with production-like dimensions and index params.
- Measure actual segment size deltas after load and after index build.
- Re-measure after one re-embedding cycle to capture churn overhead.
- Lock model dimension early; changing 384 to 1024 dims is a linear storage jump.

Practical measurement loop:

```sql
-- 1) Dimension-driven raw estimate for offers table
SELECT COUNT(*) AS offer_rows,
       384 AS dims,
       COUNT(*) * 384 * 4 AS raw_embedding_bytes
FROM   offers;

-- 2) Segment usage before/after embedding + index build
SELECT segment_name,
       segment_type,
       ROUND(SUM(bytes)/1024/1024, 2) AS mb
FROM   user_segments
WHERE  segment_name IN (
  'OFFERS',
  'OFFERS_EMBED_IDX'  -- replace with actual vector index segment name
)
GROUP  BY segment_name, segment_type
ORDER  BY mb DESC;
```

Use the delta between before/after snapshots as the canonical number for capacity planning.

---
## Slide 16 - Operations and Controls

Treat this as a production data path:

- Row-level security and redaction on both source text and derived vector artifacts
- Full audit of retrieval inputs, selected candidates, and final decision payload
- Deterministic fallbacks when vector/graph paths degrade
- Cost and latency budgets on embedding generation and re-embedding workflows

If we cannot explain a nudge in one paragraph, we should not send it.

---
## Slide 17 - Reliability Model

Failure domains and fallback behavior:

- CDC lag: degrade to stale-but-safe profile view, suppress risky nudges
- Embedding/index lag: fall back to relational rules with conservative templates
- Graph query timeout: continue with relational + vector candidate set
- Channel delivery failure: persist decision envelope for retry/idempotent replay

Design for graceful degradation, not hard dependency chains.

---
## Slide 18 - Build Plan

Phase 1 (4-6 weeks): UC1 pilot

- VECTOR columns on conversations/offers
- Hybrid index and ranking query path
- MCP/tool integration to existing chat surface

Phase 2 (6-8 weeks): UC3

- CDC feed for declines
- Graph overlay for merchant/offer adjacency
- Decision policy hardening

Phase 3 (8-10 weeks): UC2

- Abandonment-state features
- Cross-use-case orchestration and tuning

---
## Slide 19 - Engineering Review Checklist

Before production rollout:

1. Explainability: decision payload includes ranked candidates and reason codes
2. Security: PII policy validated on transcript chunking and embeddings
3. SLOs: p50/p95/p99 for retrieval and end-to-end trigger handling
4. Operability: runbooks for lag, index rebuild, model rotation, and rollback
5. Testability: replay harness for historical events and deterministic comparisons

---
## Slide 20 - Decision to Proceed

Recommendation:

- Start with UC1 as the integration-light proving ground.
- Use converged capabilities first; do not split stores prematurely.
- Hold a design review after Phase 1 with measured latency, relevance, and ops findings.

Exit criterion for pilot: measurable business lift with no new operational tier.

---
## Slide 21 - Discussion

Open engineering questions:

- Embedding path: in-DB ONNX vs external managed model under our latency/cost envelope
- Graph strategy: live overlay only vs selective materialization for hot traversals
- MCP deployment: shared service vs domain-specific tool servers
- Governance: retention, redaction, and audit policy for vectorized customer text
