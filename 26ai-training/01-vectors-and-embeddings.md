# Module 1 — Vectors, Embeddings, and ANN Indexes

This module maps AI vector concepts to familiar Oracle DBA and Spring Boot patterns.

## What changes in this repo

- `sql/03_load_onnx_model.sql` registers `MINILM_EMB` using `DBMS_VECTOR.LOAD_ONNX_MODEL`.
- `sql/06_embed_and_index.sql` creates embeddings in `conversation_chunk.embedding` (`VECTOR(384, FLOAT32)`) and builds an ANN index.

## Key mental translation

- Embedding model = deterministic feature-extraction function.
- `VECTOR(384, FLOAT32)` = fixed-width typed numeric payload, similar to any strongly typed column.
- ANN index = cost/latency optimized nearest-neighbor access path (like B-tree for equality/range, but for distance).

## Walkthrough: `sql/03_load_onnx_model.sql`

1. `DBMS_CLOUD.GET_OBJECT` downloads ONNX into `DATA_PUMP_DIR`.
2. `DBMS_VECTOR.LOAD_ONNX_MODEL` registers model alias `MINILM_EMB`.
3. JSON mapping tells Oracle which ONNX input/output names map to SQL call semantics.

Operationally: treat model registration like database artifact deployment (repeatable, versioned, auditable).

## Walkthrough: `sql/06_embed_and_index.sql`

- `INSERT INTO conversation_chunk ... VECTOR_EMBEDDING(MINILM_EMB USING SUBSTR(...) AS DATA)`
  - Embeddings are generated in-database.
- `CREATE VECTOR INDEX conv_chunk_idx ... ORGANIZATION NEIGHBOR PARTITIONS DISTANCE COSINE WITH TARGET ACCURACY 90`
  - This is IVF-style ANN (`NEIGHBOR PARTITIONS`) with cosine metric.

## HNSW vs IVF in Oracle syntax

- HNSW-style: `ORGANIZATION INMEMORY NEIGHBOR GRAPH`
- IVF-style: `ORGANIZATION NEIGHBOR PARTITIONS`

Rule of thumb:
- IVF: simpler memory profile, fast enough for many filtered workloads.
- HNSW: often better recall/latency tradeoff at larger scale and tighter top-K needs.

## Hybrid retrieval pattern (vector + relational + text)

Use vector scoring only after narrowing candidate set with relational predicates and (optionally) text filters.

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
JOIN customer cu ON cu.customer_id = c.customer_id
WHERE cu.segment = :segment
ORDER BY distance
FETCH FIRST :k ROWS ONLY;
```

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
    ORDER BY distance
    FETCH FIRST ? ROWS ONLY
    """;

return jdbcTemplate.query(sql, (rs, i) -> new ChunkHit(
        rs.getLong("chunk_id"),
        rs.getString("chunk_text"),
        rs.getDouble("distance")
    ),
    prompt, topK
);
```

## Operational checklist

- Pin embedding model/version in deployment artifacts.
- Keep query metric aligned with index metric.
- Baseline recall on fixed canary prompts.
- Track top-K latency at p50/p95/p99.
- Rebuild/retrain strategy documented for model changes.

## Verify yourself

- Confirm `conversation_chunk.embedding` is `VECTOR(384, FLOAT32)`.
- Confirm `CONV_CHUNK_IDX` exists and uses `NEIGHBOR PARTITIONS`.
- `EXPLAIN PLAN` on canonical top-K query and verify ANN access path.
- Run one wrong-metric query and confirm index path is not selected.
