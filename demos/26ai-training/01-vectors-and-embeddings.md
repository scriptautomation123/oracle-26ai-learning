# Module 1 — Vectors, Embeddings, and ANN Indexes (for the Offers Team)

> **Regulatory regimes that shape this module:** GLBA (NPI in transcripts),
> SR 11-7 / OCC 2011-12 (the embedding model is a model), Reg B / ECOA
> (no protected-class proxies leaking via similarity), records management
> (embeddings derived from NPI inherit NPI status), GDPR/CCPA (right to
> erasure must propagate to embeddings).

## What this module is actually about

The offers team already knows how to score eligibility from structured columns
(`segment`, `daily_limit`, `loan_amnt`, `loan_status`). What's new is using
**unstructured signal** — the chat transcripts in `CONVERSATION.transcript` —
to find customers who *talk* like they want a Personal Loan or who *complained*
about a declined transaction, and to retrieve the most-relevant past
resolution snippet to ground a generated nudge.

That capability is what `VECTOR(384, FLOAT32)` and `VECTOR_DISTANCE` give you.
Everything else in this module follows from "we just turned a CLOB into a
typed column we can index and join."

## The two demo files this module anchors to

- `26ai-banking-demo/sql/03_load_onnx_model.sql` — registers `MINILM_EMB`
  via `DBMS_VECTOR.LOAD_ONNX_MODEL`. **This is a model-risk artifact.**
- `26ai-banking-demo/sql/06_embed_and_index.sql` — populates
  `CONVERSATION_CHUNK.embedding` and creates `CONV_CHUNK_IDX` as
  `ORGANIZATION NEIGHBOR PARTITIONS DISTANCE COSINE WITH TARGET ACCURACY 90`.

Open both in another tab.

## Mental translation for the offers stack

| AI concept | Equivalent in your existing stack |
|---|---|
| Embedding model (`MINILM_EMB`) | A deterministic feature extractor — like a hashing function the campaign engine already uses for look-alike audiences, but emitting a 384-dim float vector instead of a hash |
| `VECTOR(384, FLOAT32)` column | A strongly typed feature column. It is **derived NPI** — same controls as the source `transcript` |
| ANN index (IVF / HNSW) | A new access path, like a B-tree but for distance. Tunable recall/latency, not exact |
| Cosine distance | "How close are these two pieces of customer language?" Used the same way you use a similarity score in a propensity model |
| Top-K vector retrieval | Candidate generation — feeds the eligibility/decision step, does **not** replace it |

## Walkthrough — `sql/03_load_onnx_model.sql`

```text
DBMS_CLOUD.GET_OBJECT      → downloads ONNX into DATA_PUMP_DIR
DBMS_VECTOR.LOAD_ONNX_MODEL → registers alias MINILM_EMB
JSON mapping               → maps ONNX tensor names to SQL call semantics
```

Operationally: **treat `MINILM_EMB` like any other production model.**

- It goes in the **bank's model inventory** under SR 11-7. It needs an owner,
  a version, a validation report, an intended-use statement, and documented
  limitations. "It's just open-source MiniLM" is not a defense — the moment
  it scores customer language, it is a model in use.
- The model file is a **deployment artifact**: same change control as a
  PL/SQL package. Hash it, sign it, version it, store it next to your DDL.
- Loading the model in-database (as opposed to calling out to a third-party
  embedding API) is a **GLBA-driven design choice**: the transcript bytes
  never leave the ADB perimeter, so no third-party data-sharing contract
  is needed for the embedding step itself. Document this in the data-flow
  inventory you already maintain for NYDFS 500.

## Walkthrough — `sql/06_embed_and_index.sql`

```sql
INSERT INTO conversation_chunk (conv_id, chunk_text, embedding)
SELECT c.conv_id,
       SUBSTR(c.transcript, 1, 3500),
       VECTOR_EMBEDDING(MINILM_EMB USING SUBSTR(c.transcript, 1, 3500) AS DATA)
FROM conversation c;

CREATE VECTOR INDEX conv_chunk_idx
ON conversation_chunk(embedding)
ORGANIZATION NEIGHBOR PARTITIONS
DISTANCE COSINE
WITH TARGET ACCURACY 90;
```

Things a principal engineer flags in code review of this file:

1. **The 3500-character truncation is a silent control.** Document it in the
   data dictionary. Anything beyond 3500 chars is dropped from the AI
   surface — a customer's later sentences won't match. That has UDAAP
   implications if a customer later says "I told you I couldn't afford it"
   and that sentence sat at character 4000.
2. **`chunk_text` duplicates content from `conversation.transcript`.** That
   is a second copy of NPI. It must inherit:
   - the same encryption (TDE on the tablespace),
   - the same retention schedule,
   - the same legal-hold mechanism,
   - the same right-to-erasure propagation (Module 6 covers the cascade).
3. **`TARGET ACCURACY 90` is a recall floor, not a guarantee.** Pair every
   release with a canary recall measurement (Module 6).
4. **No `WHERE` filter on the embed step.** Every conversation, including
   ones for customers who later opted out of personalization, gets embedded.
   Either gate the insert on `customer.personalization_opt_in = 'Y'` or
   accept that the suppression check has to happen at retrieval time
   (Module 4 enforces it at the MCP tool layer).

## HNSW vs IVF — the offers-team decision

Oracle 26ai gives you two organizations:

- IVF-style: `ORGANIZATION NEIGHBOR PARTITIONS` (what the demo uses)
- HNSW-style: `ORGANIZATION INMEMORY NEIGHBOR GRAPH`

