# Lyceum ソースコード設計書

## 1. 目的
本設計書は、`apps/Lyceum` サブプロジェクトのソースコード構造と、Any-To-Any 推論・通信基盤としてのアーキテクチャを日本語で記述し、プロジェクト全体（特に `Pakila`）との統合における型システム上の制約（モナド境界）を明確化することを目的とします。

## 2. 全体構造の概観

Lyceum は、LLM（Gemini等）への推論リクエスト、MCP（Model Context Protocol）によるツール・リソース通信、およびサンドボックス実行エンジンの基盤を提供する純粋な I/O レイヤーです。

-   **`Types.lean`**: メッセージ、ツール、エラーなどの静的なデータモデル。
-   **`Inference.lean`**: LLM バックエンドや実行エンジンが実装すべき型クラス（インターフェース）。
-   **`Inference/Gemini.lean`**: Gemini API との通信（SSEパース等）を担う具象実装。
-   **`JsonRpc.lean` / `Server.lean`**: MCP サーバーとしての通信プロトコル実装。

## 3. コア・コンポーネントの詳細

### 3.1. `Types.lean` (データモデルとエラー体系)
Lyceum が扱う全データの「型」を定義する最も基礎的なモジュールです。
-   **`Message` / `MessagePart`**: テキスト、画像、音声、ツール呼び出しを透過的に扱う Any-To-Any メッセージのコア構造。
-   **`AppError`**: `LlmError`, `ExecutionError`, `ConfigError` など、Lyceum レイヤーで発生しうる全てのエラーを内包する列挙型（`Lyceum.AppError`）。
-   **MCP 構造体**: `Tool`, `Resource`, `Prompt` など、MCP 規格に準拠したデータ表現。
-   **`LlmRequestOptions`**: トークン数や温度などの推論パラメータ。

### 3.2. `Inference.lean` (インターフェースとモナド境界)
外部モジュール（Pakila等）が Lyceum の機能を利用するための契約（Contract）を定義します。
-   **`LlmBackend` 型クラス**:
    -   `streamChatCompletion : (history : List Message) → (options : Option LlmRequestOptions) → IO (Except AppError (List Message))`
    -   **【重要原則: IO モナド境界】**: このインターフェースは、抽象モナド `m` を一切使用せず、純粋に Lean 4 のネイティブな `IO` モナド上で定義されています。これにより、Lyceum は上位のオーケストレータ（Pakila）の固有のモナド設計に依存せず、独立した物理レイヤーとして機能します。

### 3.3. `Inference/Gemini.lean` (Gemini 具象実装)
`LlmBackend` インターフェースの Gemini API 用の具象実装です。
-   **`GeminiClient`**: APIのURL、キー、モデル名を保持する構造体。
-   **`LlmClient`**: `GeminiClient` のエイリアス（`abbrev LlmClient := GeminiClient`）として定義され、Lyceum の標準クライアントとしてエクスポートされます。
-   **JSON 変換と SSE パース**: `MessagePart` から `GeminiPart` への相互変換ロジックと、Server-Sent Events のチャンクパーサー（`parseSseChunk`）を実装します。
    -   **最適化**: JSON 経由での冗長な再パースを防ぐため、`GeminiPart` から `MessagePart` へのパターンマッチングによる直接変換（`geminiPartToMessageDirect`）および `curl` プロセスの終了コードに基づく厳密なエラーハンドリングが実装されています。

### 3.4. `Inference/Generic/` (ローカル推論エンジン & GGUF ロード)
ローカルでの GGUF モデルパースおよびトランスフォーマー演算を担うモジュール群です。
-   **`Architecture.lean`**:
    -   `ModelArchitecture`: 語彙サイズ（`vocabSize`）、隠れ層サイズ（`hiddenSize`）、層数（`numLayers`）、ヘッド数（`numHeads`）、ヘッド次元（`headDim`）を保持する静的構造体。
    -   `QuantizationType`: `F32`, `Q4_0`, `Q1_K` 等の量子化種別の列挙型。
