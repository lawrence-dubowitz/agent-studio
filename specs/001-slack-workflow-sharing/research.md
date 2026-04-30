# Phase 0 調査: Slack統合型ワークフロー共有

**Feature**: 001-slack-workflow-sharing
**Date**: 2025-11-22
**Status**: Complete

## 概要

このドキュメントは、Slack統合機能の実装に必要な技術選定と設計判断を文書化します。主に以下の4つの「NEEDS CLARIFICATION」項目を解決します:

1. Slack Web API ライブラリのバージョン選定
2. Slack OAuth 認証フローの実装詳細
3. OAuthコールバック用ローカルHTTPサーバーの技術選定
4. VSCode Secret Storageの実装詳細

---

## 1. Slack Web API ライブラリ (@slack/web-api)

### Decision
`@slack/web-api` バージョン **7.x** (latest stable) を採用

### Rationale

**調査結果**:
- `@slack/web-api` は Slack公式のNode.js SDKであり、TypeScriptサポートが充実
- バージョン 7.x は以下の機能を提供:
  - `chat.postMessage` - リッチメッセージカード投稿
  - `conversations.list` - チャンネル一覧取得
  - `files.upload` - ファイルアップロード（ワークフローJSON添付）
  - `search.messages` - 過去メッセージ検索
  - Rate limit handling - 自動リトライ機能
  - TypeScript型定義完備

**必要な主要API**:
```typescript
import { WebClient } from '@slack/web-api';

const client = new WebClient(token);

// 1. ワークフロー共有 (リッチメッセージ投稿)
await client.chat.postMessage({
  channel: channelId,
  blocks: [...], // Slack Block Kit形式
  attachments: [{
    fallback: 'Workflow file',
    // ワークフローJSONファイル添付
  }]
});

// 2. ファイルアップロード (ワークフローJSON)
await client.files.uploadV2({
  channel_id: channelId,
  file: workflowJsonBuffer,
  filename: 'workflow.json'
});

// 3. チャンネル一覧取得
await client.conversations.list({
  types: 'public_channel,private_channel'
});

// 4. 過去共有ワークフロー検索
await client.search.messages({
  query: 'workflow filename:*.json'
});
```

### Alternatives Considered

| Alternative | Pros | Cons | 却下理由 |
|------------|------|------|---------|
| REST API直接呼び出し | 依存関係なし | 型安全性なし、エラーハンドリング自前実装 | TypeScript型定義が重要 |
| `@slack/bolt` | フレームワーク機能豊富 | 過剰な依存関係、VS Code拡張に不適 | 軽量なWeb APIのみで十分 |

### Implementation Notes

- **Rate Limit対応**: `@slack/web-api` は自動リトライ機能を提供（Tier 3: 20+ req/min）
- **Error Handling**: `WebAPICallError` を適切にハンドリング
- **Token管理**: VSCode Secret Storageに保存されたトークンを使用

---

## 2. Slack OAuth 認証フロー (@slack/oauth)

### Decision
`@slack/oauth` **v2.7.x** を使用せず、**手動でOAuth 2.0フローを実装**

### Rationale

**`@slack/oauth` の問題点**:
- Express.jsベースのWebサーバー起動を前提としており、VS Code拡張機能に組み込むには過剰
- VS Code拡張機能は軽量なローカルHTTPサーバーのみで十分
- 依存関係の肥大化を避けたい

**手動実装のメリット**:
- 必要最小限のコード（< 100行）
- VS Code拡張機能の制約に最適化
- デバッグが容易

**OAuth 2.0 フロー設計**:

```
[VS Code Extension] → [ブラウザ] → [Slack OAuth] → [ローカルサーバー] → [VS Code Extension]
```

**実装ステップ**:

1. **Authorization URL生成**:
```typescript
const authUrl = `https://slack.com/oauth/v2/authorize?` +
  `client_id=${SLACK_CLIENT_ID}&` +
  `scope=channels:read,chat:write,files:write,groups:read&` +
  `redirect_uri=http://localhost:${EPHEMERAL_PORT}/oauth/callback`;

