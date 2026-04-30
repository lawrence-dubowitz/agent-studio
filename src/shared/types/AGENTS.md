# src/shared/types — Shared Contract Layer

5 files shared by BOTH `src/extension` and `src/webview`. Treat as the single source of truth for cross-boundary types.

## FILES
| File | Role |
|------|------|
| `messages.ts` | **Primary contract** — all `ExtensionMessage`/`WebviewMessage` types + payloads |
| `workflow-definition.ts` | Core workflow node/edge/graph type definitions |
| `mcp-node.ts` | MCP node data types: `McpServerReference`, `McpToolReference`, `McpNodeData` |
| `sample-workflow.ts` | Sample workflow data structures |
| `ai-metrics.ts` | AI metrics recording types |

## CONVENTIONS
- `messages.ts` is edited **before** implementing any new webview ↔ extension communication
- Message type names are `UPPER_SNAKE_CASE`
- Envelope: `{ type, payload?, requestId? }`
- Never import extension or webview internals here — this layer must have zero dependencies on either side

## ANTI-PATTERNS
- Adding new messages without updating `messages.ts` first
- Importing from `src/extension` or `src/webview` — this package must stay independent
- Defining payload types outside `messages.ts` (causes fragmentation of the protocol)
