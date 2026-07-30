

# Enterprise Technical Review and Production Blueprint: Oracle Database 26ai Converged Architecture for Proactive Banking Nudges

## Executive Architectural Review and Notebook Validation

The integration of artificial intelligence within financial services presents a fundamental architectural challenge: balancing high-velocity contextual decisioning with strict regulatory oversight. Traditional implementations rely on a best-of-breed, multi-tier stack where relational transaction stores stream data via extract-transform-load (ETL) pipelines into disparate vector databases, graph engines, and third-party large language model (LLM) endpoints. In a highly regulated banking context, this distributed approach introduces severe operational complexity, latency overhead, and significant security vulnerabilities due to non-public personal information (NPI) egressing across multiple security perimeters.

The provided training notebook (`oracle_26ai_banking_nudges_training.ipynb`) introduces an alternative approach utilizing the converged capabilities of Oracle Database 26ai. By consolidating relational data, vector embeddings, property graph overlays (`SQL/PGQ`), natural language interfaces (`Select AI`), and Model Context Protocol (`MCP`) tool interfaces within a single operational database engine, the platform simplifies real-time nudge generation while maintaining strict ACID guarantees and enterprise security controls.

An exhaustive technical evaluation of the notebook confirms that its core concept—extending existing relational schemas rather than replacing them—is sound and aligned with enterprise database standards. However, transitioning the artifact from a training prototype to a production-grade deployment requires specific technical corrections, parameter adjustments, and governance wrappers.

A "nudge" in a retail or commercial banking environment is legally classified as a regulated communication. Whether delivering an introductory annual percentage rate (APR) offer for a credit card, recovering an abandoned loan application, or providing real-time servicing following a declined point-of-sale transaction, generated messages are subject to federal and state statutory frameworks. Generative AI utilities cannot operate as autonomous decisioning engines; they must act as strictly bounded phrasing modules subject to deterministic eligibility rules, suppression filters, frequency caps, and static disclosure substitution mechanisms.

## Technical Review and Correctness Corrections

A thorough review of the database objects, SQL operators, and PL/SQL package calls within the training notebook yields several key technical findings across syntax compatibility, execution paths, and performance optimization.

### In-Database ONNX Model Loading and Vector Operations

The notebook demonstrates loading an Open Neural Network Exchange (ONNX) embedding model (`all_MiniLM_L6_v2.onnx`) directly into the database kernel using `DBMS_VECTOR.LOAD_ONNX_MODEL`. In Oracle 23ai and 26ai, loading an in-database ONNX model translates text strings directly into `VECTOR(384, FLOAT32)` representations without invoking external REST endpoints or transmitting customer transcripts outside the database boundary.

The signature used in the training notebook relies on positional parameters or simplified helper calls. In enterprise PL/SQL deployments, named parameters must be explicitly specified to maintain forward compatibility and prevent runtime signature mismatches across minor database updates. Furthermore, the JSON metadata descriptor must explicitly map the input tensor array and output vector names.
```
BEGIN
  DBMS_VECTOR.LOAD_ONNX_MODEL(
    directory => 'DATA_PUMP_DIR',
    file_name => 'all_MiniLM_L6_v2.onnx',
    model_name => 'MINILM_EMB',
    metadata => JSON('{"function":"embedding","embeddingOutput":"embedding","input":{"input":["DATA"]}}')
  );
END;
/
```
During semantic retrieval, the distance metric defined in the vector index must match the metric used in query operators. The notebook defines the vector index `CONV_CHUNK_IDX` using `DISTANCE COSINE`. Consequently, all `VECTOR_DISTANCE` query filters must explicitly declare `COSINE`. If a query attempts to calculate `EUCLIDEAN` or `DOT` distance against a `COSINE`-indexed column, the Cost-Based Optimizer (CBO) bypasses the approximate nearest neighbor (ANN) vector index and executes a full table scan, degrading performance at scale.
### perty Graph Definitions and SQL/PGQ Traversal

The notebook constructs a property graph (`BANKING_GRAPH`) using standard `SQL/PGQ` syntax. The graph establishes vertex tables (`CUSTOMER`, `PRODUCT`, `ACCOUNT`) and edge tables (`ACCOUNT` as `holds`, `PAGE_EVENT` as `viewed`, `APPLICATION` as `applied_for`).

