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

## 4. テストと検証
- **Nomos Contract**: `nomos` の提供する Mock 環境を用いて、LLM の不規則な出力に対するロジックの堅牢性を決定論的に検証せよ。
- **Zero Warning**: 警告を含むコードのコミットは、統治不全とみなし厳禁とする。
