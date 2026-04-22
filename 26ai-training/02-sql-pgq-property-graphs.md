# Module 2 — SQL/PGQ and Property Graphs (for the Offers Team)

> **Regulatory regimes that shape this module:** Reg B / ECOA (graph-derived
> look-alike audiences are a classic disparate-impact trap), FCRA (graph
> traversals can become hidden features in a credit decision), UDAAP
> (peer-based suggestions must not deceive), SR 11-7 (graph traversals
> used in eligibility are a model), records management (the graph definition
> itself is a controlled artifact).

## Why the offers team should care

Look-alike audiences are not new to you. What's new is that SQL/PGQ lets you
build them **inside the same Oracle database that owns the system of record**,
in the same SQL the rest of the offer pipeline already uses, with the same
RBAC, audit, and backup. No graph DB sidecar, no nightly export to a
separate platform, no second copy of NPI to govern.

For the demo, the graph powers UC1: "Customer just landed on the Cash+ Visa
product page. What other card-family products do customers *like them* tend
to view? Use that to choose the relevant peer-comparison nudge."

That's a textbook offers use case — and it's also exactly where fair-lending
controls are easiest to forget.

## Files in scope

- `26ai-banking-demo/sql/07_property_graph.sql` — defines `BANKING_GRAPH`.
- `26ai-banking-demo/sql/09_uc1_card_view.sql` — UC1 query that uses it.

## Walkthrough — `sql/07_property_graph.sql`

```sql
CREATE PROPERTY GRAPH banking_graph
  VERTEX TABLES (
    customer KEY (customer_id) LABEL customer PROPERTIES (full_name, segment),
    product  KEY (product_id)  LABEL product  PROPERTIES (name, family),
    account  KEY (account_id)  LABEL account  PROPERTIES (daily_limit)
  )
  EDGE TABLES (
    account     SOURCE KEY (customer_id) REFERENCES customer
                DESTINATION KEY (product_id) REFERENCES product
                LABEL holds,
    page_event  KEY (event_id) ... LABEL viewed PROPERTIES (event_ts),
    application KEY (app_id)   ... LABEL applied_for PROPERTIES (status)
  );
```

What a principal engineer flags here:

1. **`ACCOUNT` is both a vertex table and an edge table.** That's a deliberate
   modeling choice (an account is an entity *and* a holds-relationship). It is
   fine, but it means the graph has two ways of asking "does this customer
   hold this product" and they must agree. Add a reconciliation check
   (Module 6 lab).
2. **`customer.segment` is exposed as a vertex property.** Segment is a
   business attribute, not a protected class — but if your bank's segment
   definition uses ZIP code, age band, or income proxies, segment becomes a
   protected-class proxy. Confirm with Compliance how `segment` was derived
   before you let any decision read it through the graph.
3. **`full_name` as a vertex property** is unnecessary for any graph query in
   the demo. Drop it. The principle is **data minimization on the graph
   surface** — only expose properties a graph traversal actually needs.
4. **No edge from `customer` to `customer`.** Good. A direct
   customer-to-customer edge would invite collaborative-filtering on PII.
   Peer relationships are inferred *through* products, which is auditable.

## Walkthrough — `sql/09_uc1_card_view.sql`

UC1 pipeline (read it as the offers team would):

1. **Trigger:** customer `:cid` viewed a credit-card product page.
2. **Last-view lookup:** find the most recent `page_event` for `:cid`.
3. **Peer traversal:** `GRAPH_TABLE ... MATCH (c1)-[:viewed]->(p)<-[:viewed]-(c2)-[:viewed]->(p2)` —
   "people who viewed what you viewed also viewed `p2`."
4. **Vector ranking:** for the candidate peer products, find the most-relevant
   conversation snippet to phrase the nudge.

This is **candidate generation** — it does not yet decide eligibility, does
not yet check suppression, does not yet generate the message. Module 5 wires
those in. The graph is the *funnel*, not the decision.

## SQL/PGQ vs. equivalent SQL

