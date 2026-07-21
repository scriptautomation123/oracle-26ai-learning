# Finish Line: Readiness and Exit Criteria

This file is the end point for the documentation path.

If you reached this page after following [00-start-here.md](00-start-here.md), use it to confirm completion and identify gaps before handoff.

## Completion checklist

A team can consider the docs pass complete when all statements below are true.

1. The team can describe UC1, UC2, and UC3 trigger logic and why UC3 is servicing.
2. The team can explain the architecture sequence: relational filter, graph traversal, vector ranking, governed generation, decision logging.
3. The team can explain why vectors, graph, and logs are kept in the same Oracle boundary.
4. The team can identify where suppression and opt-out checks run and what happens on suppression.
5. The team can identify the records-of-record tables and retention controls.
6. The team can explain the fallback path for model/profile/template degradation.
7. The team can run the demo flow from [demo-script.md](demo-script.md) without ad hoc guesswork.
8. The team can run the lab suite from [../labs/00-LAB-README.md](../labs/00-LAB-README.md) and interpret PASS, FAIL, and MANUAL outcomes.

## Evidence package expected

For a complete internal handoff, keep these artifacts together:

- SQL run-order execution log.
- Demo walkthrough notes and sample outputs.
- Lab scoreboard output from `lab_report.sql`.
- Open items list for each MANUAL control.

## If you are not done

Return to the chapter where the gap exists:

- Business understanding gap: [01-business-and-vision.md](01-business-and-vision.md)
- Architecture gap: [02-architecture-and-data-model.md](02-architecture-and-data-model.md)
- DBA/query gap: [03-dba-and-query-patterns.md](03-dba-and-query-patterns.md)
- Governance gap: [04-training-and-governance.md](04-training-and-governance.md)
- Operations gap: [05-operations-and-controls.md](05-operations-and-controls.md)

## Exit

At this point the reader should know where to start, where to end, and how to prove they learned the material with executable checks.