A critical structural detail involves the `ACCOUNT` table, which serves as both a vertex (representing a financial product instance) and an edge (connecting a customer to a product). While valid in standard property graph modeling, this dual representation requires strict foreign key index coverage. The source and destination key columns (`customer_id`, `product_id`) across `PAGE_EVENT`, `APPLICATION`, and `ACCOUNT` must possess local non-unique indexes. Lacking these access paths, multi-hop graph match patterns executed via `GRAPH_TABLE` degenerate into nested loop joins over full table scans.

### Select AI Profile and Privacy Surface Controls

The natural language generation pipeline utilizes `DBMS_CLOUD_AI.CREATE_PROFILE` to establish the `NUDGE_BOT` profile. The `object_list` parameter acts as a metadata allow-list, restricting the LLM's schema context during natural language to SQL translation or chat completions. The notebook includes `CUSTOMER`, `TXN`, `APPLICATION`, and `CONVERSATION_CHUNK` in this allow-list.

From an enterprise security perspective, exposing the base `CUSTOMER` table introduces compliance risks if columns such as `full_name`, social security numbers, or tax identifiers are accessible. The `object_list` must point to database views that project only necessary business identifiers (`customer_id`, `segment`).


Updated todo list

| Architectural Component | Prototype Notebook Implementation | Production Corrected Implementation | Operational Impact |
|---|---|---|---|
| ONNX Model Import | Unnamed positional syntax via `DBMS_VECTOR.LOAD_ONNX_MODEL` [cite: 1] | Explicit named parameters with JSON tensor mapping: `directory, file_name, model_name, metadata` | Prevents PL/SQL execution errors across Oracle 23ai/26ai patch sets. |
| Vector Metric Alignment | `DISTANCE COSINE` index; manual SQL checks | Enforced `COSINE` operator in query predicates with baseline execution plan checks | Guarantees ANN vector index utilization; prevents full table scans. |
| SQL/PGQ Graph Indexing | Graph defined over base relational tables | Compulsory non-unique B-tree indexes on all `SOURCE_KEY` and `DESTINATION_KEY` columns | Maintains single-digit millisecond latency during multi-hop peer traversals. |
| Schema Metadata Exposure | Direct exposure of `CUSTOMER` table to `DBMS_CLOUD_AI` [cite: 1] | Exposure restricted to least-privilege reporting views omitting personal identifiers | Eliminates NPI leakage during LLM context grounding and prompt construction. |
| MCP Execution Interface | Interactive `SQLcl -mcp` listener running as privileged user | Autonomous MCP daemon operating under dedicated `NUDGE_AGENT` user with restricted grants | Restricts agent actions to audited PL/SQL wrapper procedures. |

## Banking Regulatory and Compliance Governance Framework

Deploying artificial intelligence within consumer banking workflows requires navigating overlapping regulatory regimes. Every automated interaction must maintain an auditable record tracing eligibility, data retrieval, model execution, policy suppression, and disclosure rendering.

The governance execution sequence begins with a trigger event, such as a product page view, an abandoned credit application, or a declined electronic transaction. The engine evaluates deterministic eligibility criteria, checks suppression tables, and applies channel frequency caps. Once cleared, context retrieval pulls look-alike candidate sets via `SQL/PGQ` traversals, fetches relevant historical transcripts using vector distance matching, and retrieves account facts from core relational tables. The prompt generation engine crafts the response using pre-approved templates, executes post-generation disclosure substitution to inject verified statutory language, routes sampled outputs to human review queues, and records complete event metadata across immutable audit tables before dispatching the message to the customer.

### Statutory Framework Mapping

The architecture directly addresses key statutory requirements through database-level controls:

| Statutory Regime | Scope of Application | Architectural Control in Oracle 26ai |
|---|---|---|
| UDAAP (Dodd-Frank Act Title X) | All consumer-facing marketing and servicing messages | Human review queues (`UDAAP_REVIEW_QUEUE`), deterministic template substitution, and immutable text logging (`AI_CALL_LOG`). |
| Equal Credit Opportunity Act (ECOA) / Reg B | Credit card and personal loan eligibility decisioning | Complete exclusion of protected-class characteristics or demographic proxies in `SQL/PGQ` graph traversals and eligibility rules. |
| Fair Credit Reporting Act (FCRA) | Credit application declines or adverse actions | Strict prohibition of LLM-generated explanations for adverse decisions; reliance on deterministic, pre-approved reason codes. |
| Truth in Lending (Reg Z) / Truth in Savings (Reg DD) | Marketing and promotional disclosures (APR, APY, fees) | Mandatory post-generation text processing that replaces LLM tokens with static, legal-approved disclosure blocks (`APPROVED_DISCLOSURES`). |
| Electronic Fund Transfer Act (Reg E) | Servicing notifications following declined electronic transactions | Formal classification of Use Case 3 as a servicing transaction, bypassing marketing suppression filters while respecting channel consent. |
| Gramm-Leach-Bliley Act (GLBA) & PCI-DSS | Non-public Personal Information (NPI) and cardholder data protection | In-database ONNX vector generation ensuring zero transcript data leaves the Autonomous Database (ADB) perimeter; TDE encryption at rest. |
| Telephone Consumer Protection Act (TCPA) / CAN-Spam | Outbound messaging across SMS, Push, and Email channels | Automated policy queries (`OFFER_SUPPRESSION`, `DO_NOT_CONTACT`, `MARKETING_POLICY`) validating opt-in status, rolling frequency caps, and quiet hours. |
| SR 11-7 / OCC 2011-12 | Model Risk Management for embedding models and LLMs | Formal model inventory registration, ONNX binary checksum verification, and daily recall canary testing against ground-truth datasets. |

