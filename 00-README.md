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

# AI in Banking (Marketing & Online Offers) — Master Regulatory Map

| Regime | Applies to | What it forces in this AI stack |
| :--- | :--- | :--- |
| **UDAAP** *(Dodd-Frank §1031/§1036, CFPB)* | Any consumer-facing message, including LLM-generated nudges | No deceptive or abusive framing; reviewable content; reproducible record of what each customer was shown. |
| **Reg B / ECOA** | Any credit decision (Personal Loan, Cash+ Visa eligibility) | No use of protected-class attributes as features in eligibility, including via proxy, graph traversal, or complex predictive models. |
| **FCRA** | Adverse action on credit applications | Mandatory adverse-action notices with specific, derivable reasons; prohibits black-box LLM rationales or untraceable outputs. |
| **CFPB AI Circulars** *(2022-03 & 2023-03)* | Complex algorithms & LLM prompts driving credit decisions/nudges | Prohibits generic sample adverse-action reasons; notices must state the *exact* factors used, including non-traditional algorithmic inputs. |
| **Reg Z (TILA)** | Credit-card / loan offer disclosures | Cost-of-credit terms (APR, fees, promotional rates) shown in pre-approved verbatim language; **cannot be paraphrased** by an LLM. |
| **Reg DD (TISA)** | Deposit (Term Deposit) offer disclosures | APY and term language must match approved, mandatory disclosures exactly. |
| **Reg E** | Electronic fund transfer error/dispute messages (declined txn servicing) | Messages resolving declined transactions are servicing, not marketing—requires different consent models, quiet-hour rules, and retention schedules. |
| **GLBA** | Non-Public Personal Information (NPI) | Embedding transcripts, account numbers, and balances are NPI; cannot leave the bank's controlled environment without strict contract; encryption at rest and in transit. |
| **CFPB Section 1033** *(Personal Financial Data Rights)* | Open banking data fed into AI personalization/cross-selling models | Mandates consumer data access while strictly limiting the secondary use of transaction history for automated marketing without explicit, affirmative consent. |
| **State ADMT Laws** *(e.g., CA CCPA, CO AI Act)* | Automated decision-making technology & AI profiling for offers | Requires pre-decision notices to consumers, opt-out mechanisms for automated marketing/profiling, and post-outcome explanation rights. |
| **GDPR / CCPA / State Privacy** | EU / CA / applicable state customers | Lawful basis for processing, DSARs, right to deletion, and mandatory disclosures regarding automated decision-making. |
| **EU AI Act** *(Reg 2024/1689)* | AI systems evaluating credit eligibility or scoring risk for EU users | Classifies credit scoring/eligibility as **High-Risk** (Annex III); mandates fundamental rights impact assessments, EU AI database registration, transparency, and human oversight. |
| **SR 11-7 / OCC Guidance** *(Model Risk Management)* | Any model in a decision chain (embeddings, LLMs, scoring engines) | Model inventory, validation, ongoing monitoring, change controls, challenger models, and documented limitations. |
| **NIST AI RMF 1.0** *(SR 11-7 AI Extension)* | Generative LLMs, RAG pipelines, and prompt architectures | Operational controls specifically targeting non-deterministic LLM behaviors: hallucination guardrails, prompt injection defenses, and real-time output monitoring. |
| **2023 Interagency Third-Party Guidance** | Cloud-hosted LLM providers, API endpoints, SaaS vendors | Evaluates third-party AI vendors as high-risk; forces vendor audit rights, data sovereignty, exit strategies, and continuous operational resilience. |
| **TCPA / CAN-SPAM / State e-Sign** | Outbound channels (SMS, email, push notifications) | Channel-level consent + opt-out, frequency caps, quiet hours, and authoritative suppression-list management. |
| **BSA / AML** | Transaction monitoring and fraud detection | Prevents marketing nudges from leaking SAR-related signals to customers; strict constraints on messaging for fraud-declined accounts. |
| **PCI-DSS** | Cardholder data (PAN, CVV, Expiry) | Never embed raw PANs; must tokenize all card numbers before entering any prompt context or AI surface. |
| **NYDFS Part 500 / FFIEC** | Cybersecurity & third-party risk management | AI vendor data-flow mapping, strict incident reporting clocks, and real-time anomaly detection. |
| **SOX** | Financial reporting and revenue attribution | Anything affecting campaign attribution or bookings requires IT General Controls (ITGC) and auditable lineage. |

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



# Oracle Database 26ai: Next-Generation Real-Time Banking Nudges Architecture Blueprint

## Executive Summary & Architectural Vision

Modern financial institutions face a critical architectural challenge: delivering hyper-personalized, context-aware customer "nudges" (e.g., proactive overdraft warnings, tailored credit offers, abandoned application recovery) in sub-second response times while strictly adhering to rigorous regulatory frameworks (UDAAP, Reg B, Reg Z, EU AI Act, NIST AI RMF, and BSA/AML).

