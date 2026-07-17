-- lab_setup.sql
-- Creates scoring table + assert/manual procedures + prerequisite guard.

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE lab_results PURGE';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

CREATE TABLE lab_results (
  result_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  module_name   VARCHAR2(30) NOT NULL,
  test_name     VARCHAR2(200) NOT NULL,
  status        VARCHAR2(10) NOT NULL CHECK (status IN ('PASS','FAIL','MANUAL')),
  detail        VARCHAR2(4000),
  created_at    TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL
);
/

CREATE OR REPLACE PROCEDURE lab_assert(
  p_module    IN VARCHAR2,
  p_test_name IN VARCHAR2,
  p_condition IN BOOLEAN,
  p_detail    IN VARCHAR2 DEFAULT NULL
) IS
BEGIN
  INSERT INTO lab_results(module_name, test_name, status, detail)
  VALUES (p_module, p_test_name, CASE WHEN p_condition THEN 'PASS' ELSE 'FAIL' END, p_detail);
  COMMIT;
END;
/

CREATE OR REPLACE PROCEDURE lab_manual(
  p_module    IN VARCHAR2,
  p_test_name IN VARCHAR2,
  p_detail    IN VARCHAR2 DEFAULT NULL
) IS
BEGIN
  INSERT INTO lab_results(module_name, test_name, status, detail)
  VALUES (p_module, p_test_name, 'MANUAL', p_detail);
  COMMIT;
END;
/

-- lab_optional: for recommended/governance objects that the training tells
-- the team to add but the demo schema does not ship. If the object exists in
-- the schema, run the structural assertion (PASS/FAIL). If it does not, log
-- a MANUAL item with the evidence-required note so it shows up in the
-- final report as a tracked action item rather than being silently skipped.
CREATE OR REPLACE PROCEDURE lab_optional(
  p_module    IN VARCHAR2,
  p_test_name IN VARCHAR2,
  p_obj_name  IN VARCHAR2,
  p_condition IN BOOLEAN,
  p_detail    IN VARCHAR2 DEFAULT NULL
) IS
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cnt
  FROM user_objects WHERE object_name = UPPER(p_obj_name);

  IF v_cnt = 0 THEN
    INSERT INTO lab_results(module_name, test_name, status, detail)
    VALUES (p_module, p_test_name, 'MANUAL',
            'Recommended object ' || UPPER(p_obj_name) ||
            ' is not present. Add it per the module guidance and rerun.');
  ELSE
    INSERT INTO lab_results(module_name, test_name, status, detail)
    VALUES (p_module, p_test_name,
            CASE WHEN p_condition THEN 'PASS' ELSE 'FAIL' END,
            p_detail);
  END IF;
  COMMIT;
END;
/

DECLARE
  v_missing VARCHAR2(4000) := NULL;

  PROCEDURE require_obj(p_name VARCHAR2) IS
    v_cnt NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_cnt FROM user_objects WHERE object_name = UPPER(p_name);
    IF v_cnt = 0 THEN
      v_missing := v_missing || CASE WHEN v_missing IS NULL THEN '' ELSE ', ' END || UPPER(p_name);
    END IF;
  END;

  PROCEDURE require_model(p_name VARCHAR2) IS
    v_cnt NUMBER;
  BEGIN
    BEGIN
      EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM user_mining_models WHERE model_name = :x'
      INTO v_cnt USING UPPER(p_name);
    EXCEPTION
      WHEN OTHERS THEN
        v_cnt := 0;
    END;

    IF v_cnt = 0 THEN
      v_missing := v_missing || CASE WHEN v_missing IS NULL THEN '' ELSE ', ' END || UPPER(p_name);
    END IF;
  END;
BEGIN
  require_obj('CUSTOMER');
  require_obj('CONVERSATION_CHUNK');
  require_obj('CONV_CHUNK_IDX');
  require_obj('BANKING_GRAPH');
  require_model('MINILM_EMB');

  IF v_missing IS NOT NULL THEN
    RAISE_APPLICATION_ERROR(-20001, 'Lab prerequisite objects missing: ' || v_missing);
  END IF;
END;
/