### Fair Lending Guardrails in Graph and Vector Traversal

Under Reg B and ECOA, utilizing peer data to influence credit product marketing must be carefully governed to avoid discriminatory outcomes. The `SQL/PGQ` traversal pattern deployed in Use Case 1 links customers based purely on product interaction history (`viewed` edges):

```
MATCH (c1 IS customer)-[:viewed]->(p IS product)<-[:viewed]-(c2 IS customer)-[:viewed]->(p2 IS product)
```

This traversal pattern is symmetric and relies exclusively on behavioral interaction vectors. The graph definition explicitly excludes demographic indicators, income tiers, geographic zip codes, or age brackets. If an enterprise introduces demographic attributes into graph nodes, the resulting candidate sets risk generating disparate impact across protected classes. Furthermore, graph outputs must strictly serve candidate discovery for marketing visibility; actual credit extension must be governed by transparent, deterministic credit scoring pipelines.

### hannel-of-Record Segregation and Disclosure Injection

A core architectural requirement is differentiating **marketing communications** from **servicing communications**.

Marketing communications, represented by Use Case 1 (Card Page Views) and Use Case 2 (Abandoned Applications), are subject to strict opt-in verification, CAN-SPAM/TCPA consent checks, global do-not-contact lists, rolling frequency caps, and time-of-day quiet hours. If a customer has opted out of marketing, the pipeline terminates immediately prior to executing vector retrieval or LLM generation.

Servicing communications, represented by Use Case 3 (Declined Transactions), are triggered by electronic transaction failures under Reg E. Servicing messages are exempt from general marketing opt-out preferences because they provide essential operational information regarding account status. However, channel delivery preferences and privacy protections under GLBA remain fully active.

To maintain compliance with Reg Z and Reg DD, the LLM is prohibited from authoring numerical interest rates, annual percentage yields, or fee schedules. The PL/SQL wrapper package (`PKG_NUDGE_ENGINE`) renders prompts using pre-approved static templates containing placeholder tags (e.g., `{{disclosure_block}}`). Following LLM generation, the wrapper performs a deterministic substitution, populating the placeholder with verified legal text retrieved from `APPROVED_DISCLOSURES` based on the targeted `offer_id`.

SQL

```
-- Pattern for post-generation disclosure substitution within PL/SQL
l_final_nudge := REGEXP_REPLACE(
                   l_llm_raw_output, 
                   '\{\{disclosure_block\}\}', 
                   l_approved_disclosure_text
                 );

```

If the generated output lacks the placeholder tag or contains unverified numeric percentage strings outside the disclosure block, the transaction is flagged, rejected, and logged to the `UDAAP_REVIEW_QUEUE` while returning a safe deterministic fallback message to the customer.

## Database Schema, Vector Extensions, and Property Graph Specifications

The operational database design adopts a converged, layered schema architecture. Raw external datasets land in staging structures (`STG_PAYSIM`, `STG_LENDING`, `STG_BANKING77`, `STG_MARKETING`), transform into a normalized relational core (`CUSTOMER`, `ACCOUNT`, `TXN`, `APPLICATION`, `CONVERSATION`), and are extended with vector columns (`CONVERSATION_CHUNK`), property graph overlays (`BANKING_GRAPH`), and natural language profiles (`Select AI NUDGE_BOT`).

### Relational Core and Vector Extension Specifications

The underlying relational schema tracks core entities: customers, accounts, transactions, applications, page events, and support conversations. Unstructured conversation transcripts are segmented into discrete chunks within `CONVERSATION_CHUNK` and augmented with native `VECTOR` datatypes.

SQL

```
-- Core Relational Tables
CREATE TABLE customer (
  customer_id    NUMBER PRIMARY KEY,
  full_name      VARCHAR2(120),
  segment        VARCHAR2(40),
  signup_date    DATE
);

CREATE TABLE product (
  product_id     NUMBER PRIMARY KEY,
  name           VARCHAR2(120),
  family         VARCHAR2(40),
  details_blob   BLOB,
  details_text   CLOB
);

CREATE TABLE offer (
  offer_id          NUMBER PRIMARY KEY,
  product_id        NUMBER REFERENCES product(product_id),
  offer_name        VARCHAR2(120),
  eligibility_rule  VARCHAR2(400),
  outcome_label     VARCHAR2(40)
);

CREATE TABLE account (
  account_id     NUMBER PRIMARY KEY,
  customer_id    NUMBER REFERENCES customer(customer_id),
  product_id     NUMBER REFERENCES product(product_id),
  daily_limit    NUMBER,
  opened_at      DATE
);

CREATE TABLE txn (
  txn_id          NUMBER PRIMARY KEY,
  account_id      NUMBER REFERENCES account(account_id),
  amount          NUMBER,
  status          VARCHAR2(20),
  decline_reason  VARCHAR2(80),
  txn_ts          TIMESTAMP
);

CREATE TABLE application (
  app_id         NUMBER PRIMARY KEY,
  customer_id    NUMBER REFERENCES customer(customer_id),
  product_id     NUMBER REFERENCES product(product_id),
  status         VARCHAR2(20),
  fields_json    JSON,
  updated_at     TIMESTAMP
);

CREATE TABLE page_event (
  event_id       NUMBER PRIMARY KEY,
  customer_id    NUMBER REFERENCES customer(customer_id),
  product_id     NUMBER REFERENCES product(product_id),
  page_url       VARCHAR2(400),
  event_ts       TIMESTAMP
);

CREATE TABLE conversation (
  conv_id        NUMBER PRIMARY KEY,
  customer_id    NUMBER REFERENCES customer(customer_id),
  channel        VARCHAR2(20),
  transcript     CLOB,
  conv_ts        TIMESTAMP
);

-- AI Extension: Vectorized Conversation Chunks
CREATE TABLE conversation_chunk (
  chunk_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  conv_id        NUMBER REFERENCES conversation(conv_id),
  chunk_text     VARCHAR2(4000),
  embedding      VECTOR(384, FLOAT32)
);

-- In-Database Vector Index (IVF Neighborhood Partitions)
CREATE VECTOR INDEX conv_chunk_idx
ON conversation_chunk(embedding)
ORGANIZATION NEIGHBOR PARTITIONS
DISTANCE COSINE
WITH TARGET ACCURACY 90;

```

### Property Graph DDL (`SQL/PGQ`)

The property graph overlay abstracts complex relational joins into a declarative graph structure without duplicating physical storage:

SQL

```
CREATE PROPERTY GRAPH banking_graph
  VERTEX TABLES (
    customer KEY (customer_id) LABEL customer PROPERTIES (full_name, segment),
    product  KEY (product_id)  LABEL product  PROPERTIES (name, family),
    account  KEY (account_id)  LABEL account  PROPERTIES (daily_limit)
  )
  EDGE TABLES (
    account
      SOURCE KEY (customer_id) REFERENCES customer
      DESTINATION KEY (product_id) REFERENCES product
      LABEL holds,
    page_event
      KEY (event_id)
      SOURCE KEY (customer_id) REFERENCES customer
      DESTINATION KEY (product_id) REFERENCES product
      LABEL viewed PROPERTIES (event_ts),
    application
      KEY (app_id)
      SOURCE KEY (customer_id) REFERENCES customer
      DESTINATION KEY (product_id) REFERENCES product
      LABEL applied_for PROPERTIES (status)
  );

```

### Audit and Decision Governance Infrastructure

To maintain complete operational lineage for regulatory review, dedicated audit logging tables capture every decision attempt and LLM invocation:

SQL

