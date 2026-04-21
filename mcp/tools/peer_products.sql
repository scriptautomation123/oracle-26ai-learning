-- @tool name=peer_products
-- @desc Returns products that customers similar to :cid recently viewed.
-- @param cid NUMBER required Customer ID
-- @param limit NUMBER optional Max rows (default 10)

SELECT *
FROM GRAPH_TABLE(
  banking_graph
  MATCH (c1 IS customer)-[:viewed]->(p IS product)<-[:viewed]-(c2 IS customer)-[:viewed]->(p2 IS product)
  WHERE c1.customer_id = :cid
  COLUMNS (p2.product_id AS peer_product_id, p2.name AS peer_product)
)
FETCH FIRST NVL(:limit, 10) ROWS ONLY;
