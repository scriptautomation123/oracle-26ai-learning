# Hands-on Lab — Oracle 26ai Training Track (Offers Management Edition)

## Objective

Self-grade Modules 1–6 with database-native checks. The labs verify two
classes of things:

1. **In-place demo objects** — what exists after running
   `26ai-banking-demo/sql/01..08`. These produce automated `PASS` / `FAIL`.
2. **Bank-grade governance objects** that the training tells you to add
   (`AI_CALL_LOG`, `OFFER_DECISION_LOG`, `OFFER_SUPPRESSION`, `DO_NOT_CONTACT`,
   `APPROVED_DISCLOSURES`, `LEGAL_HOLD`, `UDAAP_REVIEW_QUEUE`,
   `PKG_NUDGE_AI`, `PKG_NUDGE_POLICY`, `NUDGE_AGENT` role, etc.).
   These are recommendations. If the object exists in your schema the lab
   asserts it; if not, the lab logs a `MANUAL` item with the minimum
   schema/control the auditor will expect. Either way you get a tracked
   action item.

That asymmetry is intentional. The demo proves the AI primitives work.
**Production-readiness is proved by you adding the controls.**

## How to run

1. Run core demo SQL through `26ai-banking-demo/sql/08_select_ai_profile.sql`.
2. Run `lab_setup.sql`.
3. Run `lab01_vectors.sql` ... `lab06_ops.sql` in order.
4. Run `lab_report.sql` for the final scoreboard.

## Prerequisites

- ADB 26ai schema with objects from `26ai-banking-demo/sql/01..08`.
- `MINILM_EMB` model loaded.
- `BANKING_GRAPH` created.
- `NUDGE_BOT` Select AI profile created.

## Result semantics

- `PASS`: automated check passed.
- `FAIL`: automated check failed — fix before the next gate review.
- `MANUAL`: an item that requires evidence — usually a control the bank
  must add and Compliance / Audit must sign off on. The detail column
  states what evidence is expected.

## Reading the report

`lab_report.sql` produces:

- per-module PASS/FAIL/MANUAL counts,
- FAIL detail (must be empty before launch),
- MANUAL items (must each have a tracked owner and evidence link before
  launch),
- overall pass-rate.

A green automated run with no MANUAL items closed is **not** launch-ready.
Module 5's launch-readiness checklist is the gate.

## Lab files

- `lab_setup.sql` — scoring table + assert/manual/optional helpers + prereq guard
- `lab01_vectors.sql` — Module 1 (vector schema, ANN index, NPI handling, model inventory)
- `lab02_graphs.sql` — Module 2 (graph definition, fair-lending guard on graph properties)
- `lab03_select_ai.sql` — Module 3 (NUDGE_BOT, AI_CALL_LOG, UDAAP review queue, approved disclosures)
- `lab04_mcp.sql` — Module 4 (NUDGE_AGENT least-priv, suppression + opt-out wrappers, do-not-contact)
- `lab05_e2e.sql` — Module 5 (E2E pipeline runs, OFFER_DECISION_LOG, eligibility honored, holdout assignment)
- `lab06_ops.sql` — Module 6 (vector plan, audit retention, legal-hold check, fair-lending sampling capability)
- `lab_report.sql` — final scoreboard