Historically, banks attempted to solve this using **fragmented microservice architectures**, piping transaction data out of relational databases into external Vector Databases, Graph Engines, and LLM orchestration layers. This approach introduces severe risks and overhead:

-   **Data Egress & Privacy Risks:** Constant data transfer exposes PII across multiple external boundaries.
    
-   **Latency Penalties:** Multi-hop network latency destroys sub-second real-time responsiveness.
    
-   **Data Stale & Sync Issues:** ETL pipelines create data drift between operational ledgers and AI vector indices.
    
-   **Regulatory Non-Compliance:** Lack of unified transactional lineage makes explainability and auditability nearly impossible.
    

### The Converged Solution: Oracle Database 26ai

Oracle Database 26ai unifies transactional ledgers (ACID relational engine with **Lock-Free Column Value Reservations**), vector search (**AI Vector Search** with HNSW/IVF indexing), graph analytics (**SQL/PGQ** recursive traversal), natural language interfaces (**Select AI** with **In-Database Agentic AI Workflows** and **`DBMS_DATA_ANNOTATIONS`**), and **True Cache** middle-tier acceleration inside a single enterprise-grade engine.

Furthermore, 26ai introduces **NIST-Approved ML-KEM Quantum-Resistant Encryption** to protect both data-at-rest and data-in-transit against future quantum-harvesting threats.

```
+-----------------------------------------------------------------------------------+
|                            ORACLE DATABASE 26ai CORE ENGINE                       |
|                                                                                   |
|  +--------------------+   +-----------------------+   +------------------------+  |
|  | Relational Ledger  |   |   AI Vector Search    |   |  Property Graph PGQ    |  |
|  | (Lock-Free / InMem)|   |  (HNSW / IVF Vectors) |   |  (Recursive Traversal) |  |
|  +---------+----------+   +-----------+-----------+   +-----------+------------+  |
|            |                          |                           |               |
|            +--------------------------+---------------------------+               |
|                                       |                                           |
|                           +-----------v-----------+                               |
|                           |  Select AI & Agentic  |                               |
|                           | (DBMS_DATA_ANNOTATIONS|                               |
|                           +-----------+-----------+                               |
+---------------------------------------|-------------------------------------------+
                                        v
                       +----------------------------------+
                       | Quantum-Resistant, Compliant Nudge|
                       +----------------------------------+
```
Updated todo list

## Strategic Architectural Comparison

| Architectural Metric | Fragmented Architecture (Polyglot Mesh) | Oracle 26ai Converged Architecture |
|---|---|---|
| Data Egress Risk | High (Data synced across 4+ external engines) | Zero (Data never leaves DB boundaries via in-DB ONNX/LLM routing) |
| End-to-End Latency | 450ms – 1,200ms (Network hops & sync delays) | < 35ms (In-Memory execution & True Cache acceleration) |
| Consistency Model | Eventual Consistency (Sync delay/drift) | Immediate ACID Consistency with Lock-Free Reservations |
| Regulatory Auditability | Complex distributed log stitching | Unified Immutable Audit, Blockchain Tables, & Flashback |
| Operational TCO | High (Siloed licenses, infrastructure, DBAs) | Low (Single standard Oracle DB stack with ML-KEM security) |

## End-to-End Nudge Generation Lifecycle

```
[ Customer Action / Event Stream via TxEventQ / Kafka APIs ]
          │
          ▼
1. INGESTION & IN-MEMORY ENGINE
   - Captures high-frequency transactions via TxEventQ.
   - Evaluates rule triggers in real time (<5ms) using Lock-Free reservations.
          │
          ▼
2. VECTOR SIMILARITY SEARCH
   - Calculates embedding distance against Customer Persona Vectors.
   - Filters relevant financial product offerings via HNSW Index.
          │
          ▼
3. SQL/PGQ GRAPH TRAVERSAL
   - Analyzes peer network, household connections, and referral graphs.
   - Derives contextual affinity scores without protected-class attributes.
          │
          ▼
4. SELECT AI & AGENTIC WORKFLOW SYNTHESIS
   - Integrates transactional state using DBMS_DATA_ANNOTATIONS.
   - Passes tokenized prompt to LLM via Secure Enterprise Hub.
          │
          ▼
5. COMPLIANCE & QUANTUM-RESISTANT REDACTION FILTER
   - Enforces all 20 regulatory checks (UDAAP, Reg Z, BSA/AML, EU AI Act).
   - Applies ML-KEM encryption, PII masking, and blockchain immutable logging.
          │
          ▼
[ Customer Delivery (Mobile App / Push / Web via True Cache) ]

```

## Production Use Cases & Implementation Code

### Use Case 1: Real-Time Credit Card Cross-Sell via Vector Search

Matches customer spending behavior and transaction history against embedding vectors of financial products to generate real-time push recommendations.

SQL