Decision rubric for an offers workload:

| Dimension | IVF | HNSW |
|---|---|---|
| Memory footprint | Lower | Higher (in-memory graph) |
| Best for | Filtered top-K (e.g. "for *this customer's* segment, top-5 chunks") | Tight-latency, larger top-K, less filtering |
| UC1/UC2 fit (always filtered by `customer_id` / `product_id`) | Good default | Often overkill |
| UC3 fit (declined-txn, very low latency) | Good with right partition count | Better if recall@1 matters |

The demo picks IVF. That's the right starting point. Revisit only when you
have measured p95 latency under representative load (Module 6 lab).

## Hybrid retrieval — the only pattern you should ship

**Never** issue a pure vector query against the whole corpus. Always narrow
with relational predicates first. This is both a performance rule and a
fair-lending rule (you don't want a vector ANN to silently surface
protected-class-correlated language as "similar"):

```sql
SELECT cc.chunk_id,
       cc.chunk_text,
       VECTOR_DISTANCE(
         cc.embedding,
         VECTOR_EMBEDDING(MINILM_EMB USING :query_text AS DATA),
         COSINE
       ) AS distance
FROM conversation_chunk cc
JOIN conversation c ON c.conv_id = cc.conv_id
JOIN customer cu     ON cu.customer_id = c.customer_id
WHERE cu.segment = :segment              -- relational narrowing
  AND cu.personalization_opt_in = 'Y'    -- consent gate
  AND NOT EXISTS (                       -- suppression-list gate
    SELECT 1 FROM offer_suppression s
    WHERE s.customer_id = cu.customer_id
  )
ORDER BY distance
FETCH FIRST :k ROWS ONLY;
```

Two of those four predicates (`personalization_opt_in`, `offer_suppression`)
are not yet in the demo schema. They are added in Module 4 as part of the
agent hardening. The training assumes you will add them — they are not
optional in a real bank.

## Spring `JdbcTemplate` snippet

```java
String sql = """
    SELECT cc.chunk_id, cc.chunk_text,
           VECTOR_DISTANCE(
             cc.embedding,
             VECTOR_EMBEDDING(MINILM_EMB USING ? AS DATA),
             COSINE
           ) AS distance
    FROM conversation_chunk cc
    JOIN conversation c ON c.conv_id = cc.conv_id
    JOIN customer cu     ON cu.customer_id = c.customer_id
    WHERE cu.segment = ?
      AND cu.personalization_opt_in = 'Y'
    ORDER BY distance
    FETCH FIRST ? ROWS ONLY
    """;

return jdbcTemplate.query(sql, (rs, i) -> new ChunkHit(
        rs.getLong("chunk_id"),
        rs.getString("chunk_text"),
        rs.getDouble("distance")
    ),
    promptText, segment, topK
);
```

The prompt text (`promptText`) is the *eligibility query intent*, not the
generated nudge. Keep them separate — the eligibility intent goes in the
audit log; the generated nudge text is logged separately by Module 3's
`AI_CALL_LOG`.

## Fair-lending and PII guardrails specific to embeddings

- **Never embed PII you don't need.** The transcript may contain SSN, DOB,
  account number, PAN. Tokenize/redact *before* the embed step. Treat any
  raw PII appearing in `chunk_text` as an incident.
- **Never use the embedding distance as a feature in a credit decision** for
  Personal Loan eligibility (`OFFER` row 2). It is opaque to FCRA
  adverse-action reasoning; you cannot derive specific reasons from a 384-d
  vector. Vectors are fine for *content retrieval*, not for the eligibility
  yes/no on credit products.
- **Periodic disparate-impact check on the retrieval step.** Sample retrievals
  by customer segment and test that the distribution of returned chunks is
  not statistically skewed by a protected-class proxy. (Module 6 lab.)
- **Right-to-erasure cascade.** When a customer exercises GDPR/CCPA deletion,
  you must `DELETE` from `CONVERSATION` *and* `CONVERSATION_CHUNK` (the
  embedding is derived NPI). A view or trigger is the cleanest pattern.

## Operational checklist

- [ ] `MINILM_EMB` is in the model inventory with owner, version, validation report.
- [ ] Embedding model file is hashed/signed and stored as a release artifact.
- [ ] Embedding step runs **inside** the ADB perimeter (no transcript bytes leave).
- [ ] `CONVERSATION_CHUNK` is in the same TDE-encrypted tablespace as `CONVERSATION`.
- [ ] Retention policy on `CONVERSATION_CHUNK` matches `CONVERSATION`.
- [ ] Erasure path deletes both rows.
- [ ] Query metric matches index metric (cosine ↔ cosine).
- [ ] Canary recall@K measured per release.
- [ ] p50/p95/p99 latency baselined.
- [ ] Top-K query always JOINs to `customer` for opt-in / suppression gates.

## Verify yourself

- Confirm `conversation_chunk.embedding` is `VECTOR(384, FLOAT32)`.
- Confirm `CONV_CHUNK_IDX` exists and uses `NEIGHBOR PARTITIONS`.
- `EXPLAIN PLAN` on the canonical top-K query and verify the ANN access path.
- Run one wrong-metric query (e.g. `EUCLIDEAN` against a `COSINE` index)
  and confirm the index path is *not* selected — proves you understand the
  failure mode, which is what an auditor will ask about.
- Locate the row in your model inventory for `MINILM_EMB`. If it isn't there,
  stop, file the inventory entry, then continue. This is non-negotiable.
