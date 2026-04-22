-- lab02_graphs.sql
-- Module 2 — SQL/PGQ + Property Graphs
-- Verifies BANKING_GRAPH definition and flags fair-lending / ECOA controls.

DECLARE
  v_ddl CLOB;
  v_sqlpgq_tokens NUMBER;
  v_sql_tokens NUMBER;
  v_ok NUMBER := 0;
  v_cnt NUMBER;
  c INTEGER;
BEGIN
  SELECT DBMS_METADATA.GET_DDL('PROPERTY_GRAPH', 'BANKING_GRAPH') INTO v_ddl FROM dual;

  IF INSTR(UPPER(v_ddl), 'ACCOUNT KEY (ACCOUNT_ID)') > 0
     AND INSTR(UPPER(v_ddl), 'EDGE TABLES') > 0
     AND INSTR(UPPER(v_ddl), CHR(10) || '    ACCOUNT') > 0 THEN
    v_ok := 1;
  END IF;

  lab_assert('M2', 'ACCOUNT participates as vertex and edge', v_ok = 1, NULL);

  -- ECOA / Reg B guard: no protected-class attribute should be exposed as a
  -- graph property. Common direct names checked here. Proxies (ZIP, surname,
  -- age) are flagged as MANUAL because they require Compliance review.
  IF INSTR(UPPER(v_ddl), 'PROPERTIES') > 0
     AND (INSTR(UPPER(v_ddl), 'RACE') > 0
          OR INSTR(UPPER(v_ddl), 'ETHNICITY') > 0
          OR INSTR(UPPER(v_ddl), 'RELIGION') > 0
          OR INSTR(UPPER(v_ddl), 'GENDER') > 0
          OR INSTR(UPPER(v_ddl), 'MARITAL') > 0
          OR INSTR(UPPER(v_ddl), 'NATIONAL_ORIGIN') > 0)
  THEN
    lab_assert('M2', 'BANKING_GRAPH exposes no direct protected-class properties (ECOA/Reg B)',
               FALSE, 'protected-class attribute name detected in graph DDL');
  ELSE
    lab_assert('M2', 'BANKING_GRAPH exposes no direct protected-class properties (ECOA/Reg B)',
               TRUE, NULL);
  END IF;

  -- Data minimization: full_name on customer vertex is unnecessary for any
  -- shipped graph query in the demo. Flag if present.
  IF INSTR(UPPER(v_ddl), 'FULL_NAME') > 0 THEN
    lab_manual('M2', 'Remove CUSTOMER.full_name from BANKING_GRAPH vertex properties',
               'Data minimization: no shipped graph traversal needs full_name. Drop it from PROPERTIES().');
  ELSE
    lab_assert('M2', 'CUSTOMER.full_name is not exposed on the graph surface', TRUE, NULL);
  END IF;

  v_sqlpgq_tokens := REGEXP_COUNT(
    'SELECT * FROM GRAPH_TABLE(banking_graph MATCH (c IS customer)-[:viewed]->(p IS product) COLUMNS (p.product_id))',
    '[[:alnum:]_]+');
  v_sql_tokens := REGEXP_COUNT(
    'SELECT p.product_id FROM page_event pe JOIN product p ON p.product_id = pe.product_id JOIN customer c ON c.customer_id = pe.customer_id',
    '[[:alnum:]_]+');

  lab_assert('M2', 'SQL/PGQ token count <= equivalent SQL token count',
             v_sqlpgq_tokens <= v_sql_tokens,
             'pgq=' || v_sqlpgq_tokens || ', sql=' || v_sql_tokens);

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
    AND column_name IN ('CUSTOMER_ID','PRODUCT_ID');

  lab_assert('M2', 'FK columns for SOURCE/DESTINATION KEY are indexed', v_cnt = 2,
             'indexed columns found=' || v_cnt);

  lab_manual('M2', 'Compliance sign-off on CUSTOMER.segment derivation (proxy review)',
             'segment is exposed as a vertex property. Document how segment is derived (income? ZIP? age?) and obtain ECOA/fair-lending sign-off before any credit-product graph use.');
  lab_manual('M2', 'Approved peer-traversal patterns documented (Compliance-reviewed)',
             'List the GRAPH_TABLE MATCH patterns approved for production. Patterns must be symmetric on viewed/applied_for and must not filter by protected-class proxies.');
  lab_manual('M2', 'Multi-hop guard in wrapper package',
             'Confirm the wrapper that exposes graph traversals caps hops and enforces FETCH FIRST.');
  lab_manual('M2', 'Whiteboard 1-hop and 2-hop traversal translation for review board',
             'Cover plain-English translation auditors and Compliance can read.');
EXCEPTION
  WHEN OTHERS THEN
    IF DBMS_SQL.IS_OPEN(c) THEN
      DBMS_SQL.CLOSE_CURSOR(c);
    END IF;
    lab_assert('M2', 'Module 2 execution', FALSE, SQLERRM);
END;
/