```
CREATE TABLE ai_call_log (
  call_id            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at         TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  customer_id        NUMBER,
  use_case           VARCHAR2(30),
  offer_id           NUMBER,
  channel            VARCHAR2(20),
  channel_of_record  VARCHAR2(20),
  profile_name       VARCHAR2(128),
  model_name         VARCHAR2(256),
  model_version      VARCHAR2(64),
  trace_id           VARCHAR2(64),
  span_id            VARCHAR2(32),
  prompt_template_id VARCHAR2(64),
  prompt_hash        VARCHAR2(128),
  prompt_tokens      NUMBER,
  output_tokens      NUMBER,
  output_hash        VARCHAR2(128),
  output_text        CLOB,
  disclosure_id      VARCHAR2(64),
  suppression_check  VARCHAR2(20),
  optin_check        VARCHAR2(20),
  freq_cap_check     VARCHAR2(20),
  control_group      VARCHAR2(20),
  review_queue_id    NUMBER,
  status             VARCHAR2(20),
  error_text         VARCHAR2(4000),
  retention_until    DATE
);

CREATE TABLE offer_decision_log (
  decision_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  decided_at         TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  customer_id        NUMBER,
  use_case           VARCHAR2(30),
  trigger_event_id   NUMBER,
  candidate_offers   VARCHAR2(400),
  chosen_offer_id    NUMBER,
  decision           VARCHAR2(30),
  decision_reason    VARCHAR2(400),
  channel            VARCHAR2(20),
  channel_of_record  VARCHAR2(20),
  control_group      VARCHAR2(20),
  ai_call_id         NUMBER,
  trace_id           VARCHAR2(64),
  retention_until    DATE
);

CREATE TABLE offer_suppression (
  customer_id NUMBER,
  channel     VARCHAR2(20),
  reason      VARCHAR2(200),
  created_at  TIMESTAMP DEFAULT SYSTIMESTAMP,
  PRIMARY KEY (customer_id, channel)
);

CREATE TABLE do_not_contact (
  customer_id NUMBER PRIMARY KEY,
  reason      VARCHAR2(200),
  created_at  TIMESTAMP DEFAULT SYSTIMESTAMP
);

CREATE TABLE marketing_policy (
  policy_id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  channel            VARCHAR2(20),
  freq_cap           NUMBER,
  freq_cap_window    INTERVAL DAY TO SECOND,
  quiet_hours_start  NUMBER,
  quiet_hours_end    NUMBER,
  effective_from     TIMESTAMP DEFAULT SYSTIMESTAMP
);

CREATE TABLE approved_disclosures (
  disclosure_id   VARCHAR2(64) PRIMARY KEY,
  offer_id        NUMBER,
  effective_date  DATE,
  disclosure_text CLOB,
  created_by      VARCHAR2(64),
  approved_at     TIMESTAMP
);

CREATE TABLE udaap_review_queue (
  review_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  call_id      NUMBER,
  reason       VARCHAR2(40),
  state        VARCHAR2(20) DEFAULT 'PENDING',
  reviewer     VARCHAR2(64),
  reviewed_at  TIMESTAMP,
  notes        VARCHAR2(4000)
);

CREATE INDEX ai_call_log_cust_ix ON ai_call_log(customer_id, created_at);
CREATE INDEX ai_call_log_trace_ix ON ai_call_log(trace_id);
CREATE INDEX odl_cust_ix ON offer_decision_log(customer_id, decided_at);
CREATE INDEX odl_trace_ix ON offer_decision_log(trace_id);

```

## Implementation Blueprint for Core Use Cases

The target system executes three real-time banking nudge use cases, each combining relational state, graph traversals, vector retrieval, and policy controls.

### Use Case 1: Credit Card Page View Nudge

When a customer views a credit card product page, the engine identifies relevant peer products via graph traversal, retrieves historical interaction context using vector distance, and ranks candidates for nudge presentation.

SQL

```
WITH last_view AS (
  SELECT product_id
  FROM page_event
  WHERE customer_id = :cid
  ORDER BY event_ts DESC
  FETCH FIRST 1 ROW ONLY
),
peer_products AS (
  SELECT *
  FROM GRAPH_TABLE(
    banking_graph
    MATCH (c1 IS customer)-[:viewed]->(p IS product)<-[:viewed]-(c2 IS customer)-[:viewed]->(p2 IS product)
    WHERE c1.customer_id = :cid
      AND p.product_id = (SELECT product_id FROM last_view)
    COLUMNS (
      p2.product_id AS peer_product_id,
      p2.name AS peer_product
    )
  )
)
SELECT p.peer_product,
       cc.chunk_text,
       VECTOR_DISTANCE(
         cc.embedding,
         VECTOR_EMBEDDING(MINILM_EMB USING 'credit card comparison help' AS DATA),
         COSINE
       ) AS distance
FROM conversation_chunk cc
CROSS JOIN peer_products p
ORDER BY distance
FETCH FIRST 5 ROWS ONLY;

```

### Use Case 2: Abandoned Application Recovery

