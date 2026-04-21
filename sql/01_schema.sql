-- 01_schema.sql
-- Purpose: Create core POC schema objects.
-- Run order: 1
-- Dependencies: None

CREATE TABLE customer (
  customer_id   NUMBER PRIMARY KEY,
  full_name     VARCHAR2(120),
  segment       VARCHAR2(40),
  signup_date   DATE
);

CREATE TABLE product (
  product_id    NUMBER PRIMARY KEY,
  name          VARCHAR2(120),
  family        VARCHAR2(40),
  details_blob  BLOB,
  details_text  CLOB
);

CREATE TABLE account (
  account_id    NUMBER PRIMARY KEY,
  customer_id   NUMBER REFERENCES customer,
  product_id    NUMBER REFERENCES product,
  daily_limit   NUMBER,
  opened_at     DATE
);

CREATE TABLE txn (
  txn_id        NUMBER PRIMARY KEY,
  account_id    NUMBER REFERENCES account,
  amount        NUMBER,
  status        VARCHAR2(20),
  decline_reason VARCHAR2(80),
  txn_ts        TIMESTAMP
);

CREATE TABLE application (
  app_id        NUMBER PRIMARY KEY,
  customer_id   NUMBER REFERENCES customer,
  product_id    NUMBER REFERENCES product,
  status        VARCHAR2(20),
  fields_json   JSON,
  updated_at    TIMESTAMP
);

CREATE TABLE page_event (
  event_id      NUMBER PRIMARY KEY,
  customer_id   NUMBER REFERENCES customer,
  product_id    NUMBER REFERENCES product,
  page_url      VARCHAR2(400),
  event_ts      TIMESTAMP
);

CREATE TABLE conversation (
  conv_id       NUMBER PRIMARY KEY,
  customer_id   NUMBER REFERENCES customer,
  channel       VARCHAR2(20),
  transcript    CLOB,
  conv_ts       TIMESTAMP
);

CREATE TABLE conversation_chunk (
  chunk_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  conv_id        NUMBER REFERENCES conversation,
  chunk_text     VARCHAR2(4000),
  embedding      VECTOR(384, FLOAT32)
);

CREATE TABLE offer (
  offer_id        NUMBER PRIMARY KEY,
  product_id      NUMBER REFERENCES product,
  offer_name      VARCHAR2(120),
  offer_channel   VARCHAR2(30),
  conversion_flag VARCHAR2(5),
  created_at      TIMESTAMP
);
