# Oracle 26ai Training Track — For the Online Banking Offers Management Team

> Audience: engineers, product owners, decisioning analysts, MarTech platform leads,
> and DBAs who run the **digital banking offers / personalization / next-best-action**
> stack inside a regulated bank. Written from the seat of a **principal engineer**
> who has to stand the design up in front of Architecture Review, Model Risk,
> Compliance (UDAAP / Fair Lending / Privacy), and Audit before a single
> production nudge ships.

The track teaches the AI surface of Oracle Autonomous Database 26ai using the
**Proactive Banking Nudges POC** (`26ai-banking-demo/`) as the concrete reference
implementation. Every module pulls its examples from that schema:

- `CUSTOMER` (with `segment` ∈ Mass / Prime / Affluent),
- `PRODUCT` (Cash+ Visa, Personal Loan, Term Deposit),
- `OFFER` (Cash+ Visa Intro APR, Personal Loan Cashback, Term Deposit Bonus Rate),
- `ACCOUNT`, `TXN`, `APPLICATION`, `PAGE_EVENT`, `CONVERSATION`, `CONVERSATION_CHUNK`,
- the `BANKING_GRAPH` SQL/PGQ definition, the `MINILM_EMB` ONNX model, and the
  `NUDGE_BOT` Select AI profile.

If the demo says it, the training cites it. We do not invent parallel data.

## Who this is for

You are responsible for one or more of:

- **Offer eligibility & decisioning** — who is allowed to see the Cash+ Visa
  Intro APR offer on the credit-card product page right now?
- **Personalization & content generation** — what wording goes on the screen,
  in the in-app message, in the email, in the push notification?
- **Suppression & opt-out enforcement** — who must *not* be marketed to today,
  and on which channels?
- **Channel-of-record** — is this message a marketing communication (CAN-SPAM /
  TCPA / GLBA opt-out) or a transactional/servicing message (Reg E error
  resolution, Reg Z account servicing)? They have different rules.
- **Fair-lending & UDAAP review** — can we defend, in writing, why this
  customer got this offer, in this language, on this date?
- **Operations** — SLOs, on-call, model drift, audit trail, retention,
  legal hold, regulator data requests.

You are assumed to be comfortable with:

- Production Java / Spring Boot (`JdbcTemplate`, transactions, HikariCP).
- Operating Oracle (init params, AWR/ASH, indexes, partitioning, RMAN, RBAC).
- The bank's existing offers stack (eligibility tables, campaign manager,
  decisioning engine, suppression lists, attribution).

You are assumed to be **new to the AI primitives**: vectors, embeddings, ANN
indexes, RAG, LLM-driven generation, agents, MCP. We translate each one to
something already in your operating model.

## Regulatory map — keep this open in a second tab

These are the rules that shape the design choices in every module. None of
them is optional. Most of them apply to *both* the eligibility decision *and*
the generated message text.

| Regime | Applies to | What it forces in this stack |
|---|---|---|
| **UDAAP** (Dodd-Frank §1031/§1036, CFPB) | Any consumer-facing message, including LLM-generated nudges | No deceptive/abusive framing; reviewable content; reproducible record of what each customer was shown |
| **Reg B / ECOA** | Any credit decision (Personal Loan, Cash+ Visa eligibility) | No use of protected-class attributes (race, color, religion, national origin, sex, marital status, age, public-assistance status) as features in eligibility, including via proxy or graph traversal |
| **FCRA** | Adverse action on credit applications | Adverse-action notice with specific reasons; cannot use a black-box LLM rationale; must be derivable from inputs |
| **Reg Z (TILA)** | Credit-card / loan offer disclosures | Cost-of-credit terms (APR, fees) shown in approved language, not paraphrased by an LLM |
| **Reg DD (TISA)** | Deposit (Term Deposit) offer disclosures | APY and term language must match approved disclosure |
| **Reg E** | Electronic fund transfer error/dispute messages (declined transaction servicing) | UC3 messages that resolve a declined txn are servicing, not marketing — different consent model, different retention |
| **GLBA** | NPI (non-public personal information) | Embedding transcripts, account numbers, balances → all NPI; cannot leave the bank's controlled environment without contract; encryption at rest + in transit |
| **TCPA / CAN-SPAM / state e-sign** | Outbound channel (SMS, email, push) | Channel-level consent + opt-out, frequency cap, quiet hours; suppression-list authoritative |
| **GDPR / CCPA / state privacy** | EU/CA/etc. customers | Lawful basis, DSAR, right to deletion, automated decision-making disclosure |
| **SR 11-7 / OCC 2011-12** | Any model used in a decision (embedding model, LLM, graph-based scoring) | Model inventory, validation, monitoring, change control, challenger model, documented limitations |
| **BSA / AML** | Transaction monitoring | Don't let nudges leak SAR-related signals to the customer; declined-for-fraud messaging is constrained |
| **PCI-DSS** | PAN, CVV, expiry | Never embed PAN; tokenize before any AI surface |
| **NYDFS Part 500 / FFIEC** | Cybersecurity & third-party risk | LLM provider is a third party; data-flow inventory; incident reporting clock |
| **SOX** | Financial reporting | Anything affecting revenue recognition (campaign attribution → bookings) needs ITGC controls |
| **Records management** | Bank policy + regulator retention schedules | `AI_CALL_LOG`, prompts, outputs, eligibility snapshots are records; retention + legal hold |