Applications in `STARTED` status that have remained un-updated for over one hour are surfaced. The query parses application details stored in JSON and performs a semantic similarity search across past customer service transcripts to surface contextually appropriate recovery copy.

SQL

```
WITH abandoned AS (
  SELECT a.app_id, 
         a.customer_id, 
         a.product_id, 
         a.updated_at, 
         JSON_VALUE(a.fields_json, '$.purpose') AS loan_purpose
  FROM application a
  WHERE a.status = 'STARTED'
    AND a.updated_at < SYSTIMESTAMP - INTERVAL '1' HOUR
)
SELECT ab.app_id, 
       ab.customer_id, 
       p.name AS product_name, 
       ab.loan_purpose,
       cc.chunk_text,
       VECTOR_DISTANCE(
         cc.embedding,
         VECTOR_EMBEDDING(MINILM_EMB USING 'application abandoned income verification step' AS DATA),
         COSINE
       ) AS distance
FROM abandoned ab
JOIN product p ON p.product_id = ab.product_id
CROSS JOIN conversation_chunk cc
ORDER BY distance
FETCH FIRST 10 ROWS ONLY;

```

### Use Case 3: Declined Transaction Servicing Nudge

A declined point-of-sale transaction triggers an immediate servicing response under Reg E. The pipeline synthesizes transaction decline metadata and executes a governed call to `DBMS_CLOUD_AI` to generate clear, policy-safe resolution instructions.

SQL

```
DECLARE
  v_txn_id         NUMBER := :target_txn_id;
  v_customer_id    NUMBER;
  v_amount         NUMBER;
  v_decline_reason VARCHAR2(80);
  v_segment        VARCHAR2(40);
  v_prompt         VARCHAR2(4000);
  v_generated_text CLOB;
  v_trace_id       VARCHAR2(64) := SYS_GUID();
BEGIN
  -- Extract Transaction and Customer Context
  SELECT t.amount, t.decline_reason, c.customer_id, c.segment
  INTO v_amount, v_decline_reason, v_customer_id, v_segment
  FROM txn t
  JOIN account a ON a.account_id = t.account_id
  JOIN customer c ON c.customer_id = a.customer_id
  WHERE t.txn_id = v_txn_id AND t.status = 'DECLINED';

  -- Construct Grounded Prompt Structure
  v_prompt := 'Customer ' || v_customer_id || ' (' || v_segment || ' segment) ' ||
              'experienced a declined transaction of $' || TO_CHAR(v_amount, '999,990.00') || ' ' ||
              'due to reason: ' || v_decline_reason || '. ' ||
              'Generate a one-sentence, clear, non-deceptive servicing explanation and next step.';

  -- Execute Governed Generation via Select AI Profile
  DBMS_CLOUD_AI.SET_PROFILE('NUDGE_BOT');
  v_generated_text := DBMS_CLOUD_AI.GENERATE(prompt => v_prompt, action => 'chat');

  -- Audit Interaction
  INSERT INTO ai_call_log (
    customer_id, use_case, channel, channel_of_record, profile_name,
    trace_id, output_text, status, retention_until
  ) VALUES (
    v_customer_id, 'UC3_DECLINE_SERVICING', 'IN_APP_SERVICING', 'SERVICING', 'NUDGE_BOT',
    v_trace_id, v_generated_text, 'OK', ADD_MONTHS(SYSDATE, 84)
  );
  
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    -- Fallback to pre-approved static servicing text on failure
    v_generated_text := 'Your recent transaction was declined due to account limits. Please log in to adjust settings or contact support.';
    INSERT INTO ai_call_log (
      customer_id, use_case, trace_id, status, error_text, output_text
    ) VALUES (
      v_customer_id, 'UC3_DECLINE_SERVICING', v_trace_id, 'FALLBACK', SQLERRM, v_generated_text
    );
    COMMIT;
END;
/

```

## Integration Architecture: APEX, MCP Agentic Framework, and Microservices

To serve business users, autonomous agents, and microservices, the database exposes controlled interfaces while preventing direct, un-audited schema access.

### APEX PL/SQL API Layer

Oracle Application Express (APEX) interfaces directly with PL/SQL API packages, allowing front-end chat components to trigger nudge pipelines securely.

SQL