-   **`Loader.lean`**:
    -   `loadRawGenericModel : (modelPath : String) → [Lyceum.Core.TerminalEnv IO] → IO (Except AppError RawGenericModel)`
    -   **契約と型不変条件**: GGUF ファイルメタデータサイズから `infoStartOff` を物理計算し、`IO.FS.Handle.seek` でテンソル領域の開始位置へ跳躍。物理シークとデータロードを実行し、`AppError` ドメインエラー型に安全にマッピングする。
-   **`KVCache.lean`**:
    -   `KVCache`: 各レイヤーごとの Key/Value テンソル状態。動的配列のリサイズコピーを排除し、再利用可能な構造として保持。
-   **`Kernel.lean`**:
    -   `runTransformerBlock`: RMSNorm, Multi-Head Attention (RoPE適用), FFN (SwiGLU) のトランスフォーマー評価ループ。
    -   `sampleTopP`: 温度スケーリングおよび Top-P (Nucleus) サンプリングアルゴリズム。

### 3.5. `Inference/Gemma/Native.lean` (物理演算・量子化デコード)
ローカル推論およびテンソルデコードを担う低レイヤモジュールです。
-   **デコーダ**: FP16 物理デコード、およびルックアップテーブル（LUT）方式を用いた高速量子化デコーダ（FP8, FP4, 1bit）を実装しています。
-   **演算の最適化**: `matmulNative`（行列積）および各デコーダにおいて、`Array.ofFn` を活用して一時的なヒープメモリの `push` や `set!` コピーを完全に排除した $\mathcal{O}(1)$ アロケーション設計を採用しています。

### 3.6. `Memory/VectorDB.lean` (ベクトルデータベース)
インメモリ型の類似度検索エンジンです。
-   **アロケーションフリー類似度演算**: `cosineSimilarity` において、`FloatArray` への一時的なメモリ詰め替えを排除し、単一ループ走査で内積とノルムを同時に計算することで計算効率を極大化しています。

### 3.7. `Core/Environment.lean` & `Core/IO.lean` (物理環境の抽象化)
OS 依存のファイル操作およびプロセス制御を型クラス `TerminalEnv` で抽象化します。
-   **`TerminalEnv IO`**: `fileRead`, `fileWrite`, `fileSeek`, `spawnProcess` 等の環境依存処理をカプセル化。テスト時の Mock 環境（Nomos Contract）差し替えと本番 `IO` モナド実行をシームレスに切り替えます。

### 3.8. `Server.lean` & `JsonRpc.lean` (MCP 通信基盤)
MCP (Model Context Protocol) 規格に準拠した JSON-RPC 2.0 通信ハンドラーです。
-   **`handleMessage`**: `initialize`, `tools/list`, `tools/call`, `resources/list`, `resources/read`, `prompts/get` 等のメッセージを透過的にパース・実行。
-   **防腐処理**: 入力エラーや不正 JSON に対し、ユーザー体験を損なうパニックを完全に防ぎ、ドメイン化された JSON-RPC エラーオブジェクトを安全に返却。

## 4. 横断的関心事とシステム統合の制約

### 4.1. Pakila との境界（IO vs m）
Lyceum の全ての通信・推論メソッドは `IO` モナドを返します。一方、上位フレームワークである Pakila は、テスト容易性や状態管理のために抽象モナド `m`（`[Monad m] [TerminalEnv m]` など）を用いています。

Pakila 側から Lyceum の `LlmBackend.streamChatCompletion` などを呼び出す際は、**Pakila 側で `[MonadLift IO m]` などの型クラス制約を通じて `IO` を `m` にリフトする**か、あるいは実装レイヤーで直接 `IO` として実行する必要があります。

### 4.2. 名前空間と型の一致
-   **`Lyceum.AppError`**: Pakila 内部で独自に `AppError` が定義されている場合、Lyceum の関数が返す `Except Lyceum.AppError ...` と型が衝突します。この場合、Pakila 側でエラー型の変換マッピングを実装するか、Lyceum のエラー型をそのまま引き回す設計に統一する必要があります。
-   **`Lyceum.LlmClient`**: 外部から Gemini クライントを使用する場合は、この名前空間を経由する必要があります。

