-- 07_property_graph.sql
-- Purpose: Build property graph over customer/product/account/application/page events.
-- Run order: 7
-- Dependencies: sql/01_schema.sql, sql/05_transform.sql

CREATE PROPERTY GRAPH banking_graph
  VERTEX TABLES (
    customer KEY (customer_id) LABEL customer PROPERTIES (full_name, segment),
    product  KEY (product_id)  LABEL product  PROPERTIES (name, family),
    account  KEY (account_id)  LABEL account  PROPERTIES (daily_limit, opened_at)
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
      LABEL applied_for PROPERTIES (status, updated_at)
  );
