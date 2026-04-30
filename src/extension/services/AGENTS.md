# src/extension/services — Business Logic Services

53 service files. The heaviest concentration of logic in the extension host.

## SERVICE MAP

### Core workflow
| File | Role |
|------|------|
| `file-service.ts` | Workspace file/path read-write abstraction |
| `workflow-settings-service.ts` | Workflow settings persistence/lookup |
| `export-service.ts` | Converts workflows to agent-specific output |
| `schema-loader-service.ts` | Loads + caches workflow schema |
| `refinement-service.ts` | Workflow refinement engine; enforces node rules |
| `refinement-prompt-builder.ts` | Builds prompts for AI refinement |

### Built-in MCP server
| File | Role |
|------|------|
| `mcp-server-service.ts` | Localhost HTTP MCP server (`McpServerManager`); port 6282 |
| `mcp-server-tools.ts` | MCP tool registration (`get_current_workflow`, `apply_workflow`, etc.) |
| `mcp-server-config-writer.ts` | Writes MCP config files to supported agents |

### MCP client / discovery
| File | Role |
|------|------|
| `mcp-sdk-client.ts` | MCP SDK client; stdio + HTTP transport; tool discovery |
| `mcp-cli-service.ts` | Wraps `claude mcp` CLI; lists servers/tools; fetches schemas |
| `mcp-cache-service.ts` | In-memory MCP cache for servers, tools, schemas |
| `mcp-config-reader.ts` | Reads MCP config from Claude/Copilot/Codex/Gemini/Cursor/Roo |

### Skills
| File | Role |
|------|------|
| `skill-service.ts` | Core skill management |
| `skill-file-generator.ts` | Generates SKILL.md content |
| `skill-normalization-service.ts` | Normalizes skill metadata |
| `skill-relevance-matcher.ts` | Matches skills to workflow context |
| `ai-editing-skill-service.ts` | Generates + launches AI editing skills |

### AI / refinement
| File | Role |
|------|------|
| `ai-provider.ts` | Provider abstraction/selection utilities |
| `vscode-lm-service.ts` | VS Code LM API model listing |
| `commentary-ai-service.ts` | Commentary AI backend (specific, ≤2 sentences, no JSON) |
| `commentary-session-manager.ts` | Commentary session lifecycle |
| `commentary-jsonl-watcher.ts` | Watches JSONL logs for live commentary |
| `workflow-prompt-generator.ts` | Prompt generation for workflow authoring |
| `workflow-name-prompt-builder.ts` | Prompt builder for naming |
| `ai-metrics-service.ts` | Records AI usage metrics |
| `claude-api-upload-service.ts` | Uploads skills/assets to Claude API |
| `claude-code-service.ts` | Claude Code workflow execution helpers |

### Agent integrations (per-agent pattern: cli-path + mcp-sync + skill-export + extension-service)
- **Codex**: `codex-cli-path.ts`, `codex-cli-service.ts`, `codex-mcp-sync-service.ts`, `codex-skill-export-service.ts`
- **Copilot**: `copilot-cli-mcp-sync-service.ts`, `copilot-export-service.ts`, `copilot-skill-export-service.ts`
- **Cursor**: `cursor-extension-service.ts`, `cursor-skill-export-service.ts`
- **Gemini**: `gemini-cli-path.ts`, `gemini-mcp-sync-service.ts`, `gemini-skill-export-service.ts`
- **Roo Code**: `roo-code-extension-service.ts`, `roo-code-mcp-sync-service.ts`, `roo-code-skill-export-service.ts`
- **Antigravity**: `antigravity-extension-service.ts`, `antigravity-skill-export-service.ts`
- **Claude**: `claude-cli-path.ts`, `cli-path-detector.ts`

### Slack
| File | Role |
|------|------|
| `slack-api-service.ts` | Slack Web API operations |
| `slack-oauth-service.ts` | Slack OAuth transport |
| `slack-description-prompt-builder.ts` | Prompt builder for Slack descriptions |

### Other
| File | Role |
|------|------|
| `command-service.ts` | Discovers/reads command files for sub-agents |
| `terminal-execution-service.ts` | Runs slash commands in integrated terminal |
| `yaml-parser.ts` | YAML parsing utilities |

## CONVENTIONS
- `mcp-server-service.ts` communicates with webview via `postMessage` — do not call webview directly from tools
- `refinement-service.ts` enforces: no `subAgent`/`subAgentFlow`/`askUserQuestion` nodes; exactly one Start, ≥1 End; node names `/^[a-zA-Z0-9_-]+$/`; max node count
- `refinement-prompt-builder.ts` contract: AI must return exactly one raw JSON object (no markdown fences), copy unchanged nodes exactly, include `status` and `message`
- `commentary-ai-service.ts` output rule: specific tool commentary, no vague text, no JSON, 1-2 sentences only
- New agent integrations follow the 4-file pattern above

## ANTI-PATTERNS
- Calling `postMessage` from MCP tool handlers directly — must go through `mcp-server-service.ts`
- Workflow refinement AI returning markdown-fenced JSON
- Bypassing `mcp-cache-service.ts` for repeated MCP discoveries