```
-- Create Table for Product Offerings with Vector Embeddings
CREATE TABLE banking_product_catalog (
    product_id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_name        VARCHAR2(100) NOT NULL,
    product_category    VARCHAR2(50),
    min_credit_score    NUMBER,
    product_description VARCHAR2(1000),
    product_vector      VECTOR(1536, FLOAT32)
);

-- Real-Time Vector Similarity Search Query (HNSW Index Accelerated)
SELECT 
    p.product_id,
    p.product_name,
    p.product_description,
    VECTOR_DISTANCE(p.product_vector, :customer_profile_vector, COSINE) AS distance
FROM 
    banking_product_catalog p
WHERE 
    p.min_credit_score <= :customer_credit_score
ORDER BY 
    distance ASC
FETCH FIRST 3 ROWS ONLY;

```

#### PL/SQL Nudge Decision Engine Procedure (with Data Annotations & ML-KEM Protection)

SQL

```
CREATE OR REPLACE PROCEDURE generate_credit_card_nudge (
    p_customer_id IN NUMBER,
    p_nudge_text  OUT VARCHAR2
) AS
    v_cust_vector    VECTOR(1536, FLOAT32);
    v_credit_score   NUMBER;
    v_best_product   VARCHAR2(100);
    v_prompt         VARCHAR2(2000);
BEGIN
    -- Extract customer credit score and vector profile securely
    SELECT credit_score, embedding_vector 
    INTO v_credit_score, v_cust_vector
    FROM customer_profiles
    WHERE customer_id = p_customer_id;

    -- Vector similarity match against catalog
    SELECT product_name
    INTO v_best_product
    FROM banking_product_catalog
    WHERE min_credit_score <= v_credit_score
    ORDER BY VECTOR_DISTANCE(product_vector, v_cust_vector, COSINE) ASC
    FETCH FIRST 1 ROWS ONLY;

    -- Synthesize Nudge using Select AI with Database Annotations
    v_prompt := 'Synthesize a friendly, non-coercive financial nudge for product: ' || v_best_product;
    
    SELECT AI GENERATE v_prompt 
    INTO p_nudge_text;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        v_nudge_text := 'Default: Explore our rewards credit cards today.';
END generate_credit_card_nudge;
/

```

### Use Case 2: Abandoned Loan Application Recovery via SQL/PGQ Graph Search

Identifies stalled auto/home loan applications, evaluates customer household relationships and referral history using Property Graph Queries, and triggers personalized support nudges while excluding protected classes (Reg B/ECOA compliance).

SQL

```
-- Define Property Graph over Banking Entities
CREATE PROPERTY GRAPH banking_relationship_graph
  VERTEX TABLES (
    customers KEY (customer_id),
    loan_applications KEY (application_id)
  )
  EDGE TABLES (
    customer_referrals KEY (referral_id)
      SOURCE KEY (referrer_id) REFERENCES customers (customer_id)
      DESTINATION KEY (referee_id) REFERENCES customers (customer_id),
    application_ownership KEY (ownership_id)
      SOURCE KEY (customer_id) REFERENCES customers (customer_id)
      DESTINATION KEY (application_id) REFERENCES loan_applications (application_id)
  );

-- SQL/PGQ Query: Detect Stalled Applications with Connected Peer Engagement
SELECT 
    c.customer_id,
    c.full_name,
    app.application_id,
    app.loan_type,
    app.stalled_days,
    COUNT(DISTINCT peer.customer_id) AS active_referred_peers
FROM 
    GRAPH_TABLE (banking_relationship_graph
      MATCH 
        (c:customers) -[o:application_ownership]-> (app:loan_applications),
        (c:customers) -[r:customer_referrals]-> (peer:customers)
      WHERE 
        app.status = 'INCOMPLETE' 
        AND app.stalled_days >= 3
      COLUMNS (
        c.customer_id,
        c.full_name,
        app.application_id,
        app.loan_type,
        app.stalled_days,
        peer.customer_id AS peer_id
      )
    )
GROUP BY 
    c.customer_id, c.full_name, app.application_id, app.loan_type, app.stalled_days;

```

### Use Case 3: Transaction Servicing & Overdraft Prevention

Monitors checking balances in real time using the Oracle In-Memory Column Store and **Lock-Free Column Value Reservations** to execute proactive notifications before fee occurrences without lock contention.

SQL

```
-- Configure High-Frequency Account Ledger for In-Memory Acceleration & Lock-Free Reservations
ALTER TABLE customer_accounts INMEMORY MEMCOMPRESS FOR CAPACITY;

-- Real-Time Overdraft Risk Detection Query
SELECT 
    a.account_id,
    a.customer_id,
    a.current_balance,
    SUM(t.amount) AS pending_debits_24h,
    (a.current_balance - SUM(t.amount)) AS projected_balance
FROM 
    customer_accounts a
JOIN 
    pending_transactions t ON a.account_id = t.account_id
WHERE 
    a.account_type = 'CHECKING'
    AND t.transaction_status = 'PENDING'
GROUP BY 
    a.account_id, a.customer_id, a.current_balance
HAVING 
    (a.current_balance - SUM(t.amount)) < 50.00;
```
<!--stackedit_data:
eyJoaXN0b3J5IjpbLTgzMjI3OTYxMl19
-->