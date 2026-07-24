# Business Vision: Proactive Banking Nudges on Oracle 26ai
 m

## Why

act while customer intent is still live. That means the decision has to happen in the same session window, with the same customer context, and with the same data the bank already trusts.

The three moments that matter are:

1. Credit card page view, where the customer is browsing and can still be guided.
2. Abandoned application, where a partially completed flow can be recovered.
3. Declined transaction, where the response must be explainable and immediate.

Each of these moments has different operational constraints, but the shared goal is the same: produce a timely nudge from the bank's own data without moving that data into another system.

## Banking outcomes 

- Improve decision timeliness while the customer is still in-session.
- Improve product-fit quality by combining eligibility rules with behavioral context.
- Reduce avoidable support load by handling declined-transaction servicing quickly and clearly.
- Keep every decision replayable for controls, audits, and regulator requests.

The design assumes the bank already has system-of-record data and strict controls. This demo focuses on improving action quality without weakening those controls.

## marketing

Marketing

- Increase contextual relevance for card and loan nudges during high-intent moments.
- Recover abandoned applications with tailored objection-handling prompts.
- Enforce suppression, frequency caps, and channel-level opt-out consistently.
- Support measurable attribution through deterministic holdout and decision logging.

In this model, marketing effectiveness is achieved through controlled personalization rather than unconstrained generation.

## What this is not

This is not a separate vector database project.



It is a converged Oracle Database 26ai implementation that uses relational rows, vectors, graph traversal, governed generation, and policy-wrapped tools to support regulated customer communications.

## The customer moments

### Credit card page view

A customer lands on a card product page. The bank already knows something useful: the page itself, the product family, the browsing sequence, and prior behavioral context. The system should use those signals to decide whether the customer should see a comparison nudge, a product suggestion, or a next-step prompt.

This is primarily a marketing conversion moment. The desired outcome is better product discovery and better conversion quality without violating eligibility boundaries.

### Abandoned application

The customer started an application and stopped before completion. The bank wants to know whether the right response is a reminder, an objection-handling message, or a callback offer. The design must use the customer's existing application state and prior conversation context, not an external guess.

This is a shared banking and marketing moment: operations wants workflow completion, and marketing wants a compliant re-engagement path.

### Declined transaction

The customer's transaction was declined. That is a servicing moment, not a marketing moment. The right answer may be an explanation, a limit-review path, or a fraud-resolution prompt. The content must stay explainable and the communication class must be governed correctly.

This distinction is central for banks: misclassifying servicing as marketing creates policy and legal risk.

## Why the converged approach matters

The business value is not just that Oracle 26ai can do vector search or graph traversal. The value is that these capabilities sit in the same transaction boundary as the source data.

That gives the team three practical advantages:

- The customer data stays in the bank's controlled perimeter.
- The same records can be audited, replayed, and retained under bank policy.
- The retrieval path can combine exact relational filters with semantic and graph-based context without ETL glue.

This is the core argument for the demo. The bank does not need a second platform to make the nudge possible.

## Human workflow this chapter supports

A good reader of this chapter should come away with a mental model for:

- Which customer moments are worth acting on.
- Why the bank needs live context rather than batch-only enrichment.
- Why the same customer journey can have different governance rules depending on the use case.
- Why the delivery surface can vary while the underlying decision path stays the same.
- How banking operations goals and marketing goals can be aligned in one governed execution flow.

## Next phase handoff

Next phase: setup and data preparation.

Read next:

- [03-dba-and-query-patterns.md](03-dba-and-query-patterns.md)

Run next:

- `source scripts/setup/setup_venv.sh`
- `./scripts/setup/setup_kaggle.sh`
- `./scripts/data/download_datasets.sh`
- `python3 scripts/data/trim_lending.py --input data/raw/lendingclub/accepted_2007_to_2018Q4.csv --output data/processed/lendingclub_5k.csv`
- `python3 scripts/data/generate_conversations.py --input data/raw/banking77/banking77.csv --output data/processed/banking77_conversations.csv`