PGQ expresses "friend of a friend" intent in one MATCH clause instead of three
self-joins on `page_event`. For the offers team this matters because:

- **Reviewability:** Compliance can read the MATCH clause and see the peer
  logic in one line. Three nested self-joins are easy to misread.
- **Optimizer:** the engine knows it's a graph traversal and can pick a
  better plan than the equivalent `JOIN` chain at higher hops.
- **Stability:** changing from "2-hop" to "3-hop" peer expansion is a one-token
  edit, not a refactor — easier to A/B test.

## Performance guidance

- Index `SOURCE KEY` / `DESTINATION KEY` columns: `page_event(customer_id)`,
  `page_event(product_id)`, `application(customer_id)`, `application(product_id)`.
- Keep relational predicates **selective and ahead of broad traversals.**
  In UC1, the `c1.customer_id = :cid` predicate must be applied first; verify
  in `EXPLAIN PLAN`.
- Capture representative graph query plans in your performance baseline so
  SQL Plan Management can flag regressions (Module 6).
- Multi-hop traversals (>2 hops) explode quickly. Cap with `FETCH FIRST` and
  add a max-hop guard in the wrapper package.

## Fair-lending and ECOA-specific guardrails for graph queries

This is the part most teams miss. Read it carefully.

- **A graph traversal that influences a credit-product offer is a feature in
  a credit decision.** That brings ECOA / Reg B into scope. The `OFFER` table
  in the demo includes the Personal Loan Cashback offer (`product_id = 2`,
  `LOAN` family) — peer traversals over `applied_for` for that product are
  fair-lending sensitive.
- **Do not use protected-class attributes — or proxies — as graph properties
  or as MATCH filters.** No race, color, religion, national origin, sex,
  marital status, age (over a threshold), public-assistance status. ZIP code,
  surname, language, and certain income bands are common *proxies* — handle
  with Compliance.
- **Symmetric peer logic only.** UC1 uses
  `(c1)-[:viewed]->(p)<-[:viewed]-(c2)-[:viewed]->(p2)` — symmetric on
  `viewed`, no reference to `segment`. Good. The moment someone adds
  `WHERE c1.segment = c2.segment`, you have segment-restricted peering and
  must justify it to Compliance for credit products.
- **Adverse-action defensibility.** If a graph traversal contributes to a
  *denial* (or non-presentation) of a credit offer, you must be able to
  state, in plain English, the specific reason — at the level FCRA
  adverse-action notices require. "The graph said no" is not a reason.
  Best practice: graph determines *which* offer to *show*, never *whether*
  to *approve*. Approval logic stays in deterministic, reviewable rules.
- **Segregate the graph for marketing vs. credit decisioning.** Same physical
  graph, two named wrapper procedures with different `WHERE` constraints
  and different audit tags. Module 4 wraps both as MCP tools.

## Auditability — what to log per graph query

For every graph traversal that contributes to a customer-facing decision,
log:

- `customer_id` (the subject of the decision),
- the MATCH pattern identifier (a stable name, not the raw SQL),
- the input parameters,
- the candidate set returned (IDs only, not PII),
- the wall-clock and trace ID,
- the downstream decision (which offer, suppressed, control group, etc.).

This is the same pattern Module 3 uses for `AI_CALL_LOG`. In Module 5 we
unify them under one `OFFER_DECISION_LOG`.

## Verify yourself

- `BANKING_GRAPH` exists (query `USER_PROPERTY_GRAPHS`).
- `ACCOUNT` appears in **both** the vertex and edge definitions.
- The MATCH pattern in `09_uc1_card_view.sql` does **not** reference any
  protected-class attribute or known proxy.
- Indexes exist on every `SOURCE KEY` / `DESTINATION KEY` FK column.
- Parse and execute a 1-hop `GRAPH_TABLE` query via `DBMS_SQL` and capture
  the plan.
- Confirm there is **no** wrapper that lets the credit-decision path call
  graph traversals without a specific reason code (Module 4 lab enforces
  this with a tool catalog check).
