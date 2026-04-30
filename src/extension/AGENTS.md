# src/extension — Extension Host

VSCode extension host layer (Node.js/TypeScript). Entry point: `extension.ts`.

## STRUCTURE
```
extension.ts        # activate/deactivate; registers commands, editors, URI handler, MCP lifecycle
webview-content.ts  # builds the webview HTML shell
commands/           # 24 webview message handlers (see commands/AGENTS.md)
services/           # 53 business-logic services (see services/AGENTS.md)
editors/            # custom editor provider for .vscode/workflows/*.json files
utils/              # path helpers, validators, key managers, sensitive-data detector
types/              # Slack-specific domain types
i18n/               # translations + i18n-service.ts (en, ja, ko, zh-CN, zh-TW)
```

## WHERE TO LOOK
| Task | File |
|------|------|
| Register a new command | `extension.ts` + add handler in `commands/` |
| Route a new webview message | `commands/open-editor.ts` (central dispatcher) |
| Access workspace files | `services/file-service.ts` |
| Read/write MCP config files | `services/mcp-config-reader.ts`, `services/mcp-server-config-writer.ts` |
| Path resolution for workspace/config | `utils/path-utils.ts` |
| Workflow validation | `utils/workflow-validator.ts`, `utils/validate-workflow.ts` |
| Version badge (unread changelog) | `utils/changelog-parser.ts` |
| Translations | `i18n/translation-keys.ts` → `i18n/translations/*.ts` |

## CONVENTIONS
- `extension.ts` only wires; logic lives in services
- All new webview messages must be registered in `commands/open-editor.ts`
- Service constructors receive `vscode.ExtensionContext` — do not use global state
- `utils/` functions are stateless; side-effectful operations go in `services/`

## ANTI-PATTERNS
- Adding business logic to `extension.ts` — wiring only
- Adding message routing outside `open-editor.ts`
- Using `process.env.*` for secrets — use `vscode.SecretStorage` via key managers in `utils/`
