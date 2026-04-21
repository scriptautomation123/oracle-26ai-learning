# Oracle SQLcl MCP setup

## Start MCP from SQLcl (free)

```bash
sql -mcp
```

Run the command on your Always Free VM (or local machine with SQLcl and wallet access).

## Claude Desktop configuration example

`claude_desktop_config.json` snippet:

```json
{
  "mcpServers": {
    "oracle-sqlcl": {
      "command": "sql",
      "args": ["-mcp"],
      "env": {
        "TNS_ADMIN": "/path/to/wallet"
      }
    }
  }
}
```

## Example natural-language tool calls

- "Find similar conversations for declined card payments."
- "Show recent transactions and likely decline reasons for customer 42."
- "Traverse related products viewed by peers in the same segment."
- "Summarize abandoned-application objections and draft a follow-up nudge."
