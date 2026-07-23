# Lyceum シナリオテスト・界面検証設計書

本ドキュメントは、全体最適原則（Global Optimization）および「環境はブラックボックスであり、シナリオテストこそ最重要」「エラー表示を排し適切なフォールバックを徹底する」という統合設計思想に基づき、`Lyceum` プロジェクトにおける結合動作保証、界面防腐、および非破壊自動復旧仕様を定義します。

---

## 1. 動作保証原則 (Core Testing Governance)

1. **シナリオテスト最優先原則 (E2E First)**
   - 単体テストの成功のみに依存せず、実機・本番環境と地続きのブラックボックスシナリオテスト（エンドツーエンド統合テスト）をシステム保証の絶対要件とする。
   - クライアントリクエストから推論バックエンド（Gemini API / Gemma ローカル推論）、ベクトルデータベース（VectorDB）検索、ツール実行に至る全ロングジャーニーを一気通貫で検証する。

2. **界面（アタックサーフェス）の防腐と最小化**
   - 不確実性が潜む外部環境（ネットワーク、OSファイルシーク、外部API、浮動小数点計算）との接触点（界面）を最外郭のゲートウェイモジュールに一元集中・集約する。
   - 界面を通過するすべてのデータは、境界直後で型安全な内部ドメインモデルに一括変換し、内部ロジックへの副作用・汚染を 100% 遮断する。

3. **エラー非表示と透過的フォールバック (Zero Panic UX)**
   - ユーザーや外部 MCP クライアントに対し、スタックトレースや生のエラーログ（`panic!`, `unhandled exception`）を一切露出させない。
   - ネットワーク瞬断、タイムアウト、壊れた GGUF メタデータ等の異常発生時は、透過的なリトライ、代替推論バックエンド（Gemini $\to$ Gemma ローカルフォールバック）、またはクリーンなドメインエラー応答（JSON-RPC 形式）へ自動制御する。

---

## 2. 界面別検証シナリオ (Boundary Verification Scenarios)

### 界面 A: MCP JSON-RPC 通信境界 (`Server.lean` / `JsonRpc.lean`)

| シナリオ ID | 入力条件 / 事象 | 期待される物理振る舞い | 検証基準 (Pass Criteria) |
| :--- | :--- | :--- | :--- |
| **SC-MCP-001** | クライアントから壊れた JSON / 不正な JSON-RPC 2.0 リクエストを受信 | 防腐層でパースエラーを検知し、クラッシュせずに JSON-RPC `-32700 Parse Error` オブジェクトを正常返却。 | システムプロセスが生存し、後続リクエストを処理可能。 |
| **SC-MCP-002** | 未定義のツール `tools/call` リクエストを受信 | スタックトレースを露出せず、`ToolNotFound` ドメインエラーを JSON-RPC レスポンスに変換して安全返却。 | プロセスが正常状態を維持し、パニックしない。 |
| **SC-MCP-003** | 高頻度な並行リクエストの投入 | JSON-RPC パイプラインがデッドロックやメモリリークを起こさずレスポンスを返却。 | メモリ消費が一定値（$\mathcal{O}(1)$ 増加範囲）に収まる。 |

### 界面 B: Gemini API ストリーム通信境界 (`Inference/Gemini.lean`)

| シナリオ ID | 入力条件 / 事象 | 期待される物理振る舞い | 検証基準 (Pass Criteria) |
| :--- | :--- | :--- | :--- |
| **SC-GEM-001** | `curl` プロセス実行時の DNS 解決失敗 / ネットワーク瞬断 | `child.wait` で非ゼロ終了コードをトラッキングし、即座に `AppError.NetworkError` として処理。 | 不正な JSON パースエラーに丸めず、適切なリトライ/フォールバックへ移行。 |
| **SC-GEM-002** | 複数パーツ（テキスト・ツール呼び出し・画像）を含む SSE ストリーム応答 | `parseSseChunk` が `List GeminiPart` を動的に走査し、`geminiPartToMessageDirect` パターンマッチで `MessagePart` へ一括変換。 | JSON 再パースを発生させず、マルチパーツが欠損なくドメインモデルへ反映される。 |
| **SC-GEM-003** | HTTP 429 (Rate Limit Exceeded) の発生 | 即座にリクエストを中断し、無駄なリクエストの繰り返しを行わずにローカル Gemma 推論エンジンへ透過的切り替え。 | TPM/RPM 制限超過時の無限ループが回避される。 |

### 界面 C: GGUF 物理ファイルロード境界 (`Inference/Generic/Loader.lean`)

| シナリオ ID | 入力条件 / 事象 | 期待される物理振る舞い | 検証基準 (Pass Criteria) |
| :--- | :--- | :--- | :--- |
| **SC-GGUF-001**| 壊れたメタデータを含む物理 GGUF ファイルの指定 | `getMetadataDataSize` パース過程で `Except.error` を即座にキャッチし、`AppError.ModelError` を返却。 | 境界外メモリシークや OOM（OutOfMemory）を発生させずに安全に中断。 |
| **SC-GGUF-002**| 正常な大容量 GGUF ファイルのロード | `infoStartOff` オフセットを数学的に正確に計算し、`IO.FS.Handle.seek` で直接シークロード。 | メモリ全ロードを行わず、`Std.HashMap String RawQuantizedTensor` が正確に構築される。 |
| **SC-GGUF-003**| FP8 / FP4 / 1bit 超低ビット量子化モデルのロード | ルックアップテーブル（LUT）が `initialize` 時にロードされ、推論時デコードが $\mathcal{O}(1)$ で引き当て可能。 | デコード時の追加ヒープメモリ確保が 0 であること。 |

---

## 3. シナリオテスト実行環境と決定性 (Deterministic Sandbox)

1. **Nomos Contract Mock 環境の活用**
   - `Lyceum.Core.TerminalEnv IO` インターフェースを介し、テスト実行時には `Nomos` の擬似決定論的環境（Mock TerminalEnv）を注入する。
   - ネットワークの遅延・瞬断・ファイルシークエラーを非決定的に発生させ、システムが100%安全に回復することを自動化されたプロパティベーステスト（PBT）で証明する。

2. **アロケーションフリー不変条件の自動検証**
   - `VectorDB` コサイン類似度計算および `matmulNative` 実行において、プロファイルツール（または Lean 4 VM アロケーションカウンター）を用い、実行中のヒープ割り当て回数が $\mathcal{O}(1)$（ゼロ増大）であることを自動検証する。

---

## 4. lbir / Symbol32 統合方針とテストコード実装状況

1. **`lbir` 準拠プログラミング**
   - 本プロジェクトの全 Lean 4 実装（`Lyceum`, `Lyceum.Core`, `Test`）は、`/home/pc241139/sandbox/lbir` に定義された Lean Bytecode Intermediate Representation (`lbir`) 基盤および依存関係と統一して記述される。
   - 文字コード処理においては `/home/pc241139/sandbox/Symbol32` (`Symbol32`) を標準採用する。

2. **統合テストスイートの実装完備 (`Test.lean`)**
   - **Phase 1 (Nomos Trace)**: `Lyceum/Test/ServerTest.lean` による JSON-RPC 2.0 正常/異常トレースおよび未定義ツール防腐検証。
   - **Phase 1.2 (Allocation Invariants)**: `Lyceum/Test/KVCacheTest.lean` によるメモリキャッシュ再利用性の保証。
   - **Phase 2 (Physical Boundary)**: `Lyceum/Test/PhysicalIOTest.lean` による OS ファイルアクセス権限・不払拒否・存在しないプロセストラッキングの物理実走検証。

