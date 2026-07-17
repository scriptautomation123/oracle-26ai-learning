-- 07_property_graph.sql
-- Purpose: Define a property graph over relational customer/account/product/page/application data.
-- Prerequisite: Run after 05_transform.sql.

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
