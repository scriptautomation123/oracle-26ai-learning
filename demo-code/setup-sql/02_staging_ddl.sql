-- 02_staging_ddl.sql
-- Purpose: Create staging tables for downloaded public datasets.
-- Prerequisite: Run after 01_schema.sql.

CREATE TABLE stg_paysim (
  step               NUMBER,
  type               VARCHAR2(20),
  amount             NUMBER,
  name_orig          VARCHAR2(40),
  oldbalance_org     NUMBER,
  newbalance_orig    NUMBER,
  name_dest          VARCHAR2(40),
  oldbalance_dest    NUMBER,
  newbalance_dest    NUMBER,
  is_fraud           NUMBER,
  is_flagged_fraud   NUMBER
);

CREATE TABLE stg_lending (
  id               NUMBER,
  member_id        NUMBER,
  loan_amnt        NUMBER,
  term             VARCHAR2(30),
  int_rate         VARCHAR2(20),
  grade            VARCHAR2(5),
  sub_grade        VARCHAR2(5),
  emp_length       VARCHAR2(30),
  home_ownership   VARCHAR2(30),
  annual_inc       NUMBER,
  purpose          VARCHAR2(100),
  loan_status      VARCHAR2(80),
  issue_d          VARCHAR2(20)
);

CREATE TABLE stg_banking77 (
  text             VARCHAR2(500),
  category         VARCHAR2(60)
);

-- UCI bank-additional-full.csv is semicolon-delimited.
CREATE TABLE stg_marketing (
  age               NUMBER,
  job               VARCHAR2(40),
  marital           VARCHAR2(20),
  education         VARCHAR2(40),
  "default"         VARCHAR2(10),
  housing           VARCHAR2(10),
  loan              VARCHAR2(10),
  contact           VARCHAR2(20),
  month             VARCHAR2(10),
  day_of_week       VARCHAR2(10),
  duration          NUMBER,
  campaign          NUMBER,
  pdays             NUMBER,
  previous          NUMBER,
  poutcome          VARCHAR2(20),
  emp_var_rate      NUMBER,
  cons_price_idx    NUMBER,
  cons_conf_idx     NUMBER,
  euribor3m         NUMBER,
  nr_employed       NUMBER,
  y                 VARCHAR2(10)
);
