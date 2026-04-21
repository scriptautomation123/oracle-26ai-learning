-- 03_load_onnx_model.sql
-- Purpose: Download and load all-MiniLM-L6-v2 ONNX model into ADB.
-- Run order: 3
-- Dependencies: DBMS_CLOUD and DBMS_VECTOR grants

BEGIN
  DBMS_CLOUD.GET_OBJECT(
    credential_name => NULL,
    object_uri => 'https://objectstorage.us-phoenix-1.oraclecloud.com/n/adwc4pm/b/OML-Resources/o/all_MiniLM_L6_v2.onnx',
    directory_name => 'DATA_PUMP_DIR');
END;
/

BEGIN
  DBMS_VECTOR.LOAD_ONNX_MODEL(
    directory_name => 'DATA_PUMP_DIR',
    file_name => 'all_MiniLM_L6_v2.onnx',
    model_name => 'MINILM_EMB',
    metadata => JSON('{"function":"embedding","embeddingOutput":"embedding","input":{"input":["DATA"]}}')
  );
END;
/
