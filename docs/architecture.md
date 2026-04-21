# Architecture (Always Free-oriented)

```mermaid
flowchart LR
  U[User on credit card page] --> GG[GoldenGate trigger stub\nDBMS_SCHEDULER job]
  GG --> DB[(Autonomous Database 23ai)]

  DB --> AR[Agentic RAG via MCP]
  AR --> SQL[SQL: customer profile\nrecent transactions]
  AR --> G[Graph SQL/PGQ:\nrelated products + converting offers]
  AR --> HV[Hybrid Vector Index:\nsimilar chats + page semantics]
  AR --> EXA[Exadata Smart Scan\n(stub on free tier)]
  AR --> LLM[LLM composes nudge]
```

## Notes

- GoldenGate replication is represented as a scheduler-driven event stub in this repository.
- Exadata Smart Scan is documented for production architecture; Always Free uses the same SQL patterns without Exadata-specific acceleration.