```
CREATE OR REPLACE PACKAGE nudge_chat_api AS
  FUNCTION get_nudge(p_use_case IN VARCHAR2, p_customer_id IN NUMBER) RETURN CLOB;
END nudge_chat_api;
/

CREATE OR REPLACE PACKAGE BODY nudge_chat_api AS
  FUNCTION get_nudge(p_use_case IN VARCHAR2, p_customer_id IN NUMBER) RETURN CLOB IS
    l_out CLOB;
  BEGIN
    IF p_use_case = 'UC1' THEN
      SELECT TO_CLOB('We noticed you viewed a card product recently. Would you like to compare features?')
      INTO l_out FROM dual;
    ELSIF p_use_case = 'UC2' THEN
      SELECT TO_CLOB('Your credit application is saved. Would you like assistance completing the final step?')
      INTO l_out FROM dual;
    ELSIF p_use_case = 'UC3' THEN
      DBMS_CLOUD_AI.SET_PROFILE('NUDGE_BOT');
      SELECT DBMS_CLOUD_AI.GENERATE(
               prompt => 'Customer ' || p_customer_id || ' experienced a declined transaction. Craft a one-sentence servicing explanation.',
               action => 'chat'
             )
      INTO l_out FROM dual;
    ELSE
      l_out := TO_CLOB('Invalid request: Unknown use case specified.');
    END IF;
    RETURN l_out;
  END get_nudge;
END nudge_chat_api;
/

```

### Model Context Protocol (MCP) as a Policy Enforcement Point

The Model Context Protocol (MCP), executed via SQLcl (`sql -mcp`), exposes predefined PL/SQL wrapper functions as typed "tools" to agentic frameworks (such as Anthropic Claude Desktop or LangChain agents). Rather than granting an agent standard database credentials to execute ad-hoc SQL, MCP acts as a Policy Enforcement Point (PEP).

The integration flow relies on strict privilege boundaries. The agentic framework sends a tool invocation request over the MCP protocol to the SQLcl MCP server. The SQLcl daemon authenticates to Oracle Database 26ai using a dedicated, least-privilege `NUDGE_AGENT` database user. The database executes only pre-approved PL/SQL wrapper packages, preventing arbitrary SQL execution or data extraction.

SQL

```
-- Least-Privilege NUDGE_AGENT Provisioning
CREATE USER nudge_agent IDENTIFIED BY "Complex_Password_2026#";
ALTER USER nudge_agent DEFAULT TABLESPACE users QUOTA 0 ON users;
GRANT CONNECT TO nudge_agent;

-- Restrict privileges exclusively to named tool procedures
GRANT EXECUTE ON pkg_nudge_tools TO nudge_agent;

```

The tool catalog exposed via MCP enforces business policy deterministically:

-   `peer_products(cid, limit)`: Invokes PGQ look-alike graph logic.
    
-   `recent_declines(cid, lookback_hours)`: Fetches decline records for servicing.
    
-   `similar_chunks(query_text, top_k, customer_id)`: Performs vector search while automatically injecting customer opt-in filters.
    
-   `is_suppressed(cid, channel, use_case)`: Executes mandatory suppression, opt-out, frequency-cap, and quiet-hour evaluations.
    
-   `generate_nudge(...)`: Wraps `DBMS_CLOUD_AI` execution inside mandatory disclosure substitution and logging routines.
    

### Spring Boot Service Tier Integration

In enterprise Java applications, the Spring tier integrates via standard HikariCP connection pools configured with Oracle Wallet credentials. Connection initialization sets the active Select AI profile automatically:

YAML

```
# application.yml
spring:
  datasource:
    url: jdbc:oracle:thin:@nudgedb_high?TNS_ADMIN=/etc/oracle/wallets
    username: NUDGE_APP_USER
    password: ${DB_PASSWORD}
    driver-class-name: oracle.jdbc.OracleDriver
    hikari:
      connection-init-sql: BEGIN DBMS_CLOUD_AI.SET_PROFILE('NUDGE_BOT'); END;
      maximum-pool-size: 20

```

Java repositories execute use-case queries via standard `JdbcTemplate` or JPA native queries, propagating W3C `traceparent` headers into database calls to maintain end-to-end distributed tracing across OpenTelemetry spans.

## Operationalization, Capacity Planning, and Governance Framework

Operating converged vector and graph workloads alongside traditional OLTP transactions requires clear sizing formulas, monitoring strategies, and launch-readiness controls.

### Capacity Planning and Vector Sizing Math

Vector storage calculations depend on dimension count ($dims$) and numeric precision. For `FLOAT32` representations, each dimension consumes 4 bytes.

$$\text{Bytes Per Vector} = dims \times 4$$

$$\text{Raw Data Footprint} = N \times dims \times 4$$

To establish total database storage requirements, operational multipliers must be applied:

$$\text{Total Storage} = \left( \text{Raw Data Footprint} \times M_{\text{segment}} \right) + \left( \text{Raw Data Footprint} \times M_{\text{index}} \right) + \text{Headroom}$$

Where $M_{\text{segment}}$ represents table overhead ($1.2\times$ to $1.5\times$ for block headers and PCTFREE reservations), $M_{\text{index}}$ represents index overhead ($0.5\times$ to $1.5\times$ depending on index type), and $\text{Headroom}$ provides a $30\%$ safety margin for index rebuilds and operational spikes.

Applying this formula to a production corpus of 2,000,000 vectors across 384 dimensions yielded the following storage footprint: each vector consumes 1,536 bytes ($384 \times 4$), establishing a raw data mass of approximately $3.07\text{ GB}$ ($2,000,000 \times 1,536\text{ bytes}$). Applying a $1.3\times$ table segment multiplier results in a $3.99\text{ GB}$ table segment, while an Inverted File (`IVF`) vector index adds $3.07\text{ GB}$ ($1.0\times$ index multiplier). Adding a $30\%$ operational headroom margin establishes a final provisioned allocation requirement of approximately $9.18\text{ GB}$.

### Vector Index Architecture: IVF vs. HNSW Comparison

Choosing between Inverted File (`IVF`) and Hierarchical Navigable Small World (`HNSW`) vector indexes involves tradeoffs between memory utilization, build latency, and recall accuracy.

Updated todo list

| Operational Metric | Inverted File (IVF / `NEIGHBOR PARTITIONS`) | Navigable Small World (HNSW / `INMEMORY NEIGHBOR GRAPH`) |
|---|---|---|
| Memory Footprint | Low; resides primarily on disk segments and standard buffer cache. | High; requires contiguous allocation in System Global Area (SGA) Vector Pool. |
| Build Latency | Fast; partitions vector space into discrete centroid clusters. | Slower; constructs multi-layer graph networks connecting nearest neighbors. |
| Filtered Search Efficiency | Excellent when combined with highly selective SQL relational predicates. | Degrades if heavy pre-filtering invalidates graph routing paths. |
| Recall @ K Performance | High (90% – 95% with target accuracy tuning). | Exceptional (98% – 99%+). |
| Target Banking Use Case | UC1 & UC2: Ideal for high-cardinality, multi-tenant datasets filtered by `customer_id`. | UC3: Ideal for ultra-low latency, unfiltered top-K similarity matching. |

### Observability, Performance Tuning, and Model Risk (SR 11-7)

Monitoring converged workloads requires tracking both standard database execution metrics and AI-specific indicators. Database administrators must regularly inspect cursor execution plans using `DBMS_XPLAN` to confirm vector index activation:

SQL

```
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST'));

```

The execution plan must explicitly contain `VECTOR INDEX SCAN (APPROXIMATE)`. If `TABLE ACCESS FULL` appears on `CONVERSATION_CHUNK`, the optimizer has rejected the index, leading to query degradation. SQL Plan Baselines (`DBMS_SPM`) must be captured for canonical queries across all three use cases to lock in optimal execution strategies.

To fulfill Model Risk Management requirements under SR 11-7, the embedding pipeline must undergo daily accuracy testing. An automated batch job executes a set of benchmark query strings against `CONVERSATION_CHUNK`, comparing approximate nearest-neighbor results from the vector index against exact brute-force cosine distances calculated without an index. If recall@K drops below $90\%$, an alert triggers, signaling vector index degradation or embedding drift.

Batch re-embedding jobs or runaway LLM queries must not starve core online transaction processing (OLTP) activity. The database Resource Manager confines background AI processing to dedicated consumer groups:

SQL

```
BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_CONSUMER_GROUP(
    consumer_group => 'NUDGE_AI_BATCH_CG',
    comment => 'Resource group for vector embedding and batch AI generation'
  );
  DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(
    plan => 'DEFAULT_PLAN',
    group_or_subplan => 'NUDGE_AI_BATCH_CG',
    mgmt_p1 => 10,  -- Cap CPU utilization to max 10% during peak hours
    switch_group => 'CANCEL_SQL',
    switch_time => 15 -- Terminate queries exceeding 15s execution time
  );
END;
/

```

### Launch-Readiness Sign-Off Matrix

Before deploying proactive nudges to production, all operational and regulatory readiness criteria must be satisfied:

<!--stackedit_data:
eyJoaXN0b3J5IjpbMTIwMjYyNTA3MCwtNDUyOTE1ODU3LC0xNj
U1NTY5Njc5XX0=
-->