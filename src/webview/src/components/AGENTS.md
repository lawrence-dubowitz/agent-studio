# src/webview/src/components — UI Components

React components organized by domain. Total ~100 files across subdirectories.

## STRUCTURE
```
WorkflowEditor.tsx    # React Flow canvas; node/edge types, selection, validation, minimap
Toolbar.tsx           # Top action bar: save/export/run/load, feature toggles, AI entry points
NodePalette.tsx       # Node creation palette; launches creation dialogs
PropertyOverlay.tsx   # Right-side inspector for selected node properties
CommentaryPanel.tsx   # Live execution commentary side panel
StartMenu.tsx         # Welcome/onboarding menu
CanvasToolbar.tsx     # Canvas-level controls (zoom, fit, etc.)

nodes/                # Custom React Flow node renderers
  StartNode, EndNode, PromptNode, SkillNode, McpNode/, BranchNode,
  IfElseNode, SwitchNode, GroupNode, SubAgentNode, SubAgentFlowNode,
  CodexNode, AskUserQuestionNode, DeleteButton

dialogs/              # Modal/sidebar dialogs (all Radix UI)
  RefinementChatPanel.tsx  # AI chat sidebar (DISCONTINUED — maintenance only)
  [20 other dialogs for MCP, skill, Slack, codex, Claude API, etc.]

common/               # 21 reusable UI primitives
chat/                 # Refinement chat internals: MessageList, MessageBubble, MessageInput, etc.
edges/                # Custom React Flow edge renderers
mcp/                  # MCP tool/server UI (node dialog, parameter inputs)
mode-selection/       # AI tool/model selection UI
preview/              # Read-only preview canvas (PreviewCanvas.tsx)
toolbar/              # Toolbar dropdown subcomponents
```

## WHERE TO LOOK
| Task | Location |
|------|----------|
| Add a workflow node type | `nodes/` (new file) + register in `WorkflowEditor.tsx` + update schema |
| Add a dialog | `dialogs/` using `@radix-ui/react-dialog` |
| Modify canvas behavior | `WorkflowEditor.tsx` |
| Modify top toolbar | `Toolbar.tsx` + `toolbar/` |
| Add MCP UI | `mcp/` |
| Add node property UI | `PropertyOverlay.tsx` |
| Read-only preview | `preview/PreviewCanvas.tsx` |

## DIALOG IMPLEMENTATION
Every dialog must use `@radix-ui/react-dialog`. Set `zIndex` on `Dialog.Overlay`, not content.

```tsx
import * as Dialog from '@radix-ui/react-dialog';

export function MyDialog({ isOpen, onClose }: Props) {
  return (
    <Dialog.Root open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <Dialog.Portal>
        <Dialog.Overlay
          style={{
            position: 'fixed', inset: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.5)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            zIndex: 9999,  // 9999 | 10000 (nested) | 10001 (confirm)
          }}
        >
          <Dialog.Content>{/* content */}</Dialog.Content>
        </Dialog.Overlay>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
```

**Z-index tiers:**
| z-index | Use |
|---------|-----|
| 9999 | Standalone or parent dialog |
| 10000 | Nested child dialog |
| 10001 | Confirm/warning dialog |

**New dialog checklist:** uses Radix UI ✓ | Overlay has zIndex ✓ | ESC closes ✓ | Overlay click closes ✓

## CONVENTIONS
- Node types registered in `WorkflowEditor.tsx` `nodeTypes` map
- Discontinued AI chat features (`RefinementChatPanel`, `AiGenerationDialog`) are maintenance-only

## ANTI-PATTERNS
- Custom overlay/modal without Radix UI
- Z-index values outside the 9999/10000/10001 tiers
- Accessing stores directly in leaf components — prefer props or custom hooks
- Adding new AI chat features to `RefinementChatPanel` — discontinued path
