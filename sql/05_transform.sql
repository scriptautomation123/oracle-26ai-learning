-- 05_transform.sql
-- Purpose: Transform staging data into normalized POC schema and synthesize activity data.
-- Prerequisite: Run after 01_schema.sql and 04_copy_data.sql with populated staging tables.

INSERT INTO product (product_id, name, family, details_blob, details_text)
SELECT 1, 'Cash+ Visa', 'CREDIT_CARD', TO_BLOB(UTL_RAW.CAST_TO_RAW('Cash+ Visa product sheet')), TO_CLOB('Cash+ Visa with rewards and configurable categories') FROM dual
UNION ALL
SELECT 2, 'Personal Loan', 'LOAN', TO_BLOB(UTL_RAW.CAST_TO_RAW('Personal Loan brochure')), TO_CLOB('Personal Loan fixed term repayment product') FROM dual
UNION ALL
SELECT 3, 'Term Deposit', 'DEPOSIT', TO_BLOB(UTL_RAW.CAST_TO_RAW('Term Deposit fact sheet')), TO_CLOB('Term Deposit with fixed duration and fixed interest') FROM dual;

INSERT INTO offer (offer_id, product_id, offer_name, eligibility_rule, outcome_label)
SELECT 1, 1, 'Cash+ Visa Intro APR', 'segment in (Prime, Affluent)', 'N/A' FROM dual
UNION ALL
SELECT 2, 2, 'Personal Loan Cashback', 'application purpose in debt_consolidation', 'N/A' FROM dual
UNION ALL
SELECT 3, 3, 'Term Deposit Bonus Rate', 'new_to_bank = Y', 'N/A' FROM dual;

INSERT INTO customer (customer_id, full_name, segment, signup_date)
SELECT rn,
       name_orig,
       CASE MOD(rn, 3) WHEN 0 THEN 'Mass' WHEN 1 THEN 'Prime' ELSE 'Affluent' END,
       TRUNC(SYSDATE) - MOD(rn, 720)
FROM (
  SELECT name_orig, ROW_NUMBER() OVER (ORDER BY name_orig) rn
  FROM (SELECT DISTINCT name_orig FROM stg_paysim)
)
WHERE rn <= 500;

INSERT INTO account (account_id, customer_id, product_id, daily_limit, opened_at)
SELECT seed.lvl,
       seed.customer_id,
       seed.product_id,
       -- Demo tiers aligned to customer segment: Mass=2k, Prime=5k, Affluent=10k.
       CASE c.segment
         WHEN 'Mass' THEN 2000
         WHEN 'Prime' THEN 5000
         WHEN 'Affluent' THEN 10000
         ELSE 2000
       END,
       TRUNC(SYSDATE) - MOD(seed.lvl, 900)
FROM (
  SELECT LEVEL lvl,
         MOD(LEVEL - 1, 500) + 1 AS customer_id,
         MOD(LEVEL - 1, 3) + 1 AS product_id
  FROM dual
  CONNECT BY LEVEL <= 800
) seed
JOIN customer c
  ON c.customer_id = seed.customer_id;

INSERT INTO txn (txn_id, account_id, amount, status, decline_reason, txn_ts)
SELECT rn,
       MOD(rn - 1, 800) + 1,
       amount,
       CASE WHEN NVL(is_fraud, 0) = 1 OR NVL(is_flagged_fraud, 0) = 1 THEN 'DECLINED' ELSE 'APPROVED' END,
       CASE
         WHEN NVL(is_flagged_fraud, 0) = 1 THEN 'LIMIT_EXCEEDED'
         WHEN NVL(is_fraud, 0) = 1 THEN 'SUSPECTED_FRAUD'
         ELSE NULL
       END,
       SYSTIMESTAMP - NUMTODSINTERVAL(MOD(step, 10080), 'MINUTE')
FROM (
  SELECT ROW_NUMBER() OVER (ORDER BY step, name_orig, name_dest) rn,
         step,
         amount,
         is_fraud,
         is_flagged_fraud
  FROM stg_paysim
)
WHERE rn <= 10000;

INSERT INTO application (app_id, customer_id, product_id, status, fields_json, updated_at)
SELECT rn,
       MOD(rn - 1, 500) + 1,
       CASE WHEN LOWER(NVL(purpose, '')) LIKE '%credit%' THEN 1 ELSE 2 END,
       CASE
         WHEN loan_status IN ('Current', 'Fully Paid') THEN 'SUBMITTED'
         WHEN loan_status = 'In Grace Period' THEN 'STARTED'
         ELSE 'ABANDONED'
       END,
       JSON_OBJECT(
         'loan_amnt' VALUE loan_amnt,
         'term' VALUE term,
         'int_rate' VALUE int_rate,
         'grade' VALUE grade,
         'sub_grade' VALUE sub_grade,
         'emp_length' VALUE emp_length,
         'home_ownership' VALUE home_ownership,
         'annual_inc' VALUE annual_inc,
         'purpose' VALUE purpose,
         'loan_status' VALUE loan_status,
         'issue_d' VALUE issue_d
       ),
       SYSTIMESTAMP - NUMTODSINTERVAL(MOD(rn, 2880), 'MINUTE')
FROM (
  SELECT ROW_NUMBER() OVER (ORDER BY id) rn,
         loan_amnt, term, int_rate, grade, sub_grade, emp_length,
         home_ownership, annual_inc, purpose, loan_status, issue_d
  FROM stg_lending
)
WHERE rn <= 5000;

INSERT INTO conversation (conv_id, customer_id, channel, transcript, conv_ts)
SELECT rn,
       MOD(rn - 1, 500) + 1,
       'CHAT',
       TO_CLOB('Customer: ' || text || CHR(10) || 'Agent: [resolution for ' || category || ']'),
       SYSTIMESTAMP - NUMTODSINTERVAL(MOD(rn, 43200), 'MINUTE')
FROM (
  SELECT ROW_NUMBER() OVER (ORDER BY text) rn, text, category
  FROM stg_banking77
)
WHERE rn <= 10000;

INSERT INTO page_event (event_id, customer_id, product_id, page_url, event_ts)
SELECT lvl,
       TRUNC(DBMS_RANDOM.VALUE(1, 501)),
       TRUNC(DBMS_RANDOM.VALUE(1, 4)),
       CASE TRUNC(DBMS_RANDOM.VALUE(1, 4))
         WHEN 1 THEN '/products/cash-plus-visa'
         WHEN 2 THEN '/products/personal-loan'
         ELSE '/products/term-deposit'
       END,
       SYSTIMESTAMP - NUMTODSINTERVAL(TRUNC(DBMS_RANDOM.VALUE(1, 43200)), 'MINUTE')
FROM (SELECT LEVEL lvl FROM dual CONNECT BY LEVEL <= 1000);

COMMIT;
