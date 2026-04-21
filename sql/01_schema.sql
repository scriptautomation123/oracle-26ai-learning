-- 01_schema.sql
-- Purpose: Create core POC relational schema with BLOB/CLOB/JSON/VECTOR columns.
-- Prerequisite: Run first on an empty or dedicated Oracle Autonomous Database 23ai/26ai schema.

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

CREATE TABLE conversation_chunk (
  chunk_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  conv_id        NUMBER REFERENCES conversation(conv_id),
  chunk_text     VARCHAR2(4000),
  embedding      VECTOR(384, FLOAT32)
);
