# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd prime` for full workflow context.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work atomically
bd close <id>         # Complete work
bd dolt push          # Push beads data to remote
```

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations to avoid hanging on confirmation prompts.

Shell commands like `cp`, `mv`, and `rm` may be aliased to include `-i` (interactive) mode on some systems, causing the agent to hang indefinitely waiting for y/n input.

**Use these forms instead:**
```bash
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file
rm -rf directory            # NOT: rm -r directory
cp -rf source dest          # NOT: cp -r source dest
```

Other commands that may prompt:
- `scp` — use `-o BatchMode=yes`
- `ssh` — use `-o BatchMode=yes`
- `apt-get` — use `-y`
- `brew` — use `HOMEBREW_NO_AUTO_UPDATE=1`

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->

---

# PROJECT KNOWLEDGE BASE

**Generated:** 2026-04-30 | **Commit:** df93e0d | **Branch:** main

## OVERVIEW
Agent Studio is a VSCode extension (visual workflow editor for AI agents: Claude Code, Copilot, Codex, Roo, Cursor, Gemini, Antigravity) built as a 3-part monorepo: extension host, React webview, and shared contracts.

## STRUCTURE
```
agent-studio/
├── src/extension/      # VSCode extension host (Node.js/TypeScript)
│   ├── commands/       # Webview message handlers (24 handlers)
│   ├── services/       # Business logic & integrations (53 services)
│   ├── editors/        # Custom workflow preview editor provider
│   ├── utils/          # Validation, path helpers, secret key managers
│   ├── types/          # Extension-side Slack type definitions
│   └── i18n/           # Translations: en, ja, ko, zh-CN, zh-TW
├── src/webview/        # Separate React/Vite frontend package
│   └── src/            # components, stores, hooks, services, i18n
├── src/shared/         # Types/constants shared by extension + webview
│   └── types/          # messages.ts (protocol), workflow-definition.ts, mcp-node.ts
├── resources/          # workflow-schema.json (SOURCE), icon.png
│   └── workflow-schema.toon  # AUTO-GENERATED from schema.json — DO NOT EDIT
├── scripts/            # TS-only build generators (no shell/Makefile)
├── specs/              # Feature specs (001-* per feature)
├── .github/workflows/  # CI: release (→production), security-scan, stale
├── .releaserc.json     # Semantic release config (NOT in package.json)
├── biome.json          # Lint/format: 2-space, 100-col, single-quotes, semicolons
└── .vscode/workflows/  # User-created workflow JSON files (editor target, not source)
```

## WHERE TO LOOK
| Task | Location |
|------|----------|
| Add webview message type | `src/shared/types/messages.ts` — single source of truth |
| Add extension command/handler | `src/extension/commands/` + register in `open-editor.ts` |
| Add business logic service | `src/extension/services/` |
| Add React component | `src/webview/src/components/` |
| Add dialog | `src/webview/src/components/dialogs/` — always Radix UI |
| Add workflow node type | `src/webview/src/components/nodes/` + update schema |
| State management | `src/webview/src/stores/workflow-store.ts` (Zustand + zundo undo/redo) |
| Add host↔webview call | `vscode-bridge.ts` (webview) + `open-editor.ts` (extension) |
| MCP tools exposed to agents | `src/extension/services/mcp-server-tools.ts` |
| Workflow validation rules | `src/extension/services/refinement-service.ts` |
| Schema source | `resources/workflow-schema.json` → `.toon` (auto-generated) |
| Release config | `.releaserc.json` + `.github/workflows/release.yml` |

## ARCHITECTURE

### Dual-package split (non-obvious)
- Root `tsconfig.json` **excludes `src/webview`** — two independent TS compilation pipelines
- `src/webview` has own `package.json`, `tsconfig.json`, `vite.config.ts`
- Path aliases: extension `@` → `src`; webview `@/*` → `src/webview/src/*`, `@shared/*` → `src/shared/*`
- Extension bundles via `vite.extension.config.ts` (CJS, Node 18 target) into `dist/extension.js`

### Message protocol (extension ↔ webview)
- Canonical types: `ExtensionMessage` / `WebviewMessage` in `src/shared/types/messages.ts`
- Envelope: `{ type: UPPER_SNAKE_CASE, payload?, requestId? }`
- Async calls use `requestId` correlation + timeout cleanup — see `vscode-bridge.ts`
- Startup: webview sends `WEBVIEW_READY` → extension responds `INITIAL_STATE`
- Central router: `open-editor.ts` dispatches ALL inbound `WebviewMessage` types

### Built-in MCP server
- `mcp-server-service.ts`: stateless localhost HTTP on port **6282** (config: `agent-studio.mcp.port`)
- Tools: `get_current_workflow`, `apply_workflow`, `get_workflow_schema`, `list_available_agents`, `update_nodes`
- Talks to webview via postMessage for live canvas reads/writes
- External agents use the `agent-ai-editor` skill to interface with this server

### AI editing — active vs discontinued
- **Active**: MCP server + `agent-ai-editor` skill — all new AI editing goes through this path
- **Discontinued** (maintenance only): `AiGenerationDialog`, `RefinementChatPanel` — no new features

```
AI Agent → MCP Server (port 6282) → postMessage → Webview canvas
             get_current_workflow / apply_workflow / update_nodes
```

## CONVENTIONS

### Language
- GitHub Issues, PRs (titles, bodies, comments) **must be in English** — regardless of conversation language

### Code style (Biome enforced)
- 2-space indent, 100 char lines, single quotes, semicolons
- Strict: `noImplicitAny`, `noUnusedLocals/Params`, `noImplicitReturns`, `noFallthroughCasesInSwitch`
- Never suppress with `@ts-ignore` / `as any`

### Commit messages
- Format: `<type>: <subject>` (50 char max, imperative mood, no period)
- Body (optional): 3–5 bullet points max, "what" changed only — put "why" in PR description
- Types: `feat` (minor bump), `fix`/`improvement` (patch), `docs`, `refactor`, `chore`
- **Avoid**: Problem/Solution/Impact sections, multiple paragraphs, code blocks, checkbox lists

Version bump rules:
| Prefix | Bump |
|--------|------|
| `feat:` | minor |
| `fix:`, `improvement:`, `perf:`, `revert:` | patch |
| BREAKING CHANGE in body | major |
| `docs:`, `style:`, `chore:`, `refactor:`, `test:`, `build:`, `ci:` | no release |

### Dialogs
- Always `@radix-ui/react-dialog` — never custom overlay
- Z-index tiers: base=9999, nested=10000, confirm=10001
- Set `zIndex` on `Dialog.Overlay`, not content
- Checklist: uses Radix UI ✓ | Overlay has zIndex ✓ | ESC closes ✓ | Overlay click closes ✓

### External links (webview)
- Use `openExternalUrl()` from `vscode-bridge.ts` + `lucide-react ExternalLink` icon
- Never `<a href>` or `window.open()` — blocked in webview context
- Pattern: `role="button"` + `tabIndex={0}` + `onKeyDown` for accessibility
- Add `e.stopPropagation()` when inside accordion/collapsible parent elements

### Naming rules
- Workflow node names: `/^[a-zA-Z0-9_-]+$/`
- LocalStorage keys: `agent-studio:*` (new) / `agent-studio.*` (legacy)
- Settings namespace: `agent-studio.*`

## ANTI-PATTERNS
- Edit `workflow-schema.toon` — generated at build, changes lost
- Manual `version` bumps — Semantic Release owns this; never update `package.json` version manually
- Add release config to `package.json` — belongs in `.releaserc.json`
- `<a href>` / `window.open()` in webview — use `openExternalUrl()`
- Subagent flows using `subAgent`/`subAgentFlow`/`askUserQuestion` nodes — forbidden
- AI refinement response with markdown fences — raw JSON only
- Commentary AI: vague text, JSON output, or questions — must be 1-2 sentences, specific
- Suppressing TS errors with `@ts-ignore` / `as any`

## COMMANDS

This project uses [`just`](https://github.com/casey/just) as a command runner. Run `just` to list all recipes.

```bash
# Build
just build              # Full: schema-gen → flow-gen → webview → extension
just build-dev          # Dev mode (skips TOON generation)
just watch              # Extension watch
just watch-webview      # Webview dev server (Vite HMR)

# Quality gates
just check              # Biome lint + format + auto-fix
just gate               # check + build (full pre-commit gate)

# Tests
just test               # Webview Vitest unit tests
just test-e2e           # ⚠ BROKEN — wdio.conf.ts does not exist yet

# Other
just install            # Install root + webview dependencies
just compile            # TypeScript compile check (no emit)
just lint               # Lint only (no auto-fix)
just fmt                # Format only
```

**Quality gate sequence** (mandatory before every commit/PR):
1. After code modification → `just check`
2. Before manual E2E testing → `just build`
3. Before git commit → `just gate` (runs check + build in one step)

## RELEASE PROCESS
- Fully automated via Semantic Release + GitHub Actions
- Trigger: push to `production` branch
- Automated steps: version bump → `CHANGELOG.md` → GitHub release → VSIX build/upload → sync back to `main`
- Files auto-updated: `package.json`, `src/webview/package.json`, `src/webview/package-lock.json`, `CHANGELOG.md`
- **Do NOT manually bump versions** — will be overwritten by next automated release
- Release config: `.releaserc.json` (not `package.json`)
- CI uses Node 22 (docs say 20 — stale)

## SEQUENCE DIAGRAMS

### Workflow Save
```
User → Toolbar → vscode-bridge → save-workflow.ts → file-service.ts → .vscode/workflows/
                                 validateWorkflow()  ensureDirectory()
                                                     writeFile()
       ← SAVE_SUCCESS ← ← ← ← ← ← ← ← ← ← ← ← ←
```

### MCP Tool Flow (external agent editing)
```
AI Agent → MCP Server :6282 → get_current_workflow → postMessage(GET_CURRENT_WORKFLOW_REQUEST) → App.tsx
                             ← workflow JSON ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ←
           MCP Server :6282 → apply_workflow  → postMessage(APPLY_WORKFLOW_FROM_MCP) → workflow-store.ts
```

### MCP Server/Tool Discovery
```
McpNodeDialog → LIST_MCP_SERVERS → mcp-handlers → mcp-cache-service (hit?) → mcp-sdk-client → MCP Server
                                                   (miss) → SDK.listServers() → cache → MCP_SERVERS_LIST
McpNodeDialog → GET_MCP_TOOLS → SDK.getTools() → MCP Server → MCP_TOOLS_LIST
```

## NOTES
- `test:e2e` script exists but `wdio.conf.ts` is absent — e2e not operational
- AI chat editing (`AiGenerationDialog`, `RefinementChatPanel`) is **discontinued** — maintenance only
- MCP server + `agent-ai-editor` skill is the **active** AI editing path
- `workflow-schema.toon` format reduces AI prompt token usage ~23% vs JSON
- Workflows live in workspace `.vscode/workflows/*.json` — not in extension source
- Node 22 in CI (docs claim 20 — docs are stale)
