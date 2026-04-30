# src/extension/commands — Webview Message Handlers

24 handler files. Each file handles one domain of `WebviewMessage` types dispatched by `open-editor.ts`.

## HANDLER MAP
| File | Domain |
|------|--------|
| `open-editor.ts` | **Central router** — ALL incoming messages; MCP server lifecycle wiring |
| `save-workflow.ts` | Persist workflow to disk; return save response |
| `load-workflow.ts` | Load one workflow into editor |
| `load-workflow-list.ts` | Load workflow list into webview |
| `load-sample-workflow.ts` | Load bundled sample workflows |
| `export-workflow.ts` | Export to target agent format |
| `workflow-refinement.ts` | AI-driven workflow refinement |
| `workflow-name-generation.ts` | Generate workflow names |
| `skill-operations.ts` | Browse/create/validate skills |
| `command-operations.ts` | Browse/create sub-agent command files |
| `text-editor.ts` | "Edit in VS Code editor" helper flows |
| `mcp-handlers.ts` | MCP browse/cache/tool/schema requests from webview |
| `claude-api-handlers.ts` | Claude API upload + custom skill handlers |
| `codex-handlers.ts` | Codex export/run |
| `copilot-handlers.ts` | Copilot export/run |
| `cursor-handlers.ts` | Cursor export/run |
| `gemini-handlers.ts` | Gemini export/run |
| `roo-code-handlers.ts` | Roo Code export/run |
| `antigravity-handlers.ts` | Antigravity export/run |
| `slack-share-workflow.ts` | Share workflow to Slack |
| `slack-import-workflow.ts` | Import workflow from Slack |
| `slack-connect-oauth.ts` | Slack OAuth connection flow |
| `slack-connect-manual.ts` | Slack manual token connection |
| `slack-description-generation.ts` | Generate Slack workflow description |

## CONVENTIONS
- Each handler receives `(message, panel, context, services)` — never import vscode API directly in handlers
- Handlers call services, never implement business logic themselves
- New messages: add type to `src/shared/types/messages.ts` FIRST, then add case to `open-editor.ts`
- Export handlers by function, not class

## ANTI-PATTERNS
- Accessing filesystem directly in handlers — use `file-service.ts`
- Adding handler logic outside `open-editor.ts` routing (causes silent message drops)