vscode.env.openExternal(vscode.Uri.parse(authUrl));
```

2. **ローカルHTTPサーバー起動** (エフェメラルポート):
```typescript
import * as http from 'http';

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url!, `http://localhost:${port}`);
  const code = url.searchParams.get('code');

  if (code) {
    // Step 3: トークン交換
    const tokenResponse = await fetch('https://slack.com/api/oauth.v2.access', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: SLACK_CLIENT_ID,
        client_secret: SLACK_CLIENT_SECRET,
        code: code,
        redirect_uri: `http://localhost:${port}/oauth/callback`
      })
    });

    const { access_token } = await tokenResponse.json();

    // Step 4: トークン保存 (VSCode Secret Storage)
    await context.secrets.store('slack-access-token', access_token);

    // Step 5: 成功レスポンス
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end('<h1>認証成功!</h1><p>このウィンドウを閉じてVS Codeに戻ってください。</p>');

    server.close();
  }
});

server.listen(0); // エフェメラルポート
const port = (server.address() as AddressInfo).port;
```

3. **トークンリフレッシュ対応**:
   - Slack OAuth v2 は `refresh_token` を提供しない（長期間有効な `access_token` のみ）
   - トークン失効時は再認証をユーザーに促す

### Alternatives Considered

| Alternative | Pros | Cons | 却下理由 |
|------------|------|------|---------|
| `@slack/oauth` | 公式ライブラリ | Express.js依存、過剰な機能 | VS Code拡張に不適 |
| Webviewベース認証 | UIが統合される | Slack OAuthがiframe禁止、CORSエラー | 技術的に実現不可 |

---

## 3. OAuthコールバック用ローカルHTTPサーバー

### Decision
Node.js標準ライブラリ `http` モジュールを使用（**Express.js不使用**）

### Rationale

**Express.js不使用の理由**:
- OAuthコールバックは1回限りの単純なHTTPリクエスト処理
- Express.jsの機能（ルーティング、ミドルウェア）は不要
- 依存関係の追加を避け、バンドルサイズを最小化

**Node.js `http` モジュールの利点**:
- 標準ライブラリのため追加依存なし
- 軽量（< 50行で実装可能）
- VS Code Extension Hostで動作保証

**実装例**:
```typescript
import * as http from 'http';
import * as vscode from 'vscode';

export class OAuthCallbackServer {
  private server: http.Server | null = null;
  private port: number = 0;

  async start(): Promise<number> {
    return new Promise((resolve, reject) => {
      this.server = http.createServer(this.handleRequest.bind(this));

      this.server.listen(0, () => { // エフェメラルポート (OS割り当て)
        const address = this.server!.address() as AddressInfo;
        this.port = address.port;
        console.log(`OAuth callback server listening on port ${this.port}`);
        resolve(this.port);
      });

      this.server.on('error', reject);
    });
  }

  private async handleRequest(req: http.IncomingMessage, res: http.ServerResponse) {
    const url = new URL(req.url!, `http://localhost:${this.port}`);

    if (url.pathname === '/oauth/callback') {
      const code = url.searchParams.get('code');
      const error = url.searchParams.get('error');

      if (error) {
        res.writeHead(400, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end('<h1>認証エラー</h1><p>Slack認証に失敗しました。</p>');
        this.close();
        return;
      }

      if (code) {
        // トークン交換処理（省略）
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end('<h1>認証成功!</h1><p>VS Codeに戻ってください。</p>');
        this.close();
      }
    } else {
      res.writeHead(404);
      res.end();
    }
  }

  close() {
    if (this.server) {
      this.server.close();
      this.server = null;
    }
  }
}
```

**セキュリティ考慮事項**:
- **CSRF対策**: `state` パラメータを使用してリクエスト検証
- **タイムアウト**: サーバーは30秒後に自動クローズ
- **localhost限定**: `127.0.0.1` にバインドし外部アクセスを防止

### Alternatives Considered

| Alternative | Pros | Cons | 却下理由 |
|------------|------|------|---------|
| Express.js | 開発者に馴染みがある | 依存関係追加、過剰な機能 | 単純なコールバックに不要 |
| `fastify` | 軽量、高速 | 依存関係追加 | 標準ライブラリで十分 |

---

## 4. VSCode Secret Storage 実装詳細

### Decision
VSCode Extension API の `context.secrets` を使用してSlack OAuth トークンを暗号化保存

### Rationale

**VSCode Secret Storage の特徴**:
- OS標準のキーチェーン/資格情報マネージャーに保存（暗号化）
  - macOS: Keychain
  - Windows: Credential Manager
  - Linux: libsecret
- VS Code 1.53.0+ で利用可能
- 同期設定が有効な場合、デバイス間で暗号化同期される
- 機密情報の平文保存を回避

**実装例**:

```typescript
import * as vscode from 'vscode';

export class SlackTokenManager {
  private static readonly TOKEN_KEY = 'slack-oauth-access-token';
  private static readonly WORKSPACE_KEY = 'slack-workspace-id';

