# Module 2 — SQL/PGQ and Property Graphs Over Relational Tables

## Why this matters

SQL/PGQ lets you traverse business relationships without leaving Oracle SQL or duplicating data into another graph platform.

## Files in scope

- `sql/07_property_graph.sql`
- `sql/09_uc1_card_view.sql`

## Walkthrough: `sql/07_property_graph.sql`

`CREATE PROPERTY GRAPH banking_graph` maps existing tables as:
- Vertexes: `customer`, `product`, `account`
- Edges: `account` (`holds`), `page_event` (`viewed`), `application` (`applied_for`)

Design nuance: `ACCOUNT` appears as both a vertex table and an edge table in this model.

## Walkthrough: `sql/09_uc1_card_view.sql`

UC1 pipeline:
1. Find last viewed product for customer.
2. Traverse graph for peer-viewed products (`GRAPH_TABLE ... MATCH ...`).
3. Rank contextual conversation chunks by vector distance.

## SQL/PGQ vs equivalent SQL

PGQ expresses multi-hop intent with less join boilerplate and better semantic readability.

## Performance guidance

- Index `SOURCE KEY` / `DESTINATION KEY` columns (`page_event.customer_id`, `page_event.product_id`).
- Keep relational predicates selective before broad traversals.
- Capture representative graph query plans in performance baselines.

## Verify yourself

- Validate `BANKING_GRAPH` exists.
- Validate `ACCOUNT` appears in both vertex and edge definitions.
- Parse and execute a 1-hop `GRAPH_TABLE` query via `DBMS_SQL`.
- Check indexing on graph edge FK columns.
