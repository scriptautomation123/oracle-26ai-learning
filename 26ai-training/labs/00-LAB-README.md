# Hands-on Lab — Oracle 26ai Training Track

## Objective

Self-grade Modules 1–6 with database-native checks.

## How to run

1. Run core repo SQL through `sql/08_select_ai_profile.sql`.
2. Run `lab_setup.sql`.
3. Run `lab01_vectors.sql` ... `lab06_ops.sql` in order.
4. Run `lab_report.sql` for final scoreboard.

## Prerequisites

- ADB 26ai schema with objects from `sql/01..08`
- `MINILM_EMB` model loaded
- `BANKING_GRAPH` created

## Result semantics

- `PASS`: objective automated check passed
- `FAIL`: objective automated check failed
- `MANUAL`: evidence required by human review

## Lab files

- `lab_setup.sql`
- `lab01_vectors.sql`
- `lab02_graphs.sql`
- `lab03_select_ai.sql`
- `lab04_mcp.sql`
- `lab05_e2e.sql`
- `lab06_ops.sql`
- `lab_report.sql`
