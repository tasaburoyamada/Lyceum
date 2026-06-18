# Lyceum Sub-Project Instructions (HV-CAD Governance)

本ファイルは `Lyceum` サブプロジェクトにおける AI の挙動を規定し、`Nomos` フレームワークによる統治を強制する。

## 1. 開発の基本原則
- **Nomos First**: 全ての新機能およびプロトコル実装は、`nomos` で定義された不変条件（不変則）に基づく検証を伴わなければならない。
- **End-State Driven**: `DESIGN_SPEC.vlog` に記述された「完成形」への収束を最優先し、場当たり的なラッパー実装を排除せよ。
- **Surgical Delta**: 既存の証明済みコードの修正は、`replace` による最小限のパッチ適用を原則とする。

## 2. アーキテクチャ拘束
- **MCP Native**: 外部インターフェースは MCP (Model Context Protocol) 規格に完全準拠せよ。
- **Lean 4 Verification**: 状態遷移、データのパース、ツール実行ロジックは、型システムによって矛盾がないことを物理的に保証せよ。
- **Any-To-Any Multi-modal**: `Pakila` の `MessagePart` 定義を継承し、テキスト以外のモダリティも透過的に扱えるように設計せよ。

## 3. 実装プロトコル
- **No Stub Policy**: プロトコル変換や RAG 検索ロジックにスタブを置かず、常に Lean 4 の kernel または物理的な FFI / I/O に基づいた実装を行え。
- **Vlog Synchronization**: 重要な設計変更やバイナリ評価（選択）が発生した際は、即座に `DESIGN_SPEC.vlog` を更新し、ステートを永続化せよ。

## 4. LLM Backend (Local & Remote)
`Lyceum`は、Gemini APIのようなリモートLLMだけでなく、Gemma GGUFモデルのようなローカルLLMもサポートする。

### 4.1. ローカルLLM統合 (Gemma GGUF)
- **Gemma GGUF Model Loading (`Lyceum.Inference.Gemma.Loader`)**: GGUF形式のGemmaモデルのロード、パース、RawTensorへの変換を担当。
- **Raw/Verified Model Representation (`Lyceum.Inference.Gemma.Raw`, `Lyceum.Inference.Gemma.Embedding`)**: 未検証のRawTensor表現から、型安全な検証済みモデル表現への変換を含む。
- **Tensor Operations (`LeanTensor`)**: ネイティブFFIを介した効率的なテンソル演算を統合（`Lyceum.Inference.Gemma.Native`）。
- **Tokenizer (`Lyceum.Tokenizer`)**: UnigramおよびWordPieceトークン化、語彙管理（`Vocab`）、正規化/非正規化処理をサポート。

### 4.2. メモリと知識ベース (`Lyceum.Memory`)
- **VectorDB (`Lyceum.Memory.VectorDB`)**: インメモリー型のベクトルデータベースを実装し、ベクトル埋め込みを用いたセマンティック検索を可能にする。
- **NativeEmbedding (`Lyceum.Memory.NativeEmbedding`)**: ネイティブモデル（Gemma）を使用したテキストのベクトル埋め込み生成を抽象化。
- **SemanticResponder (`Lyceum.Memory.SemanticResponder`)**: 知識ベースに対するユーザーのクエリ応答をセマンティックに処理。
- **TokenManager (`Lyceum.Memory.TokenManager`)**: メッセージのトークン数見積もりや履歴の管理。

### 4.3. 環境インターフェース (`Lyceum.Core.Environment`)
- **TerminalEnv (`Lyceum.Core.Interface`, `Lyceum.Core.Environment`)**: ファイルI/Oやプロセス実行などの物理環境操作を抽象化する型クラス。ローカルLLMのファイルアクセスに必要。

## 5. テストと検証
- **Nomos Contract**: `nomos` の提供する Mock 環境を用いて、LLM の不規則な出力に対するロジックの堅牢性を決定論的に検証せよ。
- **Zero Warning**: 警告を含むコードのコミットは、統治不全とみなし厳禁とする。
