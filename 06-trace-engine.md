# 06 — legixy 運用

このドキュメントは legixy v3 を実行・設定するときに参照する。

ツール本体は別配布: `~/.local/bin/legixy`（v0.4.0-alpha4 以降）。本フレームワークはlegixy を前提とする（grep-only fallback は提供しない）。

詳細仕様は `manual/legixy/manual.md` を参照（公式マニュアルのコピー）。本ドキュメントは本フレームワーク運用上の最低限のサマリ。

## 1. `.trace-engine.toml` の構造

`bootstrap/trace-engine.toml.template` をコピーして、`area` を自プロジェクト用に置換する。主要セクション:

```toml
[project]
name = "<your-project>"

[graph]
file = "docs/traceability/graph.toml"

[matrix]
format = "markdown"
file = "docs/traceability/matrix.md"
section = "Traceability Matrix"

[id]
pattern = "{type}-{area}-{seq}"   # 3 パート固定（v3 仕様）
area = "<AREA>"
seq_digits = 3

[id.chain]
order = ["UC", "RB", "SEQ", "DD", "TS", "TC", "SRC"]
independent = ["SPEC", "TP", "GAP", "ADR", "AT", "NFR", "VAL"]

[id.document_id]
pattern = "Document ID:"

# 各 typecode のディレクトリ・拡張子・file_pattern 定義
[id.types.SPEC]
dir = "docs/specs/"
ext = ".md"
file_pattern = "prefix"

# ... 他 typecode の定義 ...
```

`file_pattern` の意味:

- **`prefix`**: ファイル名が `{ID}_<description>.<ext>` 形式（最初のアンダースコアまでが ID）
- **`contains`**: ファイル先頭 32 行以内に `Document ID: {ID}` 行が含まれる

## 2. graph.toml の構造

`docs/traceability/graph.toml` に全成果物を `[[nodes]]` として登録する。

```toml
[[nodes]]
id = "SPEC-<AREA>-001"
type = "SPEC"
path = "docs/specs/SPEC-<AREA>-001_<description>.md"

[[nodes]]
id = "QSET-<AREA>-001"
type = "QSET"
path = "docs/frontend-pass/questionnaires/QSET-<AREA>-001.md"

[[nodes]]
id = "SPP-<AREA>-001"
type = "SPP"
path = "docs/spec-patches/SPP-<AREA>-001.md"

[[nodes]]
id = "FCR-<AREA>-001"
type = "FCR"
path = "docs/frontend-pass/check-results/FCR-<AREA>-001.md"

[[nodes]]
id = "TP-<AREA>-001"
type = "TP"
path = "docs/test-perspectives/TP-<AREA>-001.md"

[[edges]]
from = "UC-<AREA>-001"
to = "RB-<AREA>-001"
kind = "chain"
```

- `[[nodes]]` の `type` は必須
- `[[edges]]` の `kind` は `chain` / `parent_child` / `custom`
- chain 内成果物の親子関係は `chain.order` から自動推測されるため、edges に書かなくてよい
- chain 外成果物の関連は本文 metadata で管理
- 前段ループ成果物（QSET / SPP / FCR）の SPEC との親子関係は本文 metadata（`**親 SPEC**:`, `**対象 SPEC**:`）で表現する

## 3. 主要コマンド

```bash
# 第 1 層（形式）検証: ID 形式・ファイル存在・連鎖整合性・Freshness・DAG・OrphanFile・IdRedefined
legixy check --formal

# 第 1 層 + 第 2 層（意味的）検証: ONNX モデル必須
legixy check

# 全成果物の embedding を生成 → engine.db 格納（ONNX モデル必須）
legixy embed --all

# 特定成果物のドリフト検出
legixy drift <artifact_id>

# 順方向探索（影響範囲）
legixy impact SPEC-<AREA>-NNN

# 逆方向探索（依存元）
legixy investigate TC-<AREA>-NNN

# レポート / キャリブレーション
legixy report
legixy calibrate

# JSON 出力（--json はサブコマンドの前）
legixy --json check --formal
```

存在しない（旧 docs に言及があったがlegixy にない）コマンド:

- ~~`trace-engine new`~~ — 自動 ID 生成は未実装。手動で次の連番を採番する
- ~~`trace-engine orphans`~~ — `OrphanFile` は `check` 内のカテゴリで報告される
- ~~`trace-engine check --gap-gate`~~ — legixy にこのオプションはない。GAP gate は `scripts/trace-check.sh` が代替
- ~~`trace-engine check --orphans`~~ — `check --formal` に統合済
- ~~`trace-engine check --semantic`~~ — オプションなしの `check` が第 2 層を実行する

## 4. 第 1 層と第 2 層

| 層 | 内容 | 実行コマンド | ONNX モデル |
|---|---|---|---|
| 第 1 層 | 形式検証（ID 形式・ファイル存在・chain 整合・OrphanFile・IdRedefined・DAG・Freshness） | `check --formal` | 不要 |
| 第 2 層 | 意味検証（SemanticSimilarity / LinkCandidate / Drift） | `check` | 必須（`models/all-MiniLM-L6-v2/`） |

第 1 層だけでも本プロセスの最低限の検証は成立する（chain 整合性 + grep ベース GAP/TP gate）。第 2 層は意味的ドリフト検出を加えて精度を上げる。

第 2 層を有効化する手順:

1. ONNX モデル（all-MiniLM-L6-v2）を `models/all-MiniLM-L6-v2/model.onnx` と `tokenizer.json` として配置
   - 出典: huggingface.co/sentence-transformers/all-MiniLM-L6-v2
2. `legixy embed --all` で初回 embedding 生成
3. `legixy check`（オプションなし）を実行

## 5. SPEC レベル TDD ゲートと統合スクリプト

`bootstrap/trace-check.sh` は以下を統合する:

```bash
bash scripts/trace-check.sh
# 1. legixy check --formal             （第 1 層）
# 2. legixy check                      （第 2 層、ONNX モデルがあれば）
# 3. red 状態の TP がない                           （grep ベース）
# 4. open 状態の GAP がない                         （grep ベース）
```

CI では:

```yaml
- name: Trace integrity gate
  run: bash scripts/trace-check.sh
```

オプション:

| オプション | 意味 |
|---|---|
| `--no-semantic` | 第 2 層を明示的にスキップ（高速 CI 用）|
| `--strict` | ONNX モデルが無い場合を FAIL 扱い（既定は WARN でスキップ）|

## 6. ID Changelog（IdRedefined 検出）

SPEC で ID の意味を変える場合、SPEC 本文末尾に `## ID Changelog` セクションを追加して `change = "redefined"` 行を追記する。これにより `check --formal` が下流成果物の引用箇所を機械列挙する（manual §11.2）。

```markdown
## ID Changelog

| Date | ID | Change | Note |
|------|----|--------|------|
| YYYY-MM-DD | NFR-<AREA>-001 | redefined | 旧定義 → 新定義… |
```

## 7. semantic check の triage

第 2 層で警告が出た場合の判断基準:

- **Block する**: 親成果物の中核 invariant が変わったのに子が更新されていない
- **記録のみ**: 親成果物の表現が変わっただけで意味が同じ（tone, formatting）
- **要確認**: 判別がつかない → 人間判断

triage 結果は `docs/adr/` または `docs/decisions/trace-warnings.md` 等に記録する。

## 8. SPEC 変更時のリグレッション手順

```bash
# 影響範囲の特定
legixy impact SPEC-<AREA>-NNN

# 影響を受ける TP の再評価が必要
# 影響を受ける UC の再評価が必要
# 場合により全下流フェーズの再ゲート

# 第 2 層 semantic で drift 検出
legixy drift SPEC-<AREA>-NNN
```

`impact` が報告する全成果物について、第 2 層 semantic check が pass することを確認。pass しないものは drift しているので追従修正する（ONNX モデル配置時のみ実行可能）。

下流側の試行錯誤の中で「現在の境界 API では探索しづらい」というフィードバックが出た場合、これは下流側の厳格さが上流側の探索性を圧迫している兆候:

1. フィードバックを実装中の仕様書修正として扱わない（ハードルール 6 違反）
2. SPEC / UC / 観点ナレッジベースに立ち戻り、不足を確認する
3. 必要なら次バージョンの SPEC 改訂として API 契約の見直しを行う
4. 新バージョンに対して RBA → SEQA → RBD → SEQD → DD → TS を再生成する

このメタプロセスによって、決定論側の厳格さを保ちながら非決定論側の探索性を殺さない運用を成立させる。

## 9. 領域分割の運用（multi-area）

> 旧版の「v3 は `area` 単一値のみ」という記述は**誤り**として撤回した（`spikes/multi-area-2026-06-14/` で
> 実 v3 バイナリにて反証済み）。legixy v0.4.0-alpha4 は複数 area と area 別チェーンを正式サポートする。

`[id]` に `areas`（配列）を、area ごとに `[[id.chains]]` ブロックを置くと、**1 area = 1 本の線形チェーン**として
独立した chain order を持てる。ID は `pattern = "{type}-{area}-{seq}"` のまま、area 接頭辞でチェーンが解決される
（`resolve_chain_order(seq)` が area で分岐、親は同一 area-seq から `build_id_from_pattern` で算出）。

```toml
[id]
pattern = "{type}-{area}-{seq}"
seq_digits = 3
areas = ["LGX", "CLI", "MCP"]

[[id.chains]]
area  = "LGX"                                  # 機能軸
order = ["UC","RBA","SEQA","RBD","SEQD","DD","TS","TC","SRC"]
independent = ["SPEC","ADR"]

[[id.chains]]
area  = "CLI"                                  # 配送軸（CTR=根）
order = ["CTR","DLV","TS","TC","SRC"]
independent = ["ADR"]
```

**主用途は配送軸（CTR→DLV→TS→TC→SRC）を機能軸と別 area で並走させること**（`12-delivery-layer.md`）。
配送サーフェス（CLI/API/MCP）はそれぞれ独自 area・独自 CTR を根に持つのが原則（共有 CTR は cross-area=custom
エッジ化して根からの走査利益を失う、ch.12 §8）。

> ⚠️ multi-area でも `ChainIntegrity` は `Severity::Warning` 止まりで `check --formal` の exit には影響しない。
> チェーン断裂を**ゲート化**するにはラッパで WARNING を escalate すること（`08-gates.md` 契約適合ゲート / `12-delivery-layer.md` §7）。

## 10. 詳しいリファレンス

公式マニュアルの全文は `manual/legixy/manual.md`。主要章節:

- §2.5 設定ファイル（`.trace-engine.toml`）
- §3 graph.toml の構造
- §4 check サブコマンドの詳細
- §11 ID Changelog と IdRedefined
- §13 トラブルシューティング

別視点: legixy v3 を「シンボルテーブル/DWARF」「ライフサイクル全体の中央装置」「インクリメンタル・コンパイラの依存グラフ」の三側面から記述したレンズは `09-compiler-lens.md` の §3, §7, §8。
