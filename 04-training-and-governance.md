# Training and Governance

This chapter carries the long-form instructional content from the training track. It is written for humans who need to understand the system, the reasoning, the regulatory boundaries, and the evidence the bank has to produce.

## Training intent

The training is not trying to teach a generic AI workflow. It is trying to teach the offers team how to work with Oracle 26ai inside a regulated bank.

That means the training must explain:

- how vectors fit into the bank's existing data model,
- how property graphs can be used without creating a separate graph platform,
- how Select AI must be wrapped so it remains governed,
- how MCP tools become policy enforcement points,
- and how operations, retention, and audit evidence must be designed up front.

## Banking and marketing training outcomes

The training is designed so both banking and marketing teams can operate from one shared model.

- Banking outcomes: readers can explain eligibility boundaries, servicing classification, audit record requirements, and regulator-facing evidence.
- Marketing outcomes: readers can explain contextual nudge design, suppression and frequency controls, channel discipline, and attribution-ready decision logging.

The shared success condition is that personalization quality improves without loosening policy controls.

## The regulatory map

These are the rules that shape the design choices in every module. None of them is optional.

| Regime | Applies to | What it forces in this stack |
| --- | --- | --- |
| UDAAP | Any consumer-facing message, including generated nudges | No deceptive or abusive framing; reviewable content; reproducible record of what each customer saw |
| Reg B / ECOA | Any credit decision | No protected-class attributes or proxies in eligibility |
| FCRA | Adverse action on credit applications | Adverse-action notice with specific reasons; no black-box rationale |
| Reg Z | Credit-card and loan offer disclosures | Approved language for cost of credit, not paraphrase |
| Reg DD | Deposit offer disclosures | Approved APY and term language |
| Reg E | Electronic fund transfer servicing messages | Declined-transaction servicing is not marketing |
| GLBA | NPI | Transcript data, balances, and embeddings remain controlled data |
| TCPA / CAN-SPAM | Outbound email, SMS, push | Consent, opt-out, frequency cap, quiet hours |
| GDPR / CCPA | EU/CA privacy regimes | Lawful basis, erasure, disclosure obligations |
| SR 11-7 / OCC 2011-12 | Models in the decision path | Inventory, validation, monitoring, change control |
| PCI-DSS | Card data | PAN, CVV, expiry must never be embedded |
| Records management | Bank policy and retention schedules | Prompts, outputs, and eligibility snapshots are records |

The purpose of the map is not to create a separate policy system. The purpose is to force the reader to see that the data path itself has to be governable.

## Module structure

The training track is organized around six modules.

| Module | Topic | What the learner should be able to explain |
| --- | --- | --- |
| 1 | Vectors and embeddings | Why transcript chunks become a vector column, why that data remains regulated, and why vector search is still a database operation |
| 2 | Property graphs | Why SQL/PGQ can model customer-product relationships, and why graph traversals can become fair-lending issues |
| 3 | Select AI and `DBMS_CLOUD_AI` | Why governed generation needs profile limits, approved disclosures, call logging, and human review |
| 4 | MCP and SQLcl | Why named tools are safer than arbitrary SQL and how suppression becomes an enforcement point |
| 5 | End-to-end lifecycle | How trigger, eligibility, suppression, generation, delivery, and archival compose into one recordable flow |
| 6 | Operations and observability | How to monitor model behavior, retention, cost, drift, and regulator requests |

## Module responsibility map

| Module | Banking responsibility | Marketing responsibility |
| --- | --- | --- |
| 1 | Treat embeddings as controlled bank data | Use semantic retrieval to improve relevance safely |
| 2 | Keep graph features fair-lending safe | Use relationship context to improve candidate quality |
| 3 | Enforce governed generation and records-of-record | Produce campaign-safe text with approved disclosures |
| 4 | Enforce policy through tool wrappers and least privilege | Keep outbound actions compliant by channel and suppression state |
| 5 | Keep decisions replayable and reasoned | Run lifecycle with measurable conversion checkpoints |
| 6 | Maintain retention, legal hold, and incident readiness | Monitor campaign quality, suppression health, and cost efficiency |

## The instructional pattern

Each module should teach the same way:

1. State the business problem.
2. Map the AI primitive to an existing database concept.
3. Show the schema or SQL pattern.
4. Explain the control surface.
5. Define the evidence the bank must keep.
6. Show how the lab verifies the design.

That pattern is more important than any single feature. It is the reason the material can train humans instead of merely describing software.

## Companion code

The repository includes reference code that supports the training:

- Spring `JdbcTemplate` examples for retrieval and orchestration.
- OpenTelemetry wiring for trace propagation.
- MCP examples that show how the database can be exposed as named tools.
- The lab suite, which turns the training into self-grading SQL checks.

The code is part of the training material. It is not decorative. It teaches the reader how the documented controls appear in executable form.

## What the learner should retain

At the end of the training, a human should be able to explain:

- why the bank keeps the AI surface inside Oracle Database 26ai,
- why every customer-facing generated string needs a governance story,
- why the delivery channel changes the compliance rules,
- why a graph traversal is not just a convenience feature when credit is involved,
- and why evidence, logging, and retention are part of the design rather than afterthoughts.

## Next phase handoff

Next phase: integration.

Read next:

- [../mcp/README.md](../mcp/README.md)
- [../spring/README.md](../spring/README.md)

Run next:

- `./scripts/db/install_app_sql_extensions.sh --connect user/password@dsn`
- `./scripts/db/run_sql_sequence.sh --connect user/password@dsn sql/integration/13_mcp_peer_products_tool.sql sql/integration/14_apex_nudge_chat_api.sql`
