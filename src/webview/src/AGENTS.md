# src/webview/src — React Webview App

Separate React/Vite/TypeScript app; own `package.json`, `tsconfig.json`, `vite.config.ts`. Entry: `main.tsx`.

## STRUCTURE
```
main.tsx            # Acquires vscode API, sets up providers, sends WEBVIEW_READY
App.tsx             # Root: mode-switching, extension message dispatch, global layout
components/         # UI layer (see components/AGENTS.md)
stores/             # Zustand app state
  workflow-store.ts # Main canvas state + Zustand temporal (undo/redo)
  refinement-store.ts  # AI refinement/chat state (localStorage-backed)
  commentary-store.ts  # Execution commentary state (localStorage-backed)
hooks/              # Local UI behavior hooks (resize, collapse, theme, wizards)
services/           # Host bridge + domain service APIs
  vscode-bridge.ts  # Typed requestId-correlated postMessage bridge (primary)
  refinement-service.ts
  slack-integration-service.ts
  ai-generation-service.ts
  mcp-service.ts
  workflow-service.ts
  skill-browser-service.ts
  command-browser-service.ts
i18n/               # Translations + I18nProvider/hook
contexts/           # ResponsiveFontProvider (non-i18n context)
constants/          # Node labels/icons, announcements, tour steps
utils/              # Workflow diffing, validation, template/frontmatter helpers
types/              # Local component state type definitions
styles/             # Global CSS
```

## STATE MANAGEMENT
- **Zustand** is the primary app-state layer (not Redux/context)
- `workflow-store.ts`: canvas nodes/edges + **zundo temporal middleware** for undo/redo + canvas revision counter
- `refinement-store.ts`, `commentary-store.ts`: feature state persisted to **localStorage**
- Transient UI state (dialog visibility, loading flags) uses local React `useState`
- `I18nProvider` and `ResponsiveFontProvider` use React Context

## MESSAGE PROTOCOL
- All outbound: `window.acquireVsCodeApi().postMessage(msg)` — via `vscode-bridge.ts`
- All inbound: dispatched by `App.tsx` via `window.addEventListener('message', ...)`
- Types from `src/shared/types/messages.ts` — do not define message types locally
- Async requests: send with `requestId`, listen for matching response, timeout + cleanup
- Startup sequence: `main.tsx` → `WEBVIEW_READY` → extension → `INITIAL_STATE` → `App.tsx` enters edit mode

## CONVENTIONS
- New host calls: add type to shared `messages.ts`, implement in `vscode-bridge.ts`, handle in `App.tsx`
- New dialogs: `@radix-ui/react-dialog` only; z-index 9999/10000/10001
- Tests: Vitest (`npm test` from repo root); no Jest
- Path aliases: `@/*` → this `src/` dir, `@shared/*` → `src/shared/`

## EXTERNAL LINK PATTERN
`<a href>` and `window.open()` are blocked in the webview. Use:

```tsx
import { ExternalLink } from 'lucide-react';
import { openExternalUrl } from '../../services/vscode-bridge';

<span
  role="button"
  tabIndex={0}
  onClick={() => openExternalUrl('https://example.com')}
  onKeyDown={(e) => {
    if (e.key === 'Enter' || e.key === ' ') openExternalUrl('https://example.com');
  }}
  style={{ display: 'inline-flex', cursor: 'pointer', color: 'var(--vscode-textLink-foreground)' }}
  title="Open documentation"
>
  <ExternalLink size={12} />
</span>
```

- `openExternalUrl()` delegates to `vscode.env.openExternal` via extension host
- Icon size: match surrounding text (11–14px)
- Add `e.stopPropagation()` when inside accordion/collapsible parents
- See usage in: `McpServerSection.tsx`, `CodexNodeDialog.tsx`, `ClaudeApiUploadDialog.tsx`

## ANTI-PATTERNS
- Defining message types locally — edit `src/shared/types/messages.ts`
- `<a href>` / `window.open()` — use `openExternalUrl()`
- Adding new dialogs without Radix UI Dialog
- Mutating `workflow-store` state outside Zustand actions
