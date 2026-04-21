-- lab02_graphs.sql

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

  lab_manual('M2', 'Explain graph pattern to review board', 'Whiteboard 1-hop and 2-hop traversal translation.');
EXCEPTION
  WHEN OTHERS THEN
    IF DBMS_SQL.IS_OPEN(c) THEN
      DBMS_SQL.CLOSE_CURSOR(c);
    END IF;
    lab_assert('M2', 'Module 2 execution', FALSE, SQLERRM);
END;
/
