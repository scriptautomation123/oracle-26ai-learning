-- lab02_graphs.sql
-- Module 2 - SQL/PGQ and Property Graphs
-- Verifies BANKING_GRAPH and the fair-lending guard surface.

DECLARE
  v_ddl CLOB;
  v_cnt NUMBER;
  c INTEGER;
BEGIN
  SELECT DBMS_METADATA.GET_DDL('PROPERTY_GRAPH', 'BANKING_GRAPH') INTO v_ddl FROM dual;

  lab_assert('M2', 'BANKING_GRAPH DDL exists', v_ddl IS NOT NULL, NULL);

  IF INSTR(UPPER(v_ddl), 'FULL_NAME') > 0 THEN
    lab_manual('M2', 'Remove CUSTOMER.full_name from BANKING_GRAPH vertex properties',
               'Expose only the properties a traversal actually needs.');
  ELSE
    lab_assert('M2', 'CUSTOMER.full_name is not exposed on the graph surface', TRUE, NULL);
  END IF;

  IF INSTR(UPPER(v_ddl), 'SEGMENT') > 0 THEN
    lab_manual('M2', 'Compliance review for CUSTOMER.segment derivation',
               'If segment uses ZIP, age, or income proxies, treat it as a fair-lending review item.');
  ELSE
    lab_assert('M2', 'BANKING_GRAPH does not expose segment directly', TRUE, NULL);
  END IF;

  c := DBMS_SQL.OPEN_CURSOR;
  DBMS_SQL.PARSE(c,
    q'[SELECT *
       FROM GRAPH_TABLE(
         banking_graph
         MATCH (c IS customer)-[:viewed]->(p IS product)
         COLUMNS (c.customer_id AS customer_id, p.product_id AS product_id)
       )
       FETCH FIRST 1 ROW ONLY]',
    DBMS_SQL.NATIVE);
  DBMS_SQL.CLOSE_CURSOR(c);

  lab_assert('M2', 'DBMS_SQL can parse a 1-hop GRAPH_TABLE query', TRUE, NULL);

  SELECT COUNT(*) INTO v_cnt
  FROM user_ind_columns
  WHERE table_name = 'PAGE_EVENT'
    AND column_name IN ('CUSTOMER_ID', 'PRODUCT_ID');

  lab_assert('M2', 'FK columns for source/destination key are indexed', v_cnt = 2,
             'indexed columns found=' || v_cnt);

  lab_manual('M2', 'Approved peer-traversal patterns documented',
             'List the graph patterns approved for production and keep them symmetric on viewed/applied_for.');
  lab_manual('M2', 'Wrapper hop guard in place',
             'Confirm graph traversals are capped and cannot expand indefinitely.');
END;
/