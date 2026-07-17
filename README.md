# Lyceum: Provable LLM Control Plane & RAG Hub

[![Language](https://img.shields.io/badge/language-Lean_4-orange.svg)](https://leanprover.github.io/)
[![Governance](https://img.shields.io/badge/governance-HV--CAD-blue.svg)](../HV-CAD-Framework)
[![Verified-by](https://img.shields.io/badge/verified--by-Nomos-green.svg)](../nomos)

**Lyceum** (リュケイオン) は、Lean 4 を用いて構築された、形式検証済みの LLM 駆動型 MCP (Model Context Protocol) サーバーです。
あらゆる AI クライアントに対し、数理的に安全性が保証された推論、RAG (Retrieval-Augmented Generation)、およびツール実行能力を提供します。

## 🏛️ プロジェクトの姿 (End-State)

- **知能のハブ**: 複数の LLM バックエンドと知識ソース（Vector DB, File System）を統合管理。
- **数理的防護**: `Nomos` テストフレームワークにより、不変条件を破る挙動を物理的に排除。
- **MCP 準拠**: 標準プロトコルを通じて、Gemini CLI や IDE 等からシームレスに利用可能。
- **Any-To-Any マルチモーダル**: テキスト、画像、音声を含む高度なコンテキストの受け渡し。

## 📂 ディレクトリ構造

- `lyceum/`: コアロジック (MCP, RAG, Inference)
- `GEMINI.md`: 統治憲法。
- `DESIGN_SPEC.vlog`: 設計の物理的エンコード。
- `lakefile.toml`: プロジェクト構成と Nomos への依存定義。

## 🚀 開発の現状

現在は **Phase 1.5: 量子化対応と演算最適化** 段階です。
-   **プロトコル定義**: `nomos` 形式検証と整合した MCP 基礎規格の定義。
-   **量子化サポート**: ローカル推論向けに FP16 物理デコーダ、および静的ルックアップテーブル（LUT）による超低ビット（FP8, FP4, 1bit）デコーダを統合。
-   **演算最適化**: テンソル積および量子化デコーダの $\mathcal{O}(1)$ アロケーション化、VectorDB のアロケーションフリー類似度演算の適用により、実行効率を劇的に向上。

---
"知能は確率の中に生まれるが、その統治は数理の中にのみ存在する。" —— Lyceum 開発哲学より
