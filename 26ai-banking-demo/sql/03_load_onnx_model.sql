-- 03_load_onnx_model.sql
-- Purpose: Download and register all_MiniLM_L6_v2 ONNX model for in-database embeddings.
-- Prerequisite: Run after 01_schema.sql. Requires DBMS_CLOUD and DBMS_VECTOR privileges.

BEGIN
  DBMS_CLOUD.GET_OBJECT(
    credential_name => NULL,
    object_uri => 'https://objectstorage.us-phoenix-1.oraclecloud.com/n/adwc4pm/b/OML-Resources/o/all_MiniLM_L6_v2.onnx',
    directory_name => 'DATA_PUMP_DIR'
  );
END;
/

EXEC DBMS_VECTOR.LOAD_ONNX_MODEL(
  'DATA_PUMP_DIR',
  'all_MiniLM_L6_v2.onnx',
  'MINILM_EMB',
  JSON('{"function":"embedding","embeddingOutput":"embedding","input":{"input":["DATA"]}}')
);