  constructor(private context: vscode.ExtensionContext) {}

  // トークン保存
  async saveToken(accessToken: string, workspaceId: string): Promise<void> {
    await this.context.secrets.store(SlackTokenManager.TOKEN_KEY, accessToken);
    await this.context.secrets.store(SlackTokenManager.WORKSPACE_KEY, workspaceId);
  }

  // トークン取得
  async getToken(): Promise<string | undefined> {
    return await this.context.secrets.get(SlackTokenManager.TOKEN_KEY);
  }

  // トークン削除（ログアウト時）
  async deleteToken(): Promise<void> {
    await this.context.secrets.delete(SlackTokenManager.TOKEN_KEY);
    await this.context.secrets.delete(SlackTokenManager.WORKSPACE_KEY);
  }

  // トークン有効性チェック
  async validateToken(): Promise<boolean> {
    const token = await this.getToken();
    if (!token) return false;

    try {
      const client = new WebClient(token);
      await client.auth.test(); // Slack API: トークン検証
      return true;
    } catch (error) {
      // トークン無効 → 削除
      await this.deleteToken();
      return false;
    }
  }
}
```

**セキュリティベストプラクティス**:
- トークンは決してログに出力しない
- トークンはメモリ上で最小限の時間のみ保持
- 拡張機能アンインストール時は自動的に削除される

**エラーハンドリング**:
```typescript
try {
  await tokenManager.saveToken(accessToken, workspaceId);
} catch (error) {
  vscode.window.showErrorMessage(
    'Slackトークンの保存に失敗しました。OSのキーチェーンへのアクセスを確認してください。'
  );
  console.error('Secret storage error:', error);
}
```

### Alternatives Considered

| Alternative | Pros | Cons | 却下理由 |
|------------|------|------|---------|
| `.vscode/settings.json` | 実装簡単 | 平文保存、セキュリティリスク | 機密情報の平文保存は不可 |
| 環境変数 | 開発時便利 | ユーザーが手動設定必要 | UX悪い |
| 独自暗号化 + ファイル保存 | 完全制御可能 | セキュリティリスク、車輪の再発明 | OS標準機能を信頼すべき |

---

## 5. 機密情報検出パターン

### Decision
正規表現ベースのパターンマッチングを使用（拡張可能設計）

### Rationale

**検出対象パターン**:

```typescript
export const SENSITIVE_PATTERNS = {
  // AWS認証情報
  AWS_ACCESS_KEY: /AKIA[0-9A-Z]{16}/g,
  AWS_SECRET_KEY: /[0-9a-zA-Z/+=]{40}/g,

  // APIキー (一般)
  API_KEY: /api[_-]?key["\s:=]+["']?([0-9a-zA-Z-_]{20,})/gi,

  // トークン (一般)
  TOKEN: /token["\s:=]+["']?([0-9a-zA-Z-_\.]{20,})/gi,

  // Slack Token
  SLACK_TOKEN: /xox[baprs]-[0-9a-zA-Z-]{10,}/g,

  // GitHub Personal Access Token
  GITHUB_TOKEN: /ghp_[0-9a-zA-Z]{36}/g,

  // 秘密鍵
  PRIVATE_KEY: /-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----/g,

  // パスワード (シンプルな検出)
  PASSWORD: /password["\s:=]+["']?([^\s"']{8,})/gi,
};

export class SensitiveDataDetector {
  detect(workflowJson: string): Array<{ type: string; value: string; position: number }> {
    const findings: Array<{ type: string; value: string; position: number }> = [];

    for (const [type, pattern] of Object.entries(SENSITIVE_PATTERNS)) {
      const matches = workflowJson.matchAll(pattern);
      for (const match of matches) {
        findings.push({
          type,
          value: this.maskValue(match[0]),
          position: match.index!
        });
      }
    }

    return findings;
  }

  private maskValue(value: string): string {
    // 最初の4文字と最後の4文字のみ表示
    if (value.length <= 8) return '***';
    return `${value.substring(0, 4)}...${value.substring(value.length - 4)}`;
  }
}
```

**拡張可能性**:
- `.vscode/settings.json` でカスタムパターン追加可能:
```json
{
  "claudeCodeWorkflowStudio.slackIntegration.customSensitivePatterns": [
    {
      "name": "Custom API Key",
      "pattern": "my-custom-pattern-[0-9a-f]{32}"
    }
  ]
}
```

**ユーザー警告UI**:
```typescript
const findings = detector.detect(workflowJson);
if (findings.length > 0) {
  const message = `機密情報が検出されました:\n${findings.map(f => `- ${f.type}: ${f.value}`).join('\n')}`;
  const action = await vscode.window.showWarningMessage(
    message,
    { modal: true },
    '続行',
    'キャンセル'
  );

  if (action !== '続行') {
    return; // 共有中止
  }
}
```

### Alternatives Considered

| Alternative | Pros | Cons | 却下理由 |
|------------|------|------|---------|
| ML/AIベース検出 | 高精度 | 実装複雑、依存関係大 | 過剰 |
| 外部API (e.g., GitGuardian) | 高精度、メンテナンス不要 | ネットワーク依存、コスト | プライバシー懸念 |

---

## 6. Slack Block Kit メッセージ設計

### Decision
Slack Block Kit を使用してリッチメッセージカードを作成

### Block Kit構造

```typescript
export function buildWorkflowMessageBlocks(workflow: Workflow, author: string): any[] {
  return [
    {
      type: 'header',
      text: {
        type: 'plain_text',
        text: `🔧 Workflow: ${workflow.name}`
      }
    },
    {
      type: 'section',
      fields: [
        { type: 'mrkdwn', text: `*Author:*\n${author}` },
        { type: 'mrkdwn', text: `*Version:*\n${workflow.version}` },
        { type: 'mrkdwn', text: `*Nodes:*\n${workflow.nodes.length}` },
        { type: 'mrkdwn', text: `*Created:*\n${new Date().toISOString()}` }
      ]
    },
    {
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: workflow.description || '_No description_'
      }
    },
    {
      type: 'actions',
      elements: [
        {
          type: 'button',
          text: { type: 'plain_text', text: '📥 Import to VS Code' },
          style: 'primary',
          value: workflow.id,
          action_id: 'import_workflow'
        }
      ]
    },
    {
      type: 'context',
      elements: [
        {
          type: 'mrkdwn',
          text: `Shared from Agent Studio`
        }
      ]
    }
  ];
}
```

**インタラクティブ機能**:
- 「Import to VS Code」ボタン → Slack App がdeep linkを生成 → VS Code拡張機能がハンドリング

---

## まとめ

### 最終的な技術スタック

| コンポーネント | 技術選定 | バージョン |
|--------------|---------|----------|
| Slack API連携 | `@slack/web-api` | 7.x (latest) |
| OAuth認証 | 手動実装 (Node.js `http`) | - |
| ローカルHTTPサーバー | Node.js `http` 標準ライブラリ | - |
| トークン保存 | VSCode Secret Storage | VSCode 1.53.0+ |
| 機密情報検出 | 正規表現パターンマッチング | - |
| メッセージUI | Slack Block Kit | v2 |

### すべての NEEDS CLARIFICATION 解決

✅ **Slack Web API**: `@slack/web-api` v7.x 採用
✅ **Slack OAuth**: 手動実装（`@slack/oauth` 不使用）
✅ **HTTPサーバー**: Node.js `http` 標準ライブラリ（Express.js 不使用）
✅ **Secret Storage**: VSCode `context.secrets` API 使用

### 次のステップ

Phase 1 (Design & Contracts) に進み、以下を生成:
- `data-model.md`: ワークフロー共有のデータモデル
- `contracts/`: Slack API呼び出し仕様
- `quickstart.md`: 開発者向けクイックスタートガイド
