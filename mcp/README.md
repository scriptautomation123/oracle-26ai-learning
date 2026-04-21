# MCP Setup (SQLcl `-mcp`)

## 1) Install SQLcl 24.x+
- Download SQLcl from Oracle and verify:
  ```bash
  sql -version
  ```

## 2) Start MCP server
```bash
sql -mcp
```

## 3) Configure Claude Desktop
Add an MCP entry in `claude_desktop_config.json` pointing to SQLcl MCP:

```json
{
  "mcpServers": {
    "oracle-adb": {
      "command": "sql",
      "args": ["-mcp"],
      "env": {
        "TNS_ADMIN": "/path/to/wallet"
      }
    }
  }
}
```

## 4) Example agent prompts
- "Find recent declined transactions and explain likely reasons for customer 1001."
- "Use graph traversal to list products peers viewed after Cash+ Visa."
- "Retrieve similar abandoned-application chats and draft a one-line nudge."
- "Generate a UC3 proactive nudge using Select AI and policy context."
