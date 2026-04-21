-- 05_transform.sql
-- Purpose: Transform staged dataset rows into POC business schema tables.
-- Run order: 5
-- Dependencies: sql/01_schema.sql, sql/02_staging_ddl.sql, sql/04_copy_data.sql

-- Product ID mapping used below: 1=CREDIT_CARD, 2=LOAN, 3=DEPOSIT.
INSERT INTO product (product_id, name, family, details_blob, details_text)
VALUES (1, 'Cash+ Visa', 'CREDIT_CARD', EMPTY_BLOB(), 'Everyday cashback credit card for digital spend.');

INSERT INTO product (product_id, name, family, details_blob, details_text)
VALUES (2, 'Personal Loan', 'LOAN', EMPTY_BLOB(), 'Unsecured installment loan for personal expenses.');

INSERT INTO product (product_id, name, family, details_blob, details_text)
VALUES (3, 'Term Deposit', 'DEPOSIT', EMPTY_BLOB(), 'Fixed tenure deposit with guaranteed interest.');

INSERT INTO customer (customer_id, full_name, segment, signup_date)
SELECT customer_id,
       'Customer ' || customer_id,
       CASE MOD(customer_id, 4)
         WHEN 0 THEN 'MASS'
         WHEN 1 THEN 'AFFLUENT'
         WHEN 2 THEN 'YOUTH'
         ELSE 'SMB'
       END,
       TRUNC(SYSDATE) - MOD(customer_id, 365)
FROM (
  SELECT ROW_NUMBER() OVER (ORDER BY name_orig) AS customer_id, name_orig
  FROM (SELECT DISTINCT name_orig FROM stg_paysim)
  FETCH FIRST 500 ROWS ONLY
);

INSERT INTO account (account_id, customer_id, product_id, daily_limit, opened_at)
SELECT rn AS account_id,
       MOD(rn - 1, 500) + 1 AS customer_id,
       CASE MOD(rn, 3) WHEN 1 THEN 1 WHEN 2 THEN 2 ELSE 3 END AS product_id,
       CASE MOD(rn, 3) WHEN 1 THEN 2000 WHEN 2 THEN 10000 ELSE 50000 END AS daily_limit,
       TRUNC(SYSDATE) - MOD(rn, 730)
FROM (
  SELECT LEVEL AS rn
  FROM dual
  CONNECT BY LEVEL <= 800
);

INSERT INTO txn (txn_id, account_id, amount, status, decline_reason, txn_ts)
SELECT ROW_NUMBER() OVER (ORDER BY step, name_orig, name_dest) AS txn_id,
       MOD(ROW_NUMBER() OVER (ORDER BY step, name_orig, name_dest) - 1, 800) + 1 AS account_id,
       amount,
       CASE WHEN is_fraud = 1 OR is_flagged_fraud = 1 THEN 'DECLINED' ELSE 'APPROVED' END AS status,
       CASE
         WHEN is_fraud = 1 THEN 'SUSPECTED_FRAUD'
         WHEN is_flagged_fraud = 1 THEN 'LIMIT_EXCEEDED'
         ELSE NULL
       END AS decline_reason,
       SYSTIMESTAMP - NUMTODSINTERVAL(step, 'MINUTE')
FROM stg_paysim
FETCH FIRST 10000 ROWS ONLY;

INSERT INTO application (app_id, customer_id, product_id, status, fields_json, updated_at)
SELECT ROW_NUMBER() OVER (ORDER BY id) AS app_id,
       MOD(ROW_NUMBER() OVER (ORDER BY id) - 1, 500) + 1 AS customer_id,
       2 AS product_id,
       CASE
         WHEN UPPER(loan_status) LIKE '%FULLY PAID%' OR UPPER(loan_status) LIKE '%CURRENT%' THEN 'SUBMITTED'
         WHEN UPPER(loan_status) LIKE '%CHARGED OFF%' OR UPPER(loan_status) LIKE '%DEFAULT%' THEN 'ABANDONED'
         ELSE 'STARTED'
       END AS status,
       JSON_OBJECT(
         'loan_amnt' VALUE loan_amnt,
         'term' VALUE term,
         'purpose' VALUE purpose,
         'grade' VALUE grade,
         'annual_inc' VALUE annual_inc,
         'loan_status_raw' VALUE loan_status
       ),
       SYSTIMESTAMP - NUMTODSINTERVAL(MOD(ROW_NUMBER() OVER (ORDER BY id), 1440), 'MINUTE')
FROM stg_lending;

INSERT INTO conversation (conv_id, customer_id, channel, transcript, conv_ts)
SELECT ROW_NUMBER() OVER (ORDER BY text) AS conv_id,
       MOD(ROW_NUMBER() OVER (ORDER BY text) - 1, 500) + 1 AS customer_id,
       'CHAT',
       'Customer: ' || text || CHR(10) ||
       'Agent: I can help with that today. Here are your next best actions.' AS transcript,
       SYSTIMESTAMP - NUMTODSINTERVAL(MOD(ROW_NUMBER() OVER (ORDER BY text), 10080), 'MINUTE')
FROM stg_banking77
WHERE text IS NOT NULL;

INSERT INTO offer (offer_id, product_id, offer_name, offer_channel, conversion_flag, created_at)
SELECT LEVEL,
       CASE MOD(LEVEL, 3) WHEN 1 THEN 1 WHEN 2 THEN 2 ELSE 3 END,
       'Offer ' || LEVEL,
       CASE MOD(LEVEL, 2) WHEN 0 THEN 'EMAIL' ELSE 'IN_APP' END,
       CASE MOD(LEVEL, 4) WHEN 0 THEN 'Y' ELSE 'N' END,
       SYSTIMESTAMP - NUMTODSINTERVAL(LEVEL, 'DAY')
FROM dual
CONNECT BY LEVEL <= 30;

COMMIT;
