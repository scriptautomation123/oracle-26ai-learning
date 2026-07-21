# Start Here: Banking Demo Documentation Path

This is the single entry point for engineers using the banking demo documentation.

If you read only one file first, read this one.

## What this guide gives you

- A clear start point.
- A clear end point.
- A chapter order that matches how teams actually build and operate the demo.
- A handoff from documentation to labs.
- A script taxonomy that separates setup, data preparation, database operations, demo execution, and cleanup.

## Primary lens for this documentation

This manual is written for a bank running a digital marketing and servicing platform, not for a generic AI demo.

- Banking lens: account events, product eligibility, risk controls, servicing obligations, and auditability.
- Marketing lens: campaign timing, channel rules, suppression enforcement, personalization quality, and conversion measurement.

Every chapter should be read as banking decisioning plus marketing execution under regulatory constraints.

## Reader path (start to end)

1. [01-business-and-vision.md](01-business-and-vision.md)
   Why this demo exists, which customer moments matter, and what outcomes the system is designed to produce.

2. [02-architecture-and-data-model.md](02-architecture-and-data-model.md)
   How relational, vector, graph, Select AI, and MCP fit into one database-centered design.

3. [03-dba-and-query-patterns.md](03-dba-and-query-patterns.md)
   Run order, query shape, indexing posture, and storage/latency planning for implementation teams.

4. [04-training-and-governance.md](04-training-and-governance.md)
   The training model, regulatory boundaries, and the evidence model expected in a bank environment.

5. [05-operations-and-controls.md](05-operations-and-controls.md)
   Monitoring, retention, legal hold, rollback, and reliability controls.

6. [demo-script.md](demo-script.md)
   Live walkthrough order once setup is complete.

7. [../labs/00-LAB-README.md](../labs/00-LAB-README.md)
   Execute integrated training checks now embedded in `sql/06..11` and review archived standalone labs.

8. [90-finish-and-readiness.md](90-finish-and-readiness.md)
   End-state checklist for completion.

## Operational path

Use this path when you want the docs to mirror the way the repository is actually operated.

1. Setup
   Read [03-dba-and-query-patterns.md](03-dba-and-query-patterns.md) and use `scripts/setup/`.

2. Data preparation
   Read [03-dba-and-query-patterns.md](03-dba-and-query-patterns.md) and use `scripts/data/`.

3. Database build
   Read [02-architecture-and-data-model.md](02-architecture-and-data-model.md) and [03-dba-and-query-patterns.md](03-dba-and-query-patterns.md), then run `sql/foundation/`, `sql/ai/`, and `scripts/db/`.

4. Use-case run
   Read [01-business-and-vision.md](01-business-and-vision.md), [demo-script.md](demo-script.md), and run `sql/use-cases/`.

5. Integration
   Read [mcp/README.md](../mcp/README.md), [spring/README.md](../spring/README.md), and run `sql/integration/` plus the extension installer under `scripts/db/`.

6. Cleanup
   Use `scripts/cleanup/` after demo or local environment work is complete.

## Where to start by role

- Application engineer: start at Chapter 1, then Chapters 2, 4, 5, and the demo script.
- DBA/platform engineer: start at Chapter 3, then Chapters 2 and 5.
- Risk/compliance reviewer: start at Chapter 4, then Chapters 5 and 3.
- Marketing operations lead: start at Chapter 1, then Chapters 4, 5, and the demo script.
- Servicing operations lead: start at Chapter 1, then Chapters 4 and 5.

## Definition of done for this docs path

You are done when you can explain:

- how UC1, UC2, and UC3 differ,
- why retrieval is filter-first then semantic ranking,
- how suppression and channel-of-record are enforced,
- where operational evidence is written,
- and how the lab suite validates the expected controls.

## Operational script phases

- Setup: `scripts/setup/`
- Data preparation: `scripts/data/`
- Database operations: `scripts/db/`
- Demo execution: `scripts/demo/`
- Cleanup: `scripts/cleanup/`
