package com.oracle.nudges.examples.spring;

import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
public class NudgeRepository {

    private final JdbcTemplate jdbcTemplate;
    private final JdbcClient jdbcClient;

    public NudgeRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
        this.jdbcClient = JdbcClient.create(jdbcTemplate);
    }

    public List<UC1Row> uc1PeerProductsAndVectorRank(long customerId, int topK) {
        String sql = """
            WITH last_view AS (
              SELECT product_id
              FROM page_event
              WHERE customer_id = ?
              ORDER BY event_ts DESC
              FETCH FIRST 1 ROW ONLY
            ),
            peer_products AS (
              SELECT *
              FROM GRAPH_TABLE(
                banking_graph
                MATCH (c1 IS customer)-[:viewed]->(p IS product)<-[:viewed]-(c2 IS customer)-[:viewed]->(p2 IS product)
                WHERE c1.customer_id = ?
                  AND p.product_id = (SELECT product_id FROM last_view)
                COLUMNS (p2.product_id AS peer_product_id, p2.name AS peer_product)
              )
            )
            SELECT p.peer_product_id,
                   p.peer_product,
                   cc.chunk_id,
                   cc.chunk_text,
                   VECTOR_DISTANCE(
                     cc.embedding,
                     VECTOR_EMBEDDING(MINILM_EMB USING 'credit card comparison help' AS DATA),
                     COSINE
                   ) AS distance
            FROM peer_products p
            CROSS JOIN conversation_chunk cc
            ORDER BY distance
            FETCH FIRST ? ROWS ONLY
            """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new UC1Row(
                rs.getLong("peer_product_id"),
                rs.getString("peer_product"),
                rs.getLong("chunk_id"),
                rs.getString("chunk_text"),
                rs.getDouble("distance")
            ), customerId, customerId, topK);
    }

    public List<UC2Row> uc2AbandonedAppsAndVectorRank(int topK) {
        String sql = """
            WITH abandoned AS (
              SELECT a.app_id,
                     a.customer_id,
                     a.product_id,
                     a.updated_at
              FROM application a
              WHERE a.status = 'STARTED'
                AND a.updated_at < SYSTIMESTAMP - INTERVAL '1' HOUR
            )
            SELECT ab.app_id,
                   ab.customer_id,
                   p.product_id,
                   p.name AS product_name,
                   cc.chunk_id,
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
            FETCH FIRST ? ROWS ONLY
            """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new UC2Row(
                rs.getLong("app_id"),
                rs.getLong("customer_id"),
                rs.getLong("product_id"),
                rs.getString("product_name"),
                rs.getLong("chunk_id"),
                rs.getString("chunk_text"),
                rs.getDouble("distance")
            ), topK);
    }

    public String uc3GenerateNudge(long customerId, long txnId) {
        String prompt = "Customer " + customerId + " had declined transaction " + txnId
            + ". Explain likely cause and propose a compliant, empathetic next-step nudge.";

        return jdbcClient.sql("SELECT DBMS_CLOUD_AI.GENERATE(prompt => ?, action => 'chat') AS nudge FROM dual")
            .param(prompt)
            .query(String.class)
            .single();
    }

    public record UC1Row(long peerProductId, String peerProduct, long chunkId, String chunkText, double distance) {}

    public record UC2Row(long appId, long customerId, long productId, String productName,
                         long chunkId, String chunkText, double distance) {}
}
