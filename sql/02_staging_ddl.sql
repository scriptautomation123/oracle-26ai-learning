-- 02_staging_ddl.sql
-- Purpose: Create raw staging tables for external datasets.
-- Run order: 2
-- Dependencies: sql/01_schema.sql

CREATE TABLE stg_paysim (
  step              NUMBER,
  type              VARCHAR2(30),
  amount            NUMBER,
  name_orig         VARCHAR2(100),
  old_balance_org   NUMBER,
  new_balance_orig  NUMBER,
  name_dest         VARCHAR2(100),
  old_balance_dest  NUMBER,
  new_balance_dest  NUMBER,
  is_fraud          NUMBER,
  is_flagged_fraud  NUMBER
);

CREATE TABLE stg_lending (
  id                NUMBER,
  loan_amnt         NUMBER,
  term              VARCHAR2(30),
  int_rate          VARCHAR2(30),
  installment       NUMBER,
  grade             VARCHAR2(10),
  sub_grade         VARCHAR2(10),
  emp_length        VARCHAR2(30),
  home_ownership    VARCHAR2(30),
  annual_inc        NUMBER,
  purpose           VARCHAR2(100),
  loan_status       VARCHAR2(120)
);

CREATE TABLE stg_banking77 (
  text              VARCHAR2(4000),
  label             VARCHAR2(200)
);

CREATE TABLE stg_marketing (
  age               NUMBER,
  job               VARCHAR2(50),
  marital           VARCHAR2(20),
  education         VARCHAR2(50),
  default_flag      VARCHAR2(10),
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
  y                 VARCHAR2(10)
);
