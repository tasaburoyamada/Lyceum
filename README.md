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

現在は **Phase 1: 基礎プロトコル定義** 段階です。`nomos` フレームワークを用いたテスト駆動開発により、MCP 規格の型定義とバリデーションロジックの構築を進めています。

---
"知能は確率の中に生まれるが、その統治は数理の中にのみ存在する。" —— Lyceum 開発哲学より
