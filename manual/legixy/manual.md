# legixy v3 取扱説明書

**対象バージョン:** v0.4.0-alpha4（Phase 2 Block A/B/D/E/F 完成、ISSUE-001/002/003/004/005 解決）
**作成日:** 2026-04-19（最終更新: 2026-04-28）
**ステータス:** **v0.4.0-alpha4**。Phase 2 機能リリース完成（サブノード embedding / IdSemanticDrift / compile_context UX / refresh-subnodes）。GA は rc1（app Phase 2 比較計測）通過後。

---

## 目次

1. [概要](#1-概要)
2. [v3 での主要変更点（v0.1.0 からの差分）](#2-v3-での主要変更点)
   - 2.5 [プロセス非依存性（ICONIX 以外でも使える）](#25-プロセス非依存性iconix-以外でも使える)
3. [システム構成](#3-システム構成)
4. [動作環境](#4-動作環境)
5. [インストール手順](#5-インストール手順)
6. [プロジェクトへの導入](#6-プロジェクトへの導入)
7. [CLI コマンドリファレンス](#7-cli-コマンドリファレンス)
8. [MCP サーバーの設定](#8-mcp-サーバーの設定)
9. [CLAUDE.md の運用ルール記述](#9-claudemd-の運用ルール記述)
10. [運用フロー](#10-運用フロー)
11. [設定リファレンス（.trace-engine.toml）](#11-設定リファレンス)
12. [v0.1.0 からの移行](#12-v010-からの移行)
13. [トラブルシューティング](#13-トラブルシューティング)
14. [ID 再定義検出（IdRedefined / IdSemanticMismatch / IdSemanticDrift、ISSUE-001）](#14-id-再定義検出idredefined--idsemanticmismatch--idsemanticdriftissue-001)
15. [drift baseline と snapshot 運用（ISSUE-002）](#15-drift-baseline-と-snapshot-運用issue-002)
16. [refresh-subnodes（見出しリネーム連鎖変化対応、Phase 2 Block E、v0.4.0-alpha4）](#16-refresh-subnodes見出しリネーム連鎖変化対応phase-2-block-ev040-alpha4)

---

## 1. 概要

**legixy v3** は、ソフトウェアプロジェクトの成果物間のトレーサビリティを自動検証するツール群である。v0.1.0 の単純なマトリクスベースから **有向グラフベース** へアーキテクチャを刷新し、サブノード粒度・Contextual Retrieval・フィードバックループ強化を実装した次世代版。

### ツールの役割

| ツール | 役割 | 利用者 |
|--------|------|--------|
| **Rust CLI** (`legixy` v0.2.0) | 検証・初期化・マイグレーション・フィードバック・承認（Admin Surface） | 人間（開発者・管理者） |
| **MCP サーバー** (`traceability-mcp`) | コンテキスト解決・観察・監査（Agent Surface） | Claude Code（AI エージェント） |

### 5 つの価値（v0.1.0 の 3 価値から拡張）

1. **事前ガイダンス** — コードを書く前に「何を参照すべきか」を教える
2. **事後検証** — 成果物の ID 整合性・意味的整合性を検証する
3. **フィードバックループ** — 検出結果から改善提案を生成し、人間が承認する
4. **サブノード粒度** — ドキュメント内の見出し単位で粒度制御（v3 新規）
5. **Contextual Retrieval** — LLM による文脈合成で意味的検索を強化（v3 新規、デフォルト無効）

### 設計原則

- 判断は全て人間に委ねる。ツールはレビュー対象を絞り込むのみ
- 成果物の自動修正・グラフの自動編集は禁止
- 単一バイナリ。Python 依存なし。ランタイムのネットワーク依存なし
- Proposal は提案のみ。承認するまで何も変わらない
- **Admin Surface（CLI）と Agent Surface（MCP）の明示的分離**（MCP-INV-1）

---

## 2. v3 での主要変更点

### アーキテクチャ差分（v0.1.0 → v3）

| 項目 | v0.1.0 | v3 |
|------|--------|-----|
| データ構造 | `matrix.md`（Markdown table） | **`graph.toml`**（TOML、多対多エッジ対応） |
| マトリクス役割 | 一次データ | graph.toml からの派生ビュー（後方互換） |
| DB 名 | `feedback.db` | **`engine.db`**（統合 SQLite、WAL 必須） |
| embedding | `vectors.bin`（バイナリ） | **engine.db 内 `embeddings` テーブル** |
| サブノード | 非対応 | **対応**（`#anchor` / `#s:explicit` 識別子、v3 新規） |
| Contextual Retrieval | なし | **REQ.06 対応**（デフォルト無効、LLM API で context 合成） |
| Rust crate 構造 | 5 crates | **10 crates**（te-core/te-graph/te-db/te-ctx/te-check/te-nav/te-embed/te-feedback/te-mig/te-cli） |
| CLI バイナリ生成元 | `cli/` crate | **`crates/te-cli/`** |
| サブコマンド数 | 13 | **17**（+ init / migrate / audit / calibrate / report の整理） |

### 新規 / 拡張コマンド

- **`init`**: 新規 v3 プロジェクト初期化（v0.1.0 にもあったが v3 で拡張）。**2026-04-20 INIT Block**: ICONIX 標準 8 typecode（SPEC/UC/RB/SEQ/DD/TS/TC/SRC）の `[id.types.*]` と `[id.document_id]` を自動生成、`tests/` と `src/` を含む 10 ディレクトリ + 9 `.gitkeep` を配置
- **`migrate --from <v0.1.0 root>`**: v0.1.0 → v3 自動マイグレーション（**新規**）
- **`context --granularity <document|subnode>`**: サブノード粒度制御（**新規**）
- **`observe <category> <message>`**: 位置引数に変更（v0.1.0 の `--category` / `--message` フラグは **廃止**）。`--related-id` / `--target-file` / `--missing-doc` / `--source-glob` を**新規**追加
- **`audit --limit <N>`**: context_log の直近 N 件取得（**新規**、MCP `get_compile_audit` の下位層）
- **`report [--json]`**: 全リンク類似度 + リンク候補一覧（**2026-04-20 RPT Block で stub → 本実装**）
- **`calibrate [--buckets N] [--json]`**: 類似度分布ヒストグラム + 3 閾値表示（**2026-04-20 CAL Block で stub → 本実装**、`--buckets` 既定 10）

### 2026-04-20 追加の実装完了事項

- **SEM Block**: `check`（`--formal` なし）の **SemanticChecker 実装**（旧 stub 解消）。SemanticSimilarity（閾値未満 Warning）/ LinkCandidate（閾値超過 Info、v2 互換）/ Drift（content_hash 不一致 Warning）の 3 カテゴリを `check` 時に自動発火
- **INIT Block**: init 直後の `check --formal` が types 設定なしでも動作する UX 改善（Finding 1 対応）。`[id].area = "XX"` 残留時は Info で誘導、`[id.document_id].pattern` に `{id}` プレースホルダが誤記されると Warning
- **RPT / CAL Block**: 全体監査と閾値キャリブレーションが v3 単体で可能に（v0.1.0 並行運用不要）

---

## 2.5 プロセス非依存性（ICONIX 以外でも使える）

**legixy v3 のエンジン本体は完全にプロセス非依存**。典型的なドキュメント駆動開発であれば、ICONIX に限らず任意の開発プロセスで利用できる。ICONIX 前提の記述が多いのは、**デフォルト設定が ICONIX 向けに最適化**されているためで、アーキテクチャ上の制約ではない。

### 2.5.1 エンジンが process-agnostic である根拠

| コンポーネント | 汎用性の証拠 |
|--------------|-----------|
| typecode 管理 | `IndexMap<String, TypeEntry>`（`te-check/src/config_loader.rs:14-23`）、任意文字列を許容 |
| chain 検証 | `[id.chain].order: Vec<String>` を設定から読むのみ、typecode の意味解釈なし |
| graph.toml schema | `Node.type_code: String`（`te-graph/src/model.rs`）、列挙型ではない |
| DocumentId / FormalChecker 全 6 カテゴリ | typecode 非依存、設定駆動 |
| SemanticChecker / MCP / report / calibrate | embedding と閾値のみで動作、typecode 固有処理なし |

**ICONIX バイアスは以下の 2 箇所のみ**（すべて config 編集で置換可能）:

1. `init` が生成するデフォルト template（ICONIX 8 typecode + `[id.chain]` 既定値）
2. v0.1.0 → v3 migration のフォールバック既定値（`te-mig/src/matrix.rs`）

### 2.5.2 非 ICONIX プロセスでの `.trace-engine.toml` 設定例

init 直後に `.trace-engine.toml` の `[id.types.*]` と `[id.chain]` を書き換えるだけで、以下のプロセスを即座にサポート:

#### Waterfall / RDD（Requirements-Driven Design）

```toml
[id.chain]
order = ["REQ", "DES", "IMPL", "TEST"]
independent = ["ARCH"]

[id.types.REQ]
dir = "docs/requirements/"
ext = ".md"
file_pattern = "prefix"

[id.types.DES]
dir = "docs/design/"
ext = ".md"
file_pattern = "prefix"

[id.types.IMPL]
dir = "src/"
ext = ".rs"  # 言語に応じて変更可
file_pattern = "contains"

[id.types.TEST]
dir = "tests/"
ext = ".rs"
file_pattern = "contains"

[id.types.ARCH]
dir = "docs/architecture/"
ext = ".md"
file_pattern = "prefix"
```

#### Agile（User Story 中心）

```toml
[id.chain]
order = ["US", "AC", "FR", "CODE"]  # User Story → Acceptance Criteria → Feature → Code
independent = ["EPIC", "PERSONA"]

[id.types.US]
dir = "stories/"
ext = ".md"
file_pattern = "prefix"

[id.types.AC]
dir = "acceptance/"
ext = ".md"
file_pattern = "prefix"

[id.types.FR]
dir = "docs/features/"
ext = ".md"
file_pattern = "prefix"

[id.types.CODE]
dir = "src/"
ext = ".ts"  # 任意の言語拡張子
file_pattern = "contains"
```

#### BDD（Behavior-Driven）

```toml
[id.chain]
order = ["FEATURE", "SCENARIO", "STEP", "IMPL"]
independent = ["PERSONA"]

[id.types.FEATURE]
dir = "features/"
ext = ".feature"
file_pattern = "contains"

[id.types.SCENARIO]
dir = "features/scenarios/"
ext = ".feature"
file_pattern = "contains"

[id.types.STEP]
dir = "features/steps/"
ext = ".rb"  # Ruby / Python / JavaScript 等
file_pattern = "contains"

[id.types.IMPL]
dir = "lib/"
ext = ".rb"
file_pattern = "contains"
```

### 2.5.3 非 ICONIX プロセス採用時の運用手順

```bash
# 1. init（ICONIX 既定テンプレート生成）
legixy init

# 2. .trace-engine.toml を編集してプロセスを置換
#    [id.chain] と [id.types.*] を §2.5.2 の該当例で置き換え

# 3. 必要に応じて不要なディレクトリを削除 / 新規ディレクトリを作成
#    (init は ICONIX 10 ディレクトリを作成するが、使わないものは削除可)

# 4. area を変更
sed -i 's/area = "XX"/area = "MYPROJ"/' .trace-engine.toml

# 5. 検証動作確認
legixy check --formal
# → 新しい typecode 体系で DocumentId / OrphanFile が動作
```

### 2.5.4 `file_pattern` の 2 値

- **`"prefix"`**: ファイル名が `{ID}_<description>.<ext>` 形式（例: `SPEC-CALC-001_加算.md`）。主に .md ドキュメント向け
- **`"contains"`**: ファイル内容の先頭 32 行以内に `Document ID: {ID}` コメントが含まれる。主にソースコード / テストコード向け（コメント構文は言語依存だが、実装は単純 prefix 検出のため `// Document ID:` / `# Document ID:` / `-- Document ID:` 等すべて動作）

### 2.5.5 制限事項

- **`[id.chain].order` の順序は ID 連鎖検証に影響**する（左→右）。プロセスの自然な上流→下流順で記述すること
- **`[id.chain].independent` は「chain 検証対象外」の typecode 群**。要求仕様や非機能要件のような「流れに乗らない」成果物を指定
- `file_pattern = "prefix"` の場合、ファイル名の **最初のアンダースコアまで** を ID と見なす。プロジェクト規約で命名を統一すること
- サブノード自動抽出（h2/h3 見出し）は Markdown ファイル（`.md`）のみ対象。他言語・他フォーマットは対象外

---

## 3. システム構成

```
┌─────────────────────────────────────────────────────────┐
│  プロジェクトリポジトリ（v3）                               │
│                                                           │
│  .trace-engine.toml              ← 設定（両ツールが読む）   │
│  docs/traceability/graph.toml    ← グラフ定義（一次データ） │
│  docs/traceability/matrix.md     ← 派生ビュー（v0.1.0 互換）│
│  .trace-engine/engine.db         ← SQLite WAL（統合 DB）   │
│  models/all-MiniLM-L6-v2/        ← ONNX モデル（意味検証用）│
│                                                           │
│  ┌──────────────┐    ┌──────────────────────┐             │
│  │ Rust CLI     │    │ MCP サーバー          │             │
│  │ v0.2.0       │    │ (TypeScript v0.2.0)   │             │
│  │ (人間が使う)  │    │ (Claude Code が使う)  │             │
│  │              │    │                      │             │
│  │ init         │    │ compile_context      │             │
│  │ migrate      │    │ observe              │             │
│  │ check        │    │ get_compile_audit    │             │
│  │ embed/drift  │    │                      │             │
│  │ context      │    │ (内部で Rust CLI を   │             │
│  │ impact       │    │  spawn して結果転送)  │             │
│  │ investigate  │    │                      │             │
│  │ feedback     │    │                      │             │
│  │ analyze      │    │                      │             │
│  │ approve      │    │                      │             │
│  │ reject       │    │                      │             │
│  │ audit        │    │                      │             │
│  │ (全 17 コマンド)│    │                      │             │
│  └──────┬───────┘    └──────────┬───────────┘             │
│         │  サブプロセス実行       │                         │
│         │◄──────────────────────┘                         │
│         │                                                  │
│         ▼                                                  │
│  .trace-engine/engine.db (WAL + busy_timeout=5000ms)       │
└───────────────────────────────────────────────────────────┘
```

**データ共有方式:** ファイルシステムのみ。プロセス間通信なし。SQLite WAL により同時アクセス安全。

---

## 4. 動作環境

### Rust CLI（`legixy` v0.2.0）

| 要件 | バージョン |
|------|-----------|
| Rust toolchain | 1.75+ |
| OS | Windows 11 / macOS / Ubuntu 22.04+ |
| SQLite | 3.41+（rusqlite 0.33 bundled） |

### 意味的整合性検証（第2層）を使う場合

| 要件 | 詳細 |
|------|------|
| ONNX モデル | all-MiniLM-L6-v2（sentence-transformer）または互換モデル |
| `models/<model-name>/` 配下に `model.onnx` + `tokenizer.json` 配置 | |

### Contextual Retrieval を使う場合（デフォルト無効）

| 要件 | 詳細 |
|------|------|
| LLM API | Anthropic / OpenAI / Google（環境変数でキー指定） |
| 環境変数 | `ANTHROPIC_API_KEY` 等（平文ログ禁止、マスキング必須） |

### MCP サーバー（traceability-mcp）

| 要件 | バージョン |
|------|-----------|
| Node.js | **LTS 20+**（Active LTS）、**維持 LTS 2 世代サポート**（NFR-TE-001.COMPAT.10） |
| npm | 9+ |
| Claude Code | v2.1.91+（`_meta["anthropic/maxResultSizeChars"]` 対応バージョン、未満でも動作、メタは無視される） |

---

## 5. インストール手順

### 5.1 Rust CLI のビルド（v3 単一バイナリ）

```bash
# リポジトリクローン
git clone <repository-url>
cd legixy

# workspace 全体ビルド
cargo build --release

# バイナリ確認
./target/release/legixy --version
# → legixy 0.2.0
```

ビルド成果物: `target/release/legixy`（Windows は `.exe`）

#### PATH への追加（推奨）

```bash
# Linux / macOS
cp target/release/legixy ~/.local/bin/

# Windows (PowerShell)
Copy-Item target\release\legixy.exe "$env:USERPROFILE\bin\"
# その後、ユーザー環境変数 PATH に "%USERPROFILE%\bin" を追加
```

### 5.2 MCP サーバーのビルド

```bash
cd ts-mcp
npm install
npm run build
```

ビルド成果物: `ts-mcp/dist/index.js`

主要依存（`ts-mcp/package.json`）:
- `@modelcontextprotocol/sdk ^1.0.0` — MCP プロトコル実装
- `zod ^3.24` — 入力 schema 検証
- `vitest ^2.0.0`（devDeps）— テストフレームワーク
- **`better-sqlite3` は含まない**（v0.1.0 と異なり、engine.db への直接アクセスは行わず Rust CLI spawn 経由、SPEC-TE-009 REQ.05 ステートレス性確保）

### 5.3 テスト実行（任意）

```bash
# Rust workspace テスト（実測 2026-04-20 時点: 253 passed + 19 ignored、8 ignored が ONNX fixture 依存、他は env-gated）
cargo test --workspace --no-fail-fast

# MCP サーバーテスト（実測: 13 passed + 2 skipped、skipIf は RUN_STRESS / RUN_PERF env で有効化）
cd ts-mcp
npm test
```

### 5.4 ONNX モデルの配置（意味的検証・embed / drift を使う場合）

```bash
mkdir -p models/all-MiniLM-L6-v2
# 以下をダウンロード配置:
#   model.onnx
#   tokenizer.json
# 取得元: https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2
```

---

## 6. プロジェクトへの導入

### 6.1 新規プロジェクト（`init`）

対象プロジェクトのルートで:

```bash
legixy init
```

生成されるファイル / ディレクトリ（v3、2026-04-20 INIT Block 反映版）:

- `.trace-engine.toml` — 設定ファイル（**既定は ICONIX 8 typecode + `[id.document_id]` の完全 template**、最低限 `area = "XX"` のみ変更必要。**非 ICONIX プロセスの場合は §2.5 を参照して `[id.types.*]` と `[id.chain]` を書き換える**）
- `docs/traceability/graph.toml` — **グラフ定義テンプレート**（v3 新規、一次データ）
- `docs/traceability/matrix.md` — 派生ビューテンプレート（v0.1.0 互換、手動管理）
- **ICONIX 成果物 10 ディレクトリ**（既定）: `docs/{specs,usecases,robustness,sequence,detailed-design,test-specs,validation,traceability}/` + **`tests/`** + **`src/`**。非 ICONIX プロセスでは不要なディレクトリを削除し、新規ディレクトリを手動で作成（`[id.types.*].dir` の値と一致させる）
- **9 箇所の `.gitkeep`**: 空ディレクトリの Git 追跡用（`docs/specs/.gitkeep` ... `docs/validation/.gitkeep` + `tests/.gitkeep` + `src/.gitkeep`）
- `.trace-engine/` — engine.db 格納用（`.gitignore` 付き）
- `.trace-engine/engine.db` — 初期化済 SQLite（WAL、全テーブル定義済、`PRAGMA user_version=3` マーカー書込み）

**init 直後の `check --formal` 挙動**（2026-04-20 INIT Block）:
- `area = "XX"` 未変更 → Info 1 件「プロジェクト固有コードに変更してください」
- `[id.document_id].pattern` に `{id}` プレースホルダを記入 → Warning 1 件（literal prefix が正、`{id}` は未解釈）

既存プロジェクトへの上書き:

```bash
legixy init --force  # .bak バックアップを生成してから上書き
```

### 6.2 v0.1.0 プロジェクトからの移行（`migrate`）

既存 v0.1.0 プロジェクトを v3 に変換:

```bash
# v0.1.0 プロジェクトを指定
legixy migrate --from /path/to/v0.1.0-project

# dry-run（変更予定のみ確認、実ファイル変更なし）
legixy migrate --from /path/to/v0.1.0-project --dry-run
```

移行で実行される処理:

1. `.trace-engine.toml` を v0.1.0 → v3 形式に変換（`[graph]` セクション追加、`[contextual_retrieval]` デフォルト無効追加等）
2. `matrix.md` → `graph.toml` 自動生成（`[[nodes]]` + `[[edges]]`）
3. `feedback.db` → `engine.db` にテーブル copy（observations / proposals / custom_edges）
4. `vectors.bin` → `embeddings` テーブルへ import（`ImportStrategy::Skip` がデフォルト、`BestEffort` で有効化）
5. 旧 ID → 新 ID（SHA-256 ベース）マッピング表（`docs/traceability/migration-id-map.toml`）を生成
6. `.bak` バックアップ作成（非破壊性保証、REQ.02）

### 6.3 設定ファイルの編集

`.trace-engine.toml` をプロジェクトに合わせて編集。詳細は [§11 設定リファレンス](#11-設定リファレンス) を参照。

### 6.4 グラフの作成（v3 新規、graph.toml）

```toml
# docs/traceability/graph.toml

[[nodes]]
id = "SPEC-PR-001"
type = "SPEC"                                           # 必須（typecode 文字列）
path = "docs/specs/SPEC-PR-001_ログイン.md"

[[nodes]]
id = "UC-PR-001"
type = "UC"
path = "docs/usecases/UC-PR-001_ログイン.md"

[[edges]]
from = "SPEC-PR-001"
to = "UC-PR-001"
kind = "chain"
```

- **ノード**: 各成果物 ID + `type`（typecode 文字列）+ `path`。`[[nodes]]` に `type` フィールドは**必須**（2026-04-20 事実確認、`Node` 構造体の `type_code: String`）
- **エッジ**: `chain`（連鎖）/ `custom`（カスタムリンク）/ `parent_child`（サブノード）等の種別
- **サブノード ID**: `DD-PR-001#anchor`（自動）or `DD-PR-001#s:cross-section-logic`（明示）

### 6.5 初回検証

```bash
# 第1層（形式検証）のみ
legixy check --formal

# 第1層 + 第2層（意味的検証、ONNX モデル要）
legixy check

# JSON 出力（スクリプト連携、--json はグローバルフラグ、サブコマンドの**前**に置く）
legixy --json check --formal
```

> **注意**: `--json` はグローバルフラグ。`check --json` ではなく `--json check` の順で指定する。全サブコマンド共通。

---

## 7. CLI コマンドリファレンス

### 全コマンド共通オプション

| オプション | 説明 | 位置 |
|-----------|------|-----|
| `--project-root <path>` | プロジェクトルート指定（default: カレント） | サブコマンドの**前** |
| `--json` | JSON 出力モード（全コマンド対応） | サブコマンドの**前**（例: `legixy --json check --formal`） |
| `--models-dir <path>` | ONNX モデルディレクトリ（embed / drift 用、デフォルトは `[semantic].vector_store`） | サブコマンドの**前** |

### 検証系

| コマンド | 説明 |
|---------|------|
| `check --formal` | 第1層（ID 形式・ファイル存在・連鎖整合性・Freshness・DAG・OrphanFile・**IdRedefined・IdSemanticMismatch**）検証 |
| `check` | 第1層 + 第2層（**SemanticChecker 実装済 2026-04-20**: SemanticSimilarity / LinkCandidate / Drift の 3 カテゴリを自動発火） |
| `embed --all` | 全成果物の embedding を生成 → engine.db 格納 |
| `drift <artifact_id> [--against snapshot:LABEL]` | 特定成果物のドリフト検出（1.0 - cosine_similarity）。`--against` 省略時は embeddings テーブル現行行と比較、指定時は snapshot との差分（**v0.3.0 ISSUE-002**）|
| `snapshot create [--label LABEL]` / `list` / `delete <target>` | drift baseline 凍結管理（**v0.3.0 ISSUE-002**）|
| `refresh-subnodes [--dry-run \| --apply]` | 見出しリネームに伴うサブノード ID 連鎖変化を検出・反映（**v0.4.0-alpha4 Block E**、TE-NEXT-EXT-001 §9.3）|
| `report [--json]` | 全エッジの類似度 + リンク候補一覧（**2026-04-20 RPT Block 実装**） |
| `calibrate [--buckets N] [--recommend] [--json]` | 類似度分布ヒストグラム + 3 閾値表示。`--recommend` で percentile ベース推奨閾値出力（**v0.3.0 ISSUE-004**）|

### コンテキスト解決系（v3）

| コマンド | 説明 |
|---------|------|
| `context <files...>` | ファイルパスから上流成果物を解決 |
| `context <files...> --command <intent>` | 作業意図付きコンテキスト解決 |
| `context <files...> --granularity <document\|subnode>` | **v3 新規**：粒度制御 |

### グラフ走査系（v3 新規、NAV ブロック）

| コマンド | 説明 |
|---------|------|
| `impact <start_id> [--max-depth <N>]` | 順方向走査（start からの下流影響範囲） |
| `investigate <start_id> [--max-depth <N>]` | 逆方向走査（start への上流依存 + drift で怪しい候補抽出） |

### embedding / drift 系（EMB ブロック）

v3 では engine.db の embeddings テーブルに統合。CLI 経由で再生成・検査:

```bash
# 全成果物の embedding を（再）生成
legixy embed --all

# 特定成果物のドリフト検出（前回 embedding との差）
legixy drift DD-PR-001
```

### フィードバックループ系（FB ブロック）

| コマンド | 説明 |
|---------|------|
| `feedback` | check 結果から Observation を自動生成 → engine.db 記録 |
| `observe <category> <message>` | Observation を手動記録（**位置引数**、v0.1.0 の `--category` / `--message` フラグは廃止） |
| `observe <cat> <msg> --related-id <id>...` | **v3 新規**：関連 ID 複数指定 |
| `observe <cat> <msg> --target-file <path>...` | **v3 新規**：対象ファイル指定 |
| `observe <cat> <msg> --missing-doc <id>` | **v3 新規**：欠落ドキュメント指定 |
| `observe <cat> <msg> --source-glob <pattern>` | **v3 新規**：glob パターン指定 |
| `analyze` | pending Observation → Proposal 生成（Pessimistic Claim） |
| `proposals [--status pending\|approved\|rejected]` | Proposal 一覧表示 |
| `approve <proposal_id>` | Proposal を承認（FB-INV-2 原子的トランザクション） |
| `reject <proposal_id> --reason <理由>` | Proposal を却下（理由必須、空文字列不可） |
| `audit [--limit <N>]` | **v3 新規**：context_log の直近 N 件取得（default 10、1..=50） |

> **v0.1.0 → v3 観察コマンドの移行**: v2 は `observe --category X --message Y` だった。v3 は位置引数 `observe X Y`。詳細は `observe --help` を参照（2026-04-20 Finding 3 で long_about に移行例を追加済）。

### 典型的な運用フロー

```bash
# 1. 検証実行
legixy check --formal

# 2. ドリフト確認
legixy drift DD-PR-001

# 3. 検出結果から Observation を生成
legixy feedback

# 4. Observation を分析して Proposal を生成
legixy analyze

# 5. Proposal を確認
legixy proposals

# 6. 承認 or 却下
legixy approve 1
legixy reject 2 --reason "意図的に省略"

# 7. 監査ログ確認（MCP 経由の compile_context 履歴）
legixy audit --limit 20
```

---

## 8. MCP サーバーの設定

### 8.1 アーキテクチャ概要

v3 の MCP サーバー（`traceability-mcp`）は **TypeScript（Node.js LTS）で実装された独立プロジェクト** `ts-mcp/`（Rust workspace 外）。Claude Code と `StdioServerTransport` で接続し、3 種の Agent Surface ツールを提供する。

```
┌─────────────────┐         ┌──────────────────────┐        ┌────────────────────┐
│  Claude Code    │ stdio   │  traceability-mcp     │ spawn  │ legixy│
│  (Agent)        │◄───────►│  (Node.js, ts-mcp/)   │───────►│ (Rust CLI v0.2.0)  │
│                 │ MCP     │                       │ execFile│                    │
│                 │         │  - 3 ツール登録        │        │ - 17 サブコマンド   │
│                 │         │  - zod 入力検証       │        │ - engine.db 操作    │
│                 │         │  - 忠実転送 (INV-2)   │        │                    │
└─────────────────┘         └──────────────────────┘        └─────────┬──────────┘
                                                                       │
                                                                       ▼
                                                           .trace-engine/engine.db
```

**設計原則（SPEC-TE-009）:**
- **MCP-INV-1:** Agent Surface に露出するツールは **compile_context / observe / get_compile_audit の 3 種のみ**。追加禁止。
- **MCP-INV-2:** Rust CLI の出力を**加工せず忠実転送**。構造化変換は最小限。
- **MCP-INV-3:** Observation 重複排除は FB 層（`te-feedback::ObservationRecorder`）が担保。
- **MCP-INV-4:** 監査ログ（context_log）は CTX 層が自動記録、MCP は読取のみ。
- **ステートレス性（REQ.05）:** MCP サーバー自体は永続状態を持たない。engine.db アクセスは**常に Rust CLI spawn 経由**（better-sqlite3 依存を排除）。

### 8.2 `.mcp.json` の配置

プロジェクトルートに `.mcp.json` を配置:

```json
{
  "mcpServers": {
    "traceability": {
      "command": "node",
      "args": [
        "/absolute/path/to/ts-mcp/dist/index.js",
        "--project-root",
        "/absolute/path/to/project"
      ],
      "env": {
        "TRACEABILITY_ENGINE_BIN": "/absolute/path/to/legixy"
      }
    }
  }
}
```

**引数:**
- `--project-root <path>`: プロジェクトルート（省略時はカレントディレクトリ）
- `--engine-binary <path>`: Rust CLI バイナリのパス（環境変数より優先）

### 8.3 環境変数

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `TRACEABILITY_ENGINE_BIN` | Rust CLI バイナリのパス | `legixy`（PATH 解決） |
| `TRACEABILITY_PROJECT_ROOT` | プロジェクトルート | `--project-root` 引数 > カレント |

**バイナリ検出の優先順位:**
1. `--engine-binary` コマンドライン引数
2. `TRACEABILITY_ENGINE_BIN` 環境変数
3. PATH 上の `legixy`

### 8.4 提供 MCP ツール（3 種、MCP-INV-1）

#### 8.4.1 `compile_context` — 上流コンテキスト解決

target_files から上流成果物を解決し、Markdown コンテキストとして返す。

**入力 schema（zod）:**

| フィールド | 型 | 必須 | 説明 |
|----------|-----|:---:|------|
| `target_files` | `string[]` | ✓ | コンテキスト対象ファイルパス（最低 1 個） |
| `command` | `string` | — | 作業意図（例: `"implement"`, `"test"`, `"refactor"`） |
| `granularity` | `"document" \| "subnode"` | — | **v3 新規**：粒度制御（default: `"document"`） |

**下位呼出:** `legixy context <files>... [--command <cmd>] [--granularity <mode>]`

**出力:**
- `content[0].type = "text"`, `content[0].text = <Rust CLI stdout（Markdown）>`
- `_meta["anthropic/maxResultSizeChars"] = 500000`（キャッシュ永続化、TE-NEXT-EXT-002）
- Rust CLI 側で挿入された cache-breakpoint マーカー（`<!-- cache-breakpoint: stable-end -->`）をそのまま保持

#### 8.4.2 `observe` — Observation 記録

Agent が気づき（ガイドラインの不足、参照漏れ、矛盾等）を engine.db に記録する。

**入力 schema（zod）:**

| フィールド | 型 | 必須 | 説明 |
|----------|-----|:---:|------|
| `category` | `string` | ✓ | カテゴリ（`"compile_miss"` / `"review_correction"` / `"manual_note"` 等） |
| `message` | `string` | ✓ | 気づきの本文 |
| `severity` | `string` | — | `"info"` / `"warn"` / `"error"`（default: `"info"`） |
| `related_ids` | `string[]` | — | **v3 新規**：関連成果物 ID リスト |
| `target_files` | `string[]` | — | **v3 新規**：対象ファイルパス |
| `missing_doc` | `string` | — | **v3 新規**：欠落ドキュメント ID |
| `source_glob` | `string` | — | **v3 新規**：glob パターン |

**下位呼出:** `legixy observe <category> <message> [--severity] [--related-id]... [--target-file]... [--missing-doc] [--source-glob]`

**出力（2 パターン）:**
- 新規記録時: `Observation #<id> を記録`
- 重複（FB-INV-1 / MCP-INV-3 で既存と dedup）: `既に記録済み（observation_id=<id>）`

**注意:**
- `related_ids` 以外の 3 新規引数（`target_files` / `missing_doc` / `source_glob`）は engine.db の `observations.context_json` カラムに JSON として格納される（MIG Gap 2 案 A）。

#### 8.4.3 `get_compile_audit` — 監査履歴取得

`context_log` テーブルから compile_context の呼出履歴を取得する。

**入力 schema（zod）:**

| フィールド | 型 | 必須 | 説明 |
|----------|-----|:---:|------|
| `limit` | `number`（1〜50） | — | 取得件数（default: 10） |

**下位呼出:** `legixy audit [--limit <N>]`

**出力:**
- `content[0].type = "text"`, `content[0].text = <Markdown 形式の履歴一覧>`
- `_meta["anthropic/maxResultSizeChars"] = 500000`

**Markdown 形式:**
```markdown
### #<id> (<created_at>)
- Files: <input_files[] join>
- Command: <input_command>
- Resolved: <resolved_targets[] join>
...
```

### 8.5 Admin Surface との分離（MCP-INV-1）

以下の 14 コマンドは **MCP に露出しない**（CLI 専用、人間のみ実行）:

- `init` / `migrate` — プロジェクト初期化・移行
- `check` / `embed` / `drift` / `report` / `calibrate` — 検証系
- `impact` / `investigate` — グラフ走査
- `feedback` / `analyze` — Observation / Proposal 生成
- **`approve` / `reject`** — 承認・却下（CLAUDE.md 絶対ルール 5、人間のみ）

### 8.6 v3 拡張まとめ（v0.1.0 からの差分）

| 拡張 | 対象 | 仕様根拠 |
|------|------|---------|
| `compile_context.granularity` 引数 | compile_context | SPEC-TE-009 REQ.04、`document`/`subnode` の 2 値 |
| `observe` 4 引数追加 | observe | SPEC-TE-007 REQ.01、`related_ids`/`target_files`/`missing_doc`/`source_glob` |
| `_meta["anthropic/maxResultSizeChars"]` 付与 | compile_context / get_compile_audit のみ | SPEC-TE-009 REQ.13、TE-NEXT-EXT-002 §4.2、値 500000 固定 |
| cache-breakpoint マーカー | compile_context 出力 | NFR-TE-001.REL.09、Rust CLI 側で挿入、MCP は忠実転送 |
| better-sqlite3 依存削除 | ts-mcp 全体 | SPEC-TE-009 REQ.05、ステートレス性確保、Rust CLI spawn 経由 |
| Node.js LTS 固定 | ランタイム | NFR-TE-001.COMPAT.10、Active + 維持 LTS 2 世代 |

### 8.7 テスト実行

```bash
cd ts-mcp

# Unit / Integration テスト（モック RustEngine 使用、実バイナリ不要）
npm test

# 実バイナリ経由の統合テスト（skipIf を解除、任意）
RUN_STRESS=1 RUN_PERF=1 npm test

# ビルド確認
npm run build
```

**テストフレームワーク:** vitest `^2.0.0`（ESM ネイティブ、`test.skipIf` サポート）

**テスト構成（TS-TE-008）:**
- **Unit**: モック RustEngine を DI、ツール単体の入出力変換検証
- **Integration**: 実 Rust CLI を spawn、`MCP-INV-2` 忠実転送を検証
- **Protocol**: MCP client ↔ server（stdio）のエンドツーエンド

### 8.8 起動確認（動作テスト）

MCP サーバーが正しく起動しているかを検査する最小手順:

```bash
# 1. Rust CLI バイナリの確認
legixy --version  # → "legixy 0.2.0"

# 2. MCP サーバーのビルド
cd ts-mcp
npm install
npm run build

# 3. MCP サーバー単体起動（stdio で手動疎通）
TRACEABILITY_ENGINE_BIN=/path/to/legixy \
  node dist/index.js --project-root /path/to/project

# 4. Claude Code 側から接続
#    .mcp.json 配置後、Claude Code 再起動で自動検出
```

---

## 9. CLAUDE.md の運用ルール記述

プロジェクトの `CLAUDE.md` に以下を記述し、Claude Code が MCP ツールを正しく使えるようにする（**以下は ICONIX 想定の例**。非 ICONIX プロセスでは `[id.chain]` / `[id.types.*]` と整合する内容に書き換える）:

```markdown
## トレーサビリティ管理

このプロジェクトは legixy v3 で管理されています。

### 必須ルール

1. **成果物作成前に `compile_context` を呼び出し、上流成果物を参照すること**
2. ファイル先頭の `Document ID: {ID}` 行を削除・改変しない
3. **graph.toml は人間または Claude Code が手動編集**（v3 にはファイル監視機構なし）:
   - 新規成果物追加 → `[[nodes]]` + chain/custom エッジ追加
   - 成果物削除 → 該当 `[[nodes]]` + 関連エッジ削除
   - リネーム → `path` 変更（自動検出なし）
4. 検証コマンド（`--json` はグローバルフラグ、サブコマンドの前に置く）:
   - `legixy check --formal`（形式検証、必ず実行）
   - `legixy check`（意味的検証、SemanticChecker 発火、大きな変更後）
5. Proposal の承認・却下は**人間のみ**（Claude Code は実行しない）
```

詳細テンプレート: `docs/old.manual/claude-md-template.md` 参照。

### graph.toml の更新主体（2026-04-20 事実確認）

- **v3 にファイルシステム監視機構は存在しない**（`notify` crate / watcher 未実装）
- **graph.toml 編集専用 CLI サブコマンド（`add-node` 等）は存在しない**
- 編集主体: **人間 or Claude Code が直接 graph.toml を書き換える運用**
- リロード: ステートレス CLI（`parse_graph` 毎回呼出し）、明示的リロード不要
- 不整合検出: `check --formal` の 6 カテゴリ（FileExistence / DocumentId / ChainIntegrity / OrphanFile / Freshness / DAG）で事後検証

---

## 10. 運用フロー

### 10.1 日常の開発フロー

```
コード変更 → check --formal → （Error あり）→ 修正 → 再検証
                            → （Error なし）→ embed（意味検証が必要なら）→ check
```

### 10.2 レビューサイクル

```
check → feedback → Observation → analyze → Proposal
      ↓
  人間レビュー
      ↓
  approve / reject
```

### 10.3 AI 協働開発（Claude Code 使用時）

```
Claude Code が compile_context 呼出（上流成果物参照）
           ↓
Claude Code がコード実装 or ドキュメント作成
           ↓
check / feedback / analyze を人間が実行
           ↓
Proposal を人間が判断
```

### 10.4 パイプライン運用（opt-in、役割分離開発）

プロジェクトによっては **s1（設計者）/ s2（実装者）/ s3（QA）/ s4（Adversary）** の 4 役割を別 PowerShell セッションで分離するパイプライン運用を適用可（`scripts/pipe-start.cmd` + `.claude/hooks/gate-check.ps1`）。CLAUDE.md に既定オペレーションが記述されているが、**デフォルトではオーケストレーター直接実装**を推奨し、パイプラインは必要時のみ明示的に opt-in する。

**パイプライン使用時の主要な変化**:
- `$env:PIPE_ROLE` に応じてゲートフックが書込み範囲を制限（s2 は src/* のみ、s1 は docs/* + tests/* 等）
- `.pipeline/{BLOCK}/` 配下に kickoff / completion / feedback / verdict を監査証跡として保存
- 三重フィードバックループ（実装修正 / 敵対的修正 / 仕様見直し）が各 3 サイクル上限

**デフォルト運用（パイプライン非使用）**: オーケストレーターが全役割を一気通貫で実施。`/sc:implement` / `/sc:analyze` / `/sc:improve` 等の slash command で進める。

---

## 11. 設定リファレンス

`.trace-engine.toml` の主要セクション（`init` 直後のテンプレート + 編集例）:

```toml
# [project].version は init テンプレートには含まれない（2026-04-20 事実確認）
[project]
name = "my-project"

[id]
pattern = "{type}-{area}-{seq}"
area = "PR"  # init 既定は "XX"、プロジェクト固有コードに変更する（未変更だと check --formal で Info 誘導）
seq_digits = 3

[id.types]
SPEC = { dir = "docs/specs/", ext = ".md", file_pattern = "prefix" }
UC   = { dir = "docs/usecases/", ext = ".md", file_pattern = "prefix" }
RB   = { dir = "docs/robustness/", ext = ".md", file_pattern = "prefix" }
SEQ  = { dir = "docs/sequence/", ext = ".md", file_pattern = "prefix" }
DD   = { dir = "docs/detailed-design/", ext = ".md", file_pattern = "prefix" }
TS   = { dir = "docs/test-specs/", ext = ".md", file_pattern = "prefix" }
TC   = { dir = "tests/", ext = ".rs", file_pattern = "contains" }
SRC  = { dir = "src/", ext = ".rs", file_pattern = "contains" }

[id.chain]
order = ["UC", "RB", "SEQ", "DD", "TS", "TC", "SRC"]
independent = ["SPEC", "NFR", "VAL"]

[id.document_id]
# literal prefix 文字列のみ（`{id}` プレースホルダは解釈されない、誤記すると Warning）
pattern = "Document ID:"

[graph]
file = "docs/traceability/graph.toml"

[matrix]
format = "markdown"
file = "docs/traceability/matrix.md"
section = "Traceability Matrix"

[semantic]
enabled = true
model = "all-MiniLM-L6-v2"
similarity_threshold = 0.4
drift_threshold = 0.3
link_candidate_threshold = 0.7

[contextual_retrieval]
# init 既定は `enabled = false` のみ。有効化後の追加オプション（provider / model /
# timeout_sec / max_retries 等）は SPEC-TE-006 REQ.06.1 参照、本フェーズでは
# 運用実例なし（Phase 2 以降の運用開始時に確定予定）
enabled = false

[freshness]
enabled = true
method = "mtime"

[migration]
auto = false  # v0.1.0 検出時の自動移行（opt-in）
```

---

## 12. v0.1.0 からの移行

### 移行手順

```bash
# Step 1: v0.1.0 プロジェクトをバックアップ
cp -r v0.1.0-project v0.1.0-project.backup

# Step 2: v3 プロジェクトディレクトリ作成
mkdir v3-project && cd v3-project

# Step 3: v3 で init
legixy init --force

# Step 4: v0.1.0 データを migrate
legixy migrate --from ../v0.1.0-project.backup

# Step 5: 結果確認
cat docs/traceability/migration-id-map.toml  # 旧→新 ID マッピング
legixy check --formal            # 形式検証

# Step 6: Git commit（STATE-INV-2 運用ガイダンス）
git add docs/traceability/ .trace-engine.toml
git commit -m "chore: migrate to legixy v3"
```

### 注意事項

- **vectors.bin の import** は default `Skip`。再生成を推奨:
  ```bash
  legixy embed --all
  ```
- **custom_edges テーブル**: v0.1.0 `(source_glob, target_path, description)` → v3 `(from_id, to_id, reason)` にマッピング変換
- **サブノード**: v0.1.0 には存在しない。移行後に `embed --all` 等のタイミングで自動抽出（Phase 1 は MVP、ユーザー明示操作必要）

---

## 13. トラブルシューティング

### Q1: `legixy check` で「ONNX モデルの読み込みに失敗」

A: `models/<model-name>/` に `model.onnx` + `tokenizer.json` が配置されているか確認。`.trace-engine.toml` の `[semantic].model` が対応するディレクトリ名と一致しているか確認。

### Q2: `migrate` が途中で失敗した

A: `.bak` バックアップファイルが生成されている。手動で復元:
```bash
mv .trace-engine.toml.bak .trace-engine.toml
mv docs/traceability/graph.toml.bak docs/traceability/graph.toml
```
エラーメッセージを確認し、原因を特定してから再実行。

### Q3: `cargo test` で「workspace not a workspace」エラー

A: ルート `Cargo.toml` の `[workspace] members` に全 10 crate が登録されているか確認。開発時に新規 crate を追加した場合は手動追加が必要。

### Q4: MCP サーバーから `compile_context` を呼んだが Claude Code にツールが見えない

A:
1. `.mcp.json` のパスが正しいか（`dist/index.js` の**絶対パス**が必要）
2. `TRACEABILITY_ENGINE_BIN` 環境変数が正しいか（`legixy --version` で 0.2.0 を確認）
3. `ts-mcp/dist/` が存在するか（`npm run build` 未実行の場合は再ビルド）
4. Claude Code を再起動（MCP 再読み込み）
5. Claude Code のバージョン確認：`_meta["anthropic/maxResultSizeChars"]` は v2.1.91+ で解釈、未満では無視（NFR-TE-001.COMPAT.12、機能的には動作）

### Q5: approve / reject が MCP から呼べない

A: 仕様通り。`approve` / `reject` は **Admin Surface（CLI 専用）** であり、MCP に露出しない（MCP-INV-1、CLAUDE.md 絶対ルール 5）。人間が CLI で実行する。

他の **MCP 非露出コマンド**（14 種）: `init` / `migrate` / `check` / `embed` / `drift` / `report` / `calibrate` / `impact` / `investigate` / `feedback` / `analyze` / `proposals`。

### Q6: `check --formal` で大量の WARNING が出る

A: v0.1.0 ツール相当の挙動として、以下は通常の WARNING（Error ではない）:
- `SEQ-XXX` が matrix.md に未登録（v3 では graph.toml が一次データで、matrix.md は派生ビュー）
- `TC-XXX: ファイル更新日時がマトリクスより新しい`（mtime freshness、大きな編集後は通常発生）

Error が 0 であれば G2 / G3 ゲートは通過扱い。

**加えて 2026-04-20 INIT Block 以降の新規 Info / Warning**:
- `[INFO] [id].area が初期値 'XX' のまま` — `init` 直後の標準動作、プロジェクト固有コードに変更すると消える
- `[WARNING] [id.document_id].pattern に '{id}' プレースホルダ` — literal prefix のみ受付、`"Document ID:"` のように書き換える

**2026-04-27 ISSUE-001 対応で追加された Warning**:
- `[WARNING] IdRedefined: 'NFR-XXX-001' は SPEC-XXX-001 で 2026-04-26 に再定義されました…` — SPEC 内 `## ID Changelog` または `[[id_changelog]]` で `redefined` 宣言された ID の引用を検出。詳細は §11「ID 再定義検出（IdRedefined / IdSemanticMismatch）」を参照
- `[INFO] IdSemanticMismatch: 'NFR-XXX-001' の SPEC 定義と引用文に不整合があります…` — `[id_semantic_mismatch]` を有効化したときのみ動作。デフォルト OFF

### Q7: 実行バイナリのサイズが大きい（15〜25 MB）

A: 仕様通り。v3 は ONNX runtime（ort 2.0）、tokenizers、rusqlite（bundled SQLite）、clap 等を単一バイナリに含むため。`strip` + `lto=thin` で最適化済。

### Q8: `compile_context` の granularity で `graph` / `upstream` / `all` を渡すとエラー

A: v3 では Granularity は **`document` と `subnode` の 2 値のみ**（te-ctx 実装準拠、SPEC-TE-009 REQ.04 確定）。古いドキュメントの `graph`/`upstream`/`all` は採用されていない値です。

### Q9: Rust CLI が spawn できない（`ENOENT` エラー）

A:
1. `TRACEABILITY_ENGINE_BIN` が存在するファイルを指すか確認
2. PATH 解決で失敗している場合は絶対パスを環境変数で明示
3. Windows では `.exe` 拡張子が必要な場合あり：`legixy.exe`
4. 実行権限（Linux / macOS）: `chmod +x /path/to/legixy`

### Q10: MCP サーバーのログ確認

A: MCP サーバーは stderr にログを出力。Claude Code の MCP ログ設定に従う:
- Claude Code Desktop: `~/Library/Logs/Claude/mcp-server-traceability.log`（macOS）
- VS Code: 出力パネル → "MCP" チャンネル

サーバー側の詳細ログは stderr に出力される。Claude Code 側のログ設定（上記 OS 別パス）で確認可能。将来の拡張候補として `LOG_LEVEL` 環境変数によるログレベル制御があるが、Phase 1 では stdout/stderr 直出力で十分（RustCliError は `{ isError: true, content: [...] }` として MCP クライアントに転送される）。

### Q11: ファイルを削除・リネームしたら graph.toml はどう更新される？

A: **v3 は自動更新しない**。graph.toml は手動編集が前提（2026-04-20 事実確認）:

- **ファイル削除** → `check --formal` が FileExistence Error を発行。手動で `[[nodes]]` と関連 `[[edges]]` を削除
- **ファイルリネーム** → 検出機構なし。手動で `[[nodes]].path` を更新（ID を保持したいなら `path` のみ変更、ID を変えるなら ID / path 両方変更 + 関連エッジの `from` / `to` も書換え）
- **新規ファイル作成** → `OrphanFile` Info が検出。手動で `[[nodes]]` 追加 + chain/custom エッジ追加
- **h2/h3 見出し変更** → parse 時にサブノード ID（ハッシュベース）が自動変化、graph.toml には書き戻されない（メモリ内のみ）
- **本文変更（見出し以外）** → graph.toml 無影響。`embed --all` 再実行 → `check`（全層）で Drift Warning 発火

v3 のグラフ操作は「明示実行型」。ファイルシステム監視（`notify` crate 等）は未実装。`check` の定期実行 or CI 組み込みで検出する運用を推奨。

### Q12: `--json` フラグが効かない

A: `--json` は **グローバルフラグ**。サブコマンドの**前**に置く必要がある:

```bash
# ✗ 誤り（v0.1.0 の書き方、v3 では効かない）
legixy check --formal --json

# ✓ 正しい（v3）
legixy --json check --formal
```

`--project-root` / `--models-dir` も同様にグローバルフラグ。

---

## 付録

### A. 成果物 ID 体系（v3 標準）

- パターン: `{type}-{area}-{seq}`
- サブノード: `{親ID}#{anchor}` or `{親ID}#s:{explicit}`
- 連鎖順序: `UC → RB → SEQ → DD → TS → TC → SRC`
- 独立: `SPEC / NFR / VAL`

### B. 不変条件一覧（V-DRS-SPEC-001 §13）

- **CTX-INV-1**: 決定論保証（同一入力 → 同一出力）
- **CTX-INV-2**: グラフ整合性
- **SCORE-INV-1**: ハッシュ一致保証（embedding キャッシュ）
- **SCORE-INV-2**: モデルバージョン一致
- **MCP-INV-1**: Agent Surface 限定（3 ツールのみ）
- **MCP-INV-2**: 忠実転送（加工禁止）
- **MCP-INV-3**: Observation 重複排除
- **MCP-INV-4**: 監査ログ完全性
- **FB-INV-1〜5**: フィードバックループ冪等性・原子性等
- **STATE-INV-1/2**: ステートフル限定・graph.toml Git 管理
- **SUBNODE-INV-1〜6**: サブノード不変条件（TE-NEXT-EXT-001）

### C. 参考リンク

- 上位仕様書: `docs/simple_VDRS_TopLevelSpec.md`（V-DRS-SPEC-001）
- サブノード化仕様: `docs/traceability_engine_subnode_spec_v0.2.1.md`（TE-NEXT-EXT-001）
- キャッシュ仕様: `docs/traceability_engine_cache_spec_v0_1_0.md`（TE-NEXT-EXT-002）
- v0.1.0 マニュアル: `old.source/docs/manual.md`（歴史的経緯参照用）
- CLAUDE.md テンプレート: `docs/old.manual/claude-md-template.md`

---

**文書改訂履歴**

| 日付 | バージョン | 変更内容 |
|------|----------|---------|
| 2026-04-19 | 0.2.0 初版 | v3 アーキテクチャ対応、17 サブコマンド・graph.toml 主体・サブノード・Contextual Retrieval・migrate コマンド等を反映 |
| 2026-04-19 | 0.2.0 rev1 | MCP ブロック s1 完了で §8 を全面改訂。アーキテクチャ図、3 ツール詳細仕様（zod schema + 下位呼出 + 出力例）、Admin Surface 分離、v3 拡張まとめ、テスト実行・起動確認手順、トラブルシューティング Q8〜Q10 を追加。better-sqlite3 依存削除（REQ.05 ステートレス性）、Node.js LTS 固定（COMPAT.10）を明記 |
| 2026-04-19 | **0.2.0 rev2（正式版）** | **v3 プロジェクト全 9 ブロック完成を反映**。MCP ブロック s2 実装 + adv1 Finding 0 件で一発 PASS + G3 通過を受け、ヘッダステータスを「全 9 ブロック完成、v3 v0.2.0 正式版」に昇格。テスト実測値を確定（Rust 223 passed + 16 ignored、TypeScript 13 passed + 2 skipped、skipIf は `RUN_STRESS` / `RUN_PERF` env で有効化）。§13 Q10 のログ記述から「s2 実装時に対応」を削除。§5.3 テストブロックを実測値ベースに更新 |
| 2026-04-20 | **0.2.0 rev3** | **2026-04-20 の 4 追加 Block（INIT / SEM / RPT / CAL）完成を反映**。§2 に追加実装事項（SemanticChecker 本実装、init ICONIX 完全 template、report/calibrate 実装、`area="XX"` Info / `{id}` Warning）を追記、§5.3 テスト実測値を 253 passed + 19 ignored へ更新、§6.1 init 生成物を 10 ディレクトリ + 9 .gitkeep へ更新、§6.4 graph.toml サンプルに `type` フィールド追加、§6.5 `--json` 位置を修正（グローバルフラグ）、§7 検証系表に SemanticChecker / report / calibrate の新情報、§7 フィードバックループ表末尾に v0.1.0→v3 observe 移行注記、§9 に graph.toml 更新主体（手動編集前提、FS 監視なし）の事実記述、§10.4 パイプライン opt-in 運用説明を新設、§11 template の `version = "0.1.0"` 削除 + `[contextual_retrieval]` 注釈更新、§13 Q6 に新規 Info/Warning 追記、Q8-Q10 を番号順に並べ替え、Q11（FS イベント時のグラフ更新）・Q12（`--json` フラグ位置）を新規追加。`/sc:analyze` Finding 1 / Finding 3 / 事実確認調査（FS イベント → グラフ操作マッピング）の結果を一括反映 |
| 2026-04-20 | 0.2.0 rev3.1 | **プロセス非依存性の明確化**（ユーザー問合せ「ICONIX でなくても使えるのか」への対応）。§2.5 新設「プロセス非依存性（ICONIX 以外でも使える）」— エンジン本体が process-agnostic である根拠、Waterfall/Agile/BDD の `.trace-engine.toml` 設定例、非 ICONIX 採用時の運用手順、`file_pattern` の 2 値説明、制限事項を記載。§6.1 init 生成物説明に「非 ICONIX プロセスの場合は §2.5 を参照」の誘導を追加。§9 CLAUDE.md サンプルの前書きに「ICONIX 想定の例」の明示を追加。SPEC-TE-008.REQ.07 と DD-TE-007 §3.1.1 の表現を「ICONIX 標準 template」から「既定は ICONIX、エンジン本体はプロセス非依存」に改訂 |
| 2026-04-27 | **0.3.0** | **ISSUE-001 対応: ID 再定義検出機能（IdRedefined / IdSemanticMismatch）追加**。SPEC-TE-004 v0.4.0 で REQ.11 / REQ.12 を新設。§7 検証系表の `check --formal` カテゴリ列に IdRedefined / IdSemanticMismatch を追記。§13 Q6 に新規 Warning / Info の説明を追加。§11 を新設し「ID 再定義検出（IdRedefined / IdSemanticMismatch）」運用ガイドを記載。`.trace-engine.toml` に `[id_changelog]` / `[id_semantic_mismatch]` セクションを追加可能に（デフォルト OFF / 後方互換性維持）。テスト実測 50 passed for te-check（既存 39 + 新規 11） |
| 2026-04-27 | 0.3.0 rev1 | **ISSUE-002 / ISSUE-003 / ISSUE-004 同時対応**。(1) ISSUE-002: `embedding_snapshots` テーブル + `snapshot create/list/delete` サブコマンド + `drift --against snapshot:LABEL` 追加。drift baseline の凍結・時系列観測が可能に。(2) ISSUE-003: `[semantic].vector_store` 廃止。`SemanticConfig` から削除、デフォルトテンプレートからも除去、旧設定検出時に Info 警告。(3) ISSUE-004: `calibrate --recommend` 追加、percentile（p10/p25/p50/p75/p90）ベースで 3 閾値の推奨値を出力。§12 を新設し「drift baseline / snapshot 運用」を記載 |
| 2026-04-28 | **0.4.0-alpha1** | **TE-NEXT-EXT-001 Phase 2 Block A + Block D 実装**。(A) サブノード embedding 登録の実体化: `embed --all` のデフォルトでサブノード（h2/h3 自動抽出）も embedding し engine.db に格納。`embeddings` テーブルに `parent_id` / `anchor` / `is_subnode` カラム追加（既存 DB は ALTER TABLE 自動 migration）。サブノードは `Node.content_range` で切り出した部分テキストのみを入力にし、テンプレ寄与（ISSUE-005）を構造的排除。`[semantic].include_subnodes = false` で Phase 1 動作復帰可。SPEC-TE-006.REQ.09 を Phase 1 予約 → Phase 2 実装に格上げ、REQ.12 サブノード embedding 格納項目を新設。(D) graph.toml ドキュメントノードに `heading_levels` フィールド追加（既定 [2, 3]、明示で [2, 3, 4] 等カスタマイズ可、TE-NEXT-EXT-001 §4.1）。Block B/C/E/F は alpha2 以降で順次実装予定 |
| 2026-04-28 | 0.4.0-alpha1+rev | **ISSUE-003 BUG-1/2/3 修正**。(BUG-1) CLI で `include_subnodes: false` ハードコード問題を解消、`SemanticConfig.include_subnodes`（既定 true）追加。(BUG-2) ALTER TABLE 自動 migration 順序修正（`migrate_embeddings_phase2` を `execute_batch` より先に実行）。(BUG-3) drift 系関数（`compute_node_drift_at` / `_against_snapshot`）がサブノードでも `node.path` 全文を読んでいた問題を修正、`read_current_content_for_node` ヘルパで content_range を尊重 |
| 2026-04-28 | **0.4.0-alpha2** | **TE-NEXT-EXT-001 Phase 2 Block F 実装（ISSUE-001 機能 C 本体）**。SPEC-TE-004.REQ.13 IdSemanticDrift サブノード単位意味類似度検査を新設。`check --formal` の 9 番目チェッカとして注入。SPEC サブノード（定義側）と下流サブノード（引用側）が同一 ID を引用するペアの cosine_similarity を計算 → 閾値（既定 0.75）未満で Warning。`[id_semantic_drift].enabled = true` で動作（既定 OFF）。embedding 不在時はスキップ（G1 非阻害）。3 層防御完成: 機能 A（IdRedefined 宣言）+ 機能 B（IdSemanticMismatch regex）+ 機能 C（IdSemanticDrift embedding）。**ISSUE-001 完全クローズ**。テスト 273 passed（既存 268 + 新規 T-ISD-001〜005）|
| 2026-04-28 | **0.4.0-alpha2.1** | **app dogfeeding feedback 反映（観察事項 1+2+3 一括）**。(1) `IdSemanticDrift` WARNING メッセージに **path + subnode anchor** を追加（ISSUE-001 §2.3 期待形式整合）。(2) §11.4.1 に **プロジェクト規模別閾値ガイド** 追記（app 112 ノード規模で 479 件発火を踏まえ、中規模は 0.45〜0.6、大規模は 0.4〜0.5 を推奨）。(3) `deploy/manual.md` を配布物同梱、`deploy/INSTALL.md` から参照を明示。回帰テスト T-ISD-006（path/anchor が message に含まれること）追加、合計 274 passed |
| 2026-04-28 | **0.4.0-alpha3** | **TE-NEXT-EXT-001 Phase 2 Block B 実装（compile_context UX 拡張）**。app dogfeeding 観察事項 1（`--granularity subnode` が document と同等動作）を解消。(1) `Granularity::Subnode` 時に親ドキュメント upstream を **個別サブノード artifact に展開**（content_range 切り出しでテンプレ寄与排除）。(2) **`--sections <ids>`** 追加（コンマ区切りでサブノード ID 指定、機能 C テストの効率化）。(3) **`--depth N`** 追加（上流 N 階層に制限、UpstreamWalker 拡張）。(4) **`--outline-only`** 追加（h1〜h3 見出しリストのみ返却、本文省略）。新規テスト 6 件（t_blockb_001〜006）、合計 280 passed。MCP インタフェースは alpha4 以降で連動 |
| 2026-04-28 | **0.4.0-alpha4** | **TE-NEXT-EXT-001 Phase 2 Block E 実装（refresh-subnodes ツール）**。新規 CLI コマンド `legixy refresh-subnodes [--dry-run \| --apply]`。見出しリネームに伴うサブノード ID 連鎖変化（TE-NEXT-EXT-001 §9.3 既知の限界）を半自動でエッジに反映。差分検出は heading_path のレーベンシュタイン距離でリネームペアを推定、明示 ID（`#s:`）は不変。`--apply` は `.refresh-bak.{epoch}` で graph.toml をバックアップしてから書換。新規テスト 6 件（t_rs_001〜006）、合計 286 passed。DOC-COMPLETE / MCP-SYNC は別セッションで並列実装可能 |
| 2026-04-28 | 0.4.0-alpha4 補完 | **alpha4 並列 Agent による DOC-COMPLETE + MCP-SYNC 完成**。(MCP-SYNC) ts-mcp の `compile_context` Zod schema に `outline_only` / `sections` / `depth` を追加（Block B 4 引数すべてが Claude Code 経由で利用可能に）。SPEC-TE-009 v0.4.0 + DD-TE-008 v0.2.0 改訂、ts-mcp テスト 24 passed（既存 13 + 新規 11、`tests/tools/compile-context.test.ts` 新設）。(DOC-COMPLETE) SPEC-TE-003 v0.4.0 で REQ.15-17（outline_only / sections / depth_limit）を formal 化、UC-TE-002/004 / RB-TE-002/004 / SEQ-TE-002/004 / DD-TE-002 §11 / TS-TE-002 §15（T-CC-OUTLINE-001/SECTIONS-001/DEPTH-001/SUBNODE-001/SUBNODE-002/OUTLINE-FALLBACK）連鎖整備、テスト件数集計 51→57。**Phase 2 機能リリース + 連鎖整備が完成、alpha5 Block C（CR-PROD）と rc1 検証へ進む状態** |

---

## 14. ID 再定義検出（IdRedefined / IdSemanticMismatch / IdSemanticDrift、ISSUE-001）

### 14.1 背景

app プロジェクトで以下のドリフトが発生した:

- SRS（SPEC-APP-007）§5 NFR セクションを増補し、`NFR-PERF-001` を「汎用カテゴリ」から「即座応答 200ms 以内」に **限定再定義**
- mtime ベース freshness は WARNING を出すが、**意味の再定義そのもの** は検出できず、UC 側に「コールドスタートを含むプロジェクトオープン完了まで 5 秒以内」のような旧定義引用が 31 件残存

これに対応する 2 種類の検査を `check --formal` に追加した（**デフォルト OFF**、後方互換性維持）。

### 14.2 機能 A: ID Changelog 宣言検出（IdRedefined）

**目的:** SPEC で「同一 ID の意味再定義」を明示宣言し、引用箇所を機械的に列挙する。

**有効化:** `.trace-engine.toml` に以下を追加。

```toml
[id_changelog]
enabled = true
source = "spec_header"           # spec_header | toml_config | both（既定: spec_header）
citation_pattern = "\\|\\s*{ID}\\s*\\|"  # {ID} は対象 ID で置換される正規表現
max_citations_per_id = 50
```

**SPEC ファイル本文側の宣言例:**

```markdown
Document ID: SPEC-APP-007

# SRS

## ID Changelog

| Date | ID | Change | Note |
|------|----|--------|------|
| 2026-04-26 | NFR-PERF-001 | redefined | 汎用 → 即座応答 200ms 限定。旧用法は NFR-PERF-COLD-001 に移管 |
| 2026-04-26 | NFR-PERF-COLD-001 | new | コールドスタート 5 秒以内 |
```

**TOML 配列での宣言例（`source = "toml_config"` または `"both"` 時）:**

```toml
[[id_changelog_entry]]
spec = "SPEC-APP-007"
date = "2026-04-26"
id = "NFR-PERF-001"
change = "redefined"
note = "汎用 → 即座応答 200ms 限定"
```

**`check --formal` 実行時の出力例:**

```
[WARNING] IdRedefined: 'NFR-PERF-001' は SPEC-APP-007 で 2026-04-26 に再定義されました。以下の引用箇所を確認してください:
  docs/usecases/UC-APP-001_create-project.md:130 | NFR-PERF-001 | コールドスタートを含む新規作成完了まで 5 秒以内
  docs/usecases/UC-APP-002_open-project.md:163 | NFR-PERF-001 | コールドスタートを含むプロジェクトオープン完了まで 5 秒以内
 [related_ids: NFR-PERF-001, SPEC-APP-007, UC-APP-001, UC-APP-002]
```

**運用手順:**

1. SPEC を編集して ID の意味を変える際、本文末尾近くに `## ID Changelog` セクションを追加し `change = "redefined"` を宣言
2. `legixy check --formal` を実行
3. WARNING リストに沿って引用箇所を 1 件ずつ確認・修正（誤った数値を新しい ID に振り替える、または定義に合わせて引用文を更新）
4. 引用箇所の修正完了後、再度 `check --formal` を実行して残件確認

**注意:**
- `enabled = false`（既定）では本検査はスキップされる。後方互換性のため明示的有効化が必要
- `change = "new"` / `"removed"` は宣言可能だが Phase 1 では引用列挙の対象外（将来拡張）
- Severity は Warning。Error にはならないため G1 ゲート通過を阻害しない

### 14.3 機能 B: ID 引用整合性検査（IdSemanticMismatch）

**目的:** Changelog 宣言を忘れたケースに対するセーフティネットとして、SPEC 定義表の数値・キーワードと下流引用文の不整合を検出する。

**有効化:**

```toml
[id_semantic_mismatch]
enabled = true
severity = "info"            # info | warning（既定: info、false-positive 抑制）
unit_normalization = true    # ms ↔ 秒 ↔ 分 を正規化（200ms と 0.2 秒 を一致扱い）
keywords = ["クラッシュリカバリ", "ロールバック"]   # project-specific 必須キーワード辞書（既定: 空）
```

**動作概要:**

- SPEC ノードから Markdown 表行（`| ID | カテゴリ | 目標値 | ... |`）を抽出
- 各 ID 行の数値リテラル（`200ms`, `5 秒` 等）と `keywords` の出現を記録
- 下流 chain ノードを行単位でスキャンし、同一 ID を引用する行から数値・キーワードを抽出
- SPEC 定義と引用で **数値が異なる**（単位正規化後）または **必須キーワードが欠落** している場合に警告

**出力例:**

```
[INFO] IdSemanticMismatch: 'NFR-PERF-001' の SPEC 定義と引用文に不整合があります。数値不一致（SPEC: 即座応答 | 200ms 以内 / 引用: NFR-PERF-001 | 5 秒以内） （引用箇所: docs/usecases/UC-APP-002_open-project.md:163）
 [related_ids: NFR-PERF-001, UC-APP-002]
```

**注意:**
- `enabled = false`（既定）では本検査はスキップされる
- Severity は既定 Info（false-positive 多発に備えて控えめ）。`severity = "warning"` で昇格可能
- 引用行に数値が含まれない場合は判定対象外（false-positive 防止）
- `keywords` は明示的に列挙したものだけ判定対象。デフォルト辞書は提供しない

### 14.4 機能 A と機能 B の使い分け

| 状況 | 推奨設定 |
|------|---------|
| 規律ある SPEC 運用（SPEC 編集時に必ず Changelog を更新） | A: ON、B: OFF |
| Changelog 宣言を忘れがちで数値が頻繁に変わる | A: ON、B: ON（severity = "info"）|
| 厳格運用（数値不整合は即座にエラー扱い） | A: ON、B: ON（severity = "warning"）+ keywords 整備 |
| 既存プロジェクトで未対応のまま稼働させたい | 両方 OFF（既定値、v0.2.0 と同等の出力） |

### 14.4.0 compile_context UX 拡張（v0.4.0-alpha3、TE-NEXT-EXT-001 Phase 2 Block B）

app dogfeeding で発見された観察事項 1（`--granularity subnode` が document と同等動作）を解消し、3 つの新フラグを追加しました。

**`--granularity subnode`（本来動作）:**

```bash
legixy context tests/TC-TE-001.rs --granularity subnode
```

親ドキュメント全文ではなく、**子サブノード（h2/h3 見出し）を個別 upstream artifact として展開**して返します。各サブノードは `content_range` で切り出した部分テキストのみを body に含み、`Document ID:` 行・ヘッダ表・変更履歴等のテンプレ部分を排除（ISSUE-005 構造的対応）。

サブノードを持たない上流ドキュメントは fallback で全文を返します（後方互換）。

**`--sections <id_list>`:**

```bash
legixy context tests/TC-TE-001.rs \
  --granularity subnode \
  --sections "DD-TE-003#a3f7,DD-TE-003#b8c2"
```

指定されたサブノード ID のみを返却。機能 C（IdSemanticDrift）の特定ペア検証で便利。

**`--depth N`:**

```bash
legixy context tests/TC-TE-001.rs --depth 2
```

target から **N 階層上流まで** に走査を制限。深い chain（SPEC → UC → RB → SEQ → DD → TS → TC → SRC = 7 階層）で「直近の DD だけ見たい」等の絞り込みに使用。`--depth 1` で直接の親のみ、`--depth 2` で祖父まで。省略時は無制限（v0.2.0 互換）。

**`--outline-only`:**

```bash
legixy context tests/TC-TE-001.rs --outline-only
```

各 upstream artifact の本文を **h1〜h3 見出しリストのみ** に置換。階層インデント付きで返却:

```
- Title
  - Section A
  - Section B
```

トークン消費を大幅削減（app 88,303 bytes → outline で数 KB 程度）。「上流の構成だけ確認したい」用途に使用。`--granularity subnode` と組み合わせるとサブノードの anchor のみ返却。

**3 フラグの組合せ例:**

```bash
# 直近 2 階層のサブノード見出しのみ
legixy context tests/TC-X.rs --granularity subnode --depth 2 --outline-only
```

### 14.4.1 機能 C: サブノード単位意味類似度検査（IdSemanticDrift、v0.4.0-alpha2、ISSUE-001 機能 C 本体）

**目的:** SPEC で定義された ID（例: `NFR-PERF-001`）について、SPEC 内のサブノード（定義側）と下流（UC/RB/SEQ）のサブノード（引用側）の **embedding cosine_similarity** を計算し、閾値未満なら Warning として報告する。機能 A/B が宣言・regex で補えない「表記揺れ + 定義シフトの併発」を最終的に拾う 3 層防御の embedding レイヤ。

**前提条件:**
- `legixy embed --all` が実行済（サブノード embedding が `is_subnode=1` で永続化されている）
- ONNX モデル配置済み（`embed --all` の前提）
- `[semantic].include_subnodes = true`（既定、Phase 2 alpha1 以降）

**有効化（`.trace-engine.toml`）:**

```toml
[id_semantic_drift]
enabled = true
similarity_threshold = 0.75      # 既定値、これ未満を Warning
citation_pattern = "\\|\\s*{ID}\\s*\\|"  # 機能 A/B と統一
max_pairs_per_id = 50            # 1 ID あたりの比較ペア上限
```

**動作概要:**

1. 全 SPEC ファイルから ID を収集（`## ID Changelog` 表 + 定義表）
2. 全サブノードを走査し、本文に ID の citation_pattern がマッチするものを抽出
3. SPEC 親ノードに属するサブノードを「定義側」、それ以外を「引用側」として分類
4. 各 (定義, 引用) ペアで embedding 類似度を計算
5. 閾値未満のペアを `IdSemanticDrift` Warning として報告

**出力例:**

```
[WARNING] IdSemanticDrift: 'NFR-PERF-001' の SPEC 定義と引用文の意味類似度が 0.6234（閾値 0.75 未満）
  SPEC: SPEC-APP-007 (subnode: SPEC-APP-007#nfr-perf-001)
  引用: UC-APP-002 (subnode: UC-APP-002#nfr-references)
 [related_ids: NFR-PERF-001, SPEC-APP-007#nfr-perf-001, UC-APP-002#nfr-references]
```

**機能 A / B / C の三層防御使い分け:**

| 機能 | 検出原理 | 強み | 弱点 |
|------|---------|------|------|
| A IdRedefined | Changelog 宣言ベース | 明示宣言があれば確実 | 宣言忘れに弱い |
| B IdSemanticMismatch | 数値・キーワード regex | 規則的な数値不一致を検出 | 表記揺れに弱い |
| **C IdSemanticDrift** | **embedding 類似度** | **表記揺れ + 定義シフト併発を捕捉** | **embed --all 実行が前提** |

3 つを同時 ON すると最大の検出力。A/B/C は独立に動作可。

**embedding 不在時の挙動:**
- `embed --all` 未実行 / engine.db 不在 → 0 件発行（致命扱いせず、G1 ゲート非阻害）
- 該当サブノードの embedding が個別に欠落 → そのペアをスキップ

**性能:** 全ペア cosine_similarity 計算は線形コスト（数千ペア × 384 次元 = 数 ms）。100 ノード規模のプロジェクトで `check --formal` 全体への追加遅延は < 100 ms。

**閾値設定ガイド（v0.4.0-alpha2.1 追記、app dogfeeding 結果反映）:**

app（112 ノード規模）で `[id_semantic_drift].similarity_threshold = 0.75`（既定）のまま `check --formal` を実行したところ **479 件の Warning + 3 件 Info** が発火しました。これは仕様どおりの感度ですが、SPEC 短文 vs UC 長文の構造差で類似度が 0.4〜0.6 帯に大量に分布するため、運用上は **プロジェクト規模・記述スタイルに応じた調整** が必要です。

| プロジェクト規模 | 推奨 `similarity_threshold` | 想定発火数の目安 |
|----------------|---------------------------:|----------------|
| 小規模（< 50 ノード）| 0.6 〜 0.75（既定）| 数十件以下 |
| **中規模（50〜200 ノード、app 等）**| **0.45 〜 0.6** | 数十〜数百件 |
| 大規模（> 200 ノード）| 0.4 〜 0.5 | 数百件 |

**閾値の探し方**:

1. まず `legixy calibrate --recommend` で全ペア類似度の percentile（p10/p25/p50/p75/p90）を確認
2. サブノード embedding を含む状態（v0.4.0-alpha1 以降）での p25 前後を `similarity_threshold` に設定するのが妥当
3. 出力を確認しながら 0.05 刻みで調整。発火が少なすぎる → 上げる、ノイズが多い → 下げる
4. ISSUE-005 §2.3 で記録された **app Phase 1 ノード単位 mean=0.6798** から推測すると、**サブノード単位では mean=0.4〜0.5 程度** に下がるため、最終的な絶対値はプロジェクトごとに異なる

**注意**: 機能 C は **絶対類似度ではなく相対分布** で判断する性格の検査です。閾値を厳しすぎると false-positive が大量発生し、緩すぎると本物のドリフトを見逃します。calibrate データを必ず参照してください。

**他のチューニング:**
- `max_pairs_per_id`（既定 50）: 1 ID あたり多数の引用がある場合の打切り。app で NFR-USABILITY/RELIABILITY/A11Y 系で 51 件/ID が観測されたため、**全件確認したい場合は 100〜200 に増やす**
- `citation_pattern`: 既定 `\|\s*{ID}\s*\|`（表行）。本文中の自由記述も拾いたい場合はパターン拡張可

### 14.5 既知の制限

- 機能 B の数値抽出は最初にマッチした 1 個のみ採用。複数値の取扱いは将来拡張
- 機能 A の citation_pattern は `\|\s*{ID}\s*\|`（表行内の単独出現）が既定。本文中の引用も拾いたい場合はパターンを書き換える
- サブノード単位（SPEC 内 §5.1 行レベル vs UC 内 §3.2 行レベル）の embedding 比較（ISSUE-001 §2.3 の機能 C）は **本リリース未実装**。`TE-NEXT-EXT-001` Phase 2（サブノード embedding 登録）完了後に追加予定（DD-TE-003 §9 観察事項 6）

---

## 15. drift baseline と snapshot 運用（ISSUE-002）

### 15.1 背景

v0.3.0 rev1 以前の `drift` コマンドは **`embeddings` テーブルの現行行と比較** するだけで、`embed --all` を実行するたび baseline が上書きされる仕様だった。結果として「2026-01 リリース時点との比較」のような **時系列定点観測ができない** 問題があった（ISSUE-002）。

v0.3.0 rev1 で `embedding_snapshots` テーブルと `snapshot` サブコマンド群を導入し、任意時点の embedding をフリーズして後で参照できるようにした。

### 15.2 基本フロー

```bash
# 1. baseline を作成（ラベル付き、後で参照しやすい）
legixy embed --all
legixy snapshot create --label "release-v1.0"
# → snapshot_id = snap-XXXXXXXXXXXXX-YYYYYYYY が表示される

# 2. ファイルを編集してから drift を取る
vim docs/specs/SPEC-XXX-001_*.md

# 3. snapshot 経由で drift を計算
legixy drift SPEC-XXX-001 --against snapshot:release-v1.0
# → drift = 0.1234
#   baseline: snapshot snap-XXXX...

# 4. snapshot 一覧を確認
legixy snapshot list

# 5. 不要になった snapshot を削除
legixy snapshot delete label:release-v1.0
# または snapshot_id を直接指定
legixy snapshot delete snap-XXXXXXXXXXXXX-YYYYYYYY
```

### 15.3 `--against` の値フォーマット

| 形式 | 解釈 |
|------|------|
| 省略 | `embeddings` テーブル現行行と比較（v0.2.0 互換挙動）|
| `snapshot:label:LABEL` | label で指定された最新スナップショットと比較 |
| `snapshot:LABEL`（label が一致する場合）| 上と同じ。label 不在なら下に fallback |
| `snapshot:<snapshot_id>` | snapshot_id 直接指定（ID をコピペする運用）|

### 15.4 ストレージ影響

- 1 スナップショット = ノード数 × embedding サイズ（all-MiniLM-L6-v2 で 384 次元 × 4 byte = 1.5 KB / ノード）
- 100 ノードのプロジェクトで 1 スナップショット = 約 150 KB（実用上無視できる）
- 大量保持しても問題ないが、`snapshot delete` で随時整理可能

### 15.5 ドッグフィーディングでの活用

V-DRS-SPEC-001 §14.5 Phase 4 のドッグフィーディングで、以下のような時系列観測が可能:

```bash
# 各リリース時点で snapshot 作成
legixy snapshot create --label "v0.3.0"
# ... 開発を継続 ...
legixy snapshot create --label "v0.4.0"
# ... さらに継続 ...

# 「v0.3.0 から v0.4.0 までで最も変化したノード」を調査
for id in $(grep '^id = ' docs/traceability/graph.toml | cut -d'"' -f2); do
    echo -n "$id: "
    legixy drift "$id" --against snapshot:v0.3.0 --json | \
        jq -r '.drift // "n/a"'
done | sort -t: -k2 -gr
```

### 15.6 注意事項

- snapshot 内の embedding は **モデルバージョンと content_hash を保持** するため、後でモデルを変更すると比較不能になる（次元不一致エラー）
- `model_version` が異なる baseline と current は drift 計算で `EmbedError::DimensionMismatch` を返す → snapshot 作成時のモデルを記録しておくこと
- `snapshot delete` は **取り消し不可**。重要な baseline はラベル管理で識別性を保つこと

---

## 16. refresh-subnodes（見出しリネーム連鎖変化対応、Phase 2 Block E、v0.4.0-alpha4）

### 16.1 背景

TE-NEXT-EXT-001 §9.3 に既知の限界として記載された「上位見出しのリネームは配下のサブノード ID を連鎖的に変化させる」問題への対応ツール。

サブノード ID（auto-generated）は `{親ID}#{ハッシュ16文字}` 形式で、ハッシュは見出しテキストから決定論的に計算される。そのため `## 認証機能` を `## 認証・認可機能` にリネームすると、配下の `DD-APP-001#a3f7b2c4e91dfa08` が `DD-APP-001#b8c2a4f1e76dab12` に変化し、graph.toml の chain/parent_child/custom edges が古い ID を参照したままになる（孤立エッジ化）。

`refresh-subnodes` は (1) この差分を検出し、(2) heading anchor の編集距離でリネームペアを推定、(3) graph.toml と edges を半自動で更新する。

### 16.2 基本フロー

```bash
# 1. dry-run で差分を確認（既定動作）
legixy refresh-subnodes
# または明示的に
legixy refresh-subnodes --dry-run

# 2. 出力を確認、人間判断で renames が妥当なら apply
legixy refresh-subnodes --apply
# graph.toml.refresh-bak.{epoch} に自動バックアップが残る

# 3. 必要なら git でレビュー / 取消
git diff docs/traceability/graph.toml
# 不要な変更があればバックアップから戻す
cp docs/traceability/graph.toml.refresh-bak.1714296000 docs/traceability/graph.toml
```

### 16.3 dry-run 出力例

```
=== Subnode ID changes detected (dry-run) ===

--- Renames (1 件) ---
  DD-APP-001#a3f7b2c4e91dfa08  →  DD-APP-001#b8c2a4f1e76dab12
    parent:    DD-APP-001
    heading:   "## 認証機能" → "認証・認可機能"
    edges:     chain/parent_child 3 件、custom 1 件

--- Removed (graph.toml に残るが現ファイルに無い、1 件) ---
  DD-APP-002#deadbeefcafebabe (parent: DD-APP-002, heading: "## 削除済セクション")

--- Added (現ファイルに新出、1 件) ---
  DD-APP-003#newhash00000000 (parent: DD-APP-003, heading: "新セクション")

Summary: 1 renames, 2 orphans, 5 parent docs scanned

Run with --apply to commit changes (graph.toml は .refresh-bak.{epoch} にバックアップされます)
```

### 16.4 ペアリングアルゴリズム

1. 各親ドキュメントについて graph.toml の auto-generated サブノードと現ファイル抽出結果を比較
2. graph.toml にあって現ファイル抽出に出ない → `removed` 候補
3. 現ファイル抽出に出るが graph.toml に無い → `added` 候補
4. removed/added の各ペアに対し、heading anchor の **レーベンシュタイン距離** を計算
5. 最小距離のペアから順に `rename` として確定（同距離なら graph 順）
6. ペア化されなかった removed/added は `orphan` として記録

ペア化精度は heading の編集の小ささに依存。大規模リネーム（語順入替等）は orphan として残ることがあり、人間判断で追加対応する。

### 16.5 重要原則

| 原則 | 内容 |
|------|------|
| **完全自動化はしない** | dry-run 必須、`--apply` は人間判断後 |
| **明示 ID（`#s:` 接頭辞）は不変** | `DD-APP-001#s:cross-section-logic` のような明示宣言サブノードは対象外。ハッシュ ID（`#a3f7...`）のみ rename される |
| **graph.toml の commit は人間** | `--apply` は編集まで、`git add` / `git commit` はユーザ責任 |
| **バックアップ必須** | `--apply` 実行前に `graph.toml.refresh-bak.{epoch}` を生成。万一の誤適用に対する安全網 |
| **engine.db との整合は別工程** | embeddings の `node_id` 自動更新は本コマンドに含まない。古い ID の embedding 行が残る場合は `embed --all --force` で再生成 |

### 16.6 apply 後の推奨手順

```bash
# 1. 変更を git レビュー
git diff docs/traceability/graph.toml

# 2. embeddings の整合性回復（古い ID のサブノード embedding を新 ID で再登録）
legixy embed --all --force

# 3. check で整合性確認
legixy check --formal

# 4. 機能 C を有効化している場合は再 calibrate
legixy calibrate --recommend
```

### 16.7 制限事項と既知のエッジケース

- **複数同名見出し**: 同一親内で `## section` が複数回現れると h2_context 等で識別されるが、リネーム時に対応が曖昧になる場合がある → 個別確認を推奨
- **大規模リネーム**: 編集距離が大きすぎると orphan 化される（heading 全体長の 50% 程度を目安）。手動で graph.toml を直接編集する方が確実
- **custom_edges の更新**: graph.toml の `[[edges]]` のみ更新する。engine.db の `custom_edges` テーブルが別途存在するプロジェクトでは個別対応が必要
- **JSON 出力**: `--json` で構造化出力。CI 統合時に `renames` / `orphans` 配列を自動処理する用途で利用