Each module flags which of these regimes shape the design choice it describes.

## Modules

| # | File | Topic | Demo files anchored |
|---|------|-------|--------------------|
| 1 | `01-vectors-and-embeddings.md` | VECTOR datatype, ONNX embeddings, ANN indexes, hybrid search — and why your transcript embeddings are NPI under GLBA | `sql/03_load_onnx_model.sql`, `sql/06_embed_and_index.sql`, `CONVERSATION`, `CONVERSATION_CHUNK` |
| 2 | `02-sql-pgq-property-graphs.md` | SQL/PGQ as a look-alike audience builder — and the ECOA / fair-lending traps in graph-derived eligibility | `sql/07_property_graph.sql`, `sql/09_uc1_card_view.sql`, `BANKING_GRAPH` |
| 3 | `03-select-ai-and-dbms-cloud-ai.md` | Select AI as a governed offer-content generator with UDAAP review, adverse-action handling, and Reg Z/DD disclosure protection | `sql/08_select_ai_profile.sql`, `sql/11_uc3_declined_txn.sql`, `NUDGE_BOT` profile |
| 4 | `04-mcp-and-sqlcl.md` | MCP named tools as the **policy enforcement point** for the offers agent (suppression, opt-out, frequency cap, channel-of-record) | `mcp/README.md`, `mcp/tools/peer_products.sql` |
| 5 | `05-putting-it-all-together.md` | End-to-end offer lifecycle: trigger → eligibility → suppression/opt-out → frequency cap → channel-of-record split → generation → control group → delivery → attribution → archival | All UC files + `docs/architecture.md`, `docs/demo-script.md` |
| 6 | `06-operations-and-observability.md` | Regulator-grade observability: AI_CALL_LOG retention, disparate-impact monitoring, model drift under SR 11-7, cost guardrails, legal hold, regulator data request playbook | All of the above + ops |

## Companion code (in the demo repo)

| File | What it shows |
|------|---------------|
| `examples/spring/NudgeRepository.java` | Spring `JdbcTemplate` calling vector search + SQL/PGQ + Select AI |
| `examples/spring/NudgeService.java` | OpenTelemetry-instrumented service layer |
| `examples/spring/OtelDataSourceConfig.java` | Wraps `DataSource` with `JdbcTelemetry` for one-to-one APM↔DB correlation (needed for regulator data requests) |
| `examples/spring/application.yml` | HikariCP `connection-init-sql` for `SET_PROFILE` |
| `examples/spring/pom-otel-snippet.xml` | OTel JDBC + Spring Boot starter deps |
| `examples/mcp/claude_desktop_config.json` | Working MCP client config for SQLcl `-mcp` |
| `mcp/tools/peer_products.sql` | Example SQLcl MCP named tool — note: this is a *policy enforcement point*, not just a query |

## Hands-on lab

| File | What it does |
|------|--------------|
| `labs/00-LAB-README.md` | Lab overview + how to run |
| `labs/lab_setup.sql` | Creates `lab_results` scoring table + asserter procs + prereq guard |
| `labs/lab01_vectors.sql` | Module 1 self-checks (vector schema, index, NPI handling) |
| `labs/lab02_graphs.sql` | Module 2 self-checks (graph definition, fair-lending guard) |
| `labs/lab03_select_ai.sql` | Module 3 self-checks (profile, object_list minimization, AI_CALL_LOG, UDAAP review queue) |
| `labs/lab04_mcp.sql` | Module 4 self-checks (least-priv agent, suppression wrapper, opt-out wrapper) |
| `labs/lab05_e2e.sql` | Module 5 self-checks (offer-lifecycle controls in place) |
| `labs/lab06_ops.sql` | Module 6 self-checks (audit retention, disparate-impact sampling, legal-hold) |
| `labs/lab_report.sql` | Final pass/fail/manual scoreboard |

## How to use this track

1. Read modules 1→6 in order. Each builds on the previous.
2. Run the corresponding SQL file from `26ai-banking-demo/sql/` in ADB while you read.
3. At the end, run the hands-on lab for self-grading PASS/FAIL/MANUAL.
4. Module 5 includes the **launch-readiness checklist** the offers PMO will hold you to.
   Module 6 includes the **on-call + regulator-data-request** playbook.

## Mental model — keep this in your head the whole time

> Oracle 26ai does **not** add a new database. It adds:
>   - one new **datatype** (`VECTOR`),
>   - one new **index kind** (vector ANN: HNSW / IVF),
>   - a couple of new **SQL operators** (`VECTOR_EMBEDDING`, `VECTOR_DISTANCE`),
>   - a **graph view layer** (SQL/PGQ) over existing tables,
>   - and two **PL/SQL packages** (`DBMS_VECTOR`, `DBMS_CLOUD_AI`) that wrap models and LLM providers.
>
> Everything else — transactions, RBAC, partitioning, backup, replication, RAC,
> Data Guard, AWR, SQL plan management — works the way it already does. Which
> means the bank's existing controls (encryption, key management, audit,
> retention, legal hold, change management, ITGC) **already cover the AI
> surface**, *if* you keep the AI surface inside the database. That is the
> single biggest reason this design is defensible to Compliance and Audit.

> Second mental model: **a nudge is a regulated communication, not a string.**
> Every model in this track exists to keep that string defensible end-to-end —
> who was eligible, why, with what data, generated by which model version,
> reviewed by whom, suppressed for whom, sent on which channel, retained for
> how long.
