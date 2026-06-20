# 02 — 成果物タイプコード一覧と ID 規則

このドキュメントは新規成果物を作成・命名するときに参照する。

## 1. チェーン上のタイプ

legixy v3 の `chain.order` に登録され、親子関係が自動解決されるタイプ。

| Typecode | 名称 | 役割 | 親（chain） | 場所（既定） | file_pattern |
|---|---|---|---|---|---|
| `UC` | ユースケース | アクター視点の振る舞い記述 | (chain 起点。SPEC は本文で参照) | `docs/usecases/` | `prefix` |
| `RBA` | 抽象ロバストネス図 | ドメイン主語と責務、Boundary/Control/Entity の役割識別 | UC | `docs/robustness-abstract/` | `prefix` |
| `SEQA` | 抽象シーケンス図 | ドメイン主語の交互作用 | RBA | `docs/sequence-abstract/` | `prefix` |
| `RBD` | 具体ロバストネス図 | クラス図レベル、操作名(人間の言語)まで含む | SEQA | `docs/robustness-detail/` | `prefix` |
| `SEQD` | 具体シーケンス図 | クラスインスタンス間メッセージング | RBD | `docs/sequence-detail/` | `prefix` |
| `DD` | 詳細設計 | 言語仕様・動作環境・OS API への mapping | SEQD | `docs/detailed-design/` | `prefix` |
| `TS` | テスト仕様 | TP の観点を実行可能形式に翻訳 | DD（chain）+ TP（参照） | `docs/test-specs/` | `prefix` |
| `TC` | テストコード | TS を機械実行可能なテストに変換 | TS | `tests/` | `contains` |
| `SRC` | 実装コード | TC を通す最小実装 | TC | `src/` | `contains` |

> **二段化された RB/SEQ**: 旧来の単一段 `RB`, `SEQ` は廃止し、抽象側(RBA/SEQA)と具体側(RBD/SEQD)に分離した。抽象側はドメインレベル(言語非依存)、具体側はクラス図レベル(言語非依存、操作名は人間の言語)、DD で言語/環境/OS への翻訳を行う。詳細は `04-iconix-layer.md`。レンズ的視点は `09-compiler-lens.md` §4。

## 2. 独立タイプ（chain 外）

`independent` として登録されるタイプ。親子関係は本文 metadata で表現する。

| Typecode | 名称 | 役割 | 場所（既定） | file_pattern |
|---|---|---|---|---|
| `SPEC` | 仕様書 | プロジェクトの Why と What を確定 | `docs/specs/` | `prefix` |
| `QSET` | Questionnaire Set | AI が SPEC の不足・曖昧・矛盾から生成した質問票 | `docs/frontend-pass/questionnaires/` | `prefix` |
| `SPP` | SPEC Patch Proposal | 質問票への回答を反映した SPEC 差分案 | `docs/spec-patches/` | `prefix` |
| `FCR` | Frontend Check Result | フロントエンド検証結果（`frontend_status` を保持） | `docs/frontend-pass/check-results/` | `prefix` |
| `TP` | Test Perspective | 仕様検証用の観点リスト | `docs/test-perspectives/` | `prefix` |
| `GAP` | Gap Analysis | TP を仕様にぶつけて検出した欠落の記録 | `docs/gap-analysis/` | `prefix` |
| `ADR` | アーキテクチャ判断記録 | SPEC レベルの設計判断の根拠記録 | `docs/adr/` | `prefix` |
| `AT` | 受け入れテスト | 暗黙知・ドメイン慣行・前提不一致の検証 | `docs/acceptance-tests/` | `prefix` |
| `NFR` | 非機能要件 | 性能・並行性・リソース・セキュリティ | `docs/nfr/` | `prefix` |
| `VAL` | 妥当性確認 | プロジェクト全体に対する横断的検証 | `docs/validation/` | `prefix` |
| `RPC` | Responsibility Preservation Check | 抽象責務(RBA/SEQA)から具体責務(RBD/SEQD)への保存性検査(v1.0、`11-responsibility-preservation-check.md`) | `docs/responsibility-preservation/` | `prefix` |
| `PAI` | 完成品適合検査 | ビルド済み完成品を Author と独立に・黒箱で・実環境で凍結契約(CTR)/SPEC へ適合検査(v1.0、`13-product-acceptance-inspection.md`) | `docs/product-acceptance/` | `prefix` |

SPEC レベル TDD ループ（SPEC ⇄ TP ⇄ GAP）および前段ループ（Raw SPEC ⇄ QSET ⇄ SPP ⇄ FCR）はlegixy の chain 検証対象外。本文 metadata + `scripts/trace-check.sh` の grep ベースゲートで運用する。

## 3. ID 規則

各成果物は **3 パート** ID を持つ:

```
{TYPECODE}-{AREA}-{NNN}
```

- `TYPECODE`: 上記表のタイプコード（大文字）
- `AREA`: プロジェクト全体で 1 つ。3〜5 文字推奨。例: `APP`, `OPS`, `PAY`, `CMS`
- `NNN`: 3 桁ゼロ詰め連番（typecode ごとに独立連番）

### 例

```
SPEC-<AREA>-001
QSET-<AREA>-001   # 親: 本文に「**親 SPEC**: SPEC-<AREA>-NNN」「**反復回数**: <N>」
SPP-<AREA>-001    # 親: 本文に「**親 QSET**: QSET-<AREA>-NNN」「**対象 SPEC**: SPEC-<AREA>-NNN」
FCR-<AREA>-001    # 親: 本文に「**対象 SPEC**: SPEC-<AREA>-NNN」「**frontend_status**: ACCEPTED」
TP-<AREA>-001     # 親: 本文に「**親 SPEC**: SPEC-<AREA>-NNN」または「**親 UC**: UC-<AREA>-NNN」
GAP-<AREA>-001    # 親: 本文に「**親 TP**: TP-<AREA>-NNN」
UC-<AREA>-001
RB-<AREA>-001
ADR-<AREA>-001
```

### area の決め方

- 機能チェーンは 1 プロジェクトにつき 1 area が原則。エディション分割・複数製品統合は **命名規則** ではなく **エディションポリシー / プロダクトポリシー** で表現する。
- **複数 area / 複数チェーン（配送層）**: legixy は `[id.areas]` + `[[id.chains]]`（**area 別チェーン**）で multi-area を**実装済み**（2026-06-14 実走確認、`12-delivery-layer.md` §4/§10）。配送サーフェス（CLI/API/MCP 等）は**独自 area**（例 `CLI`/`MCP`）を持ち、機能軸（例 `LGX`）と別の線形チェーンを構成する。配送軸の typecode `CTR`（境界契約・チェーン根）・`DLV`（配送設計）と、再利用する `TS`/`TC`/`SRC` は **area で曖昧性を解消**する（1 area = 1 線形チェーンの制約）。詳細は `12-delivery-layer.md`。
- 旧記述（「area は単一値、`{type}-{area1}-{area2}-{seq}` で拡張」）は撤回。multi-area は `[id.areas]` / `[[id.chains]]` で表現する。

## 4. ファイル命名規則

`file_pattern` の 2 値（legixy v3 manual §2.5.4）:

### `prefix`（Markdown ドキュメント既定）

ファイル名が `{ID}_<description>.md` または `{ID}.md` 形式。

```
SPEC-<AREA>-001_canonical-timeline.md   ← 最初の `_` までが ID
SPEC-<AREA>-001.md                       ← description 省略可
```

### `contains`（コード成果物）

ファイル先頭 32 行以内に `Document ID: {ID}` 行が含まれる。命名は自由。

```rust
// src/timeline.rs
//! Document ID: SRC-<AREA>-001
//! Timeline domain module
...
```

## 5. 親子関係の表現

3 パート ID は親情報を ID に埋め込まない。代わりに **本文 metadata** で親を明示する。

| 子 typecode | 親 metadata 表記 |
|---|---|
| QSET | `**親 SPEC**: SPEC-<AREA>-NNN`、`**反復回数**: <N>` |
| SPP | `**親 QSET**: QSET-<AREA>-NNN`、`**対象 SPEC**: SPEC-<AREA>-NNN` |
| FCR | `**対象 SPEC**: SPEC-<AREA>-NNN`、`**frontend_status**: ACCEPTED \| NEEDS_QUESTIONNAIRE` |
| TP | `**親 SPEC**: SPEC-<AREA>-NNN` または `**親 UC**: UC-<AREA>-NNN` |
| GAP | `**親 TP**: TP-<AREA>-NNN` |
| UC | `**親 SPEC**: SPEC-<AREA>-NNN`（chain 起点だが SPEC への参照を残す）|
| TS | `**親 DD**: DD-<AREA>-NNN`、`**継承 TP**: TP-<AREA>-NNN, ...` |
| AT | `**対象 UC**: UC-<AREA>-NNN`（または `**対象 SPEC**:`） |
| NFR | `**対象**: <ID 列挙 or "全 UC"> |
| ADR | `**対象 SPEC / DD**: <ID>` |
| RPC | `**対象 UC**: UC-<AREA>-NNN`、`**対象 RBA / SEQA / RBD / SEQD**: <ID 列挙>` |
| PAI | `**対象成果物**: <完成品名>`、`**対象契約 / SPEC**: <CTR-<AREA>-NNN, SPEC-<AREA>-NNN, ...>`、`**実施主体**: <Author と独立>` |

chain 内成果物（UC → RBA → SEQA → RBD → SEQD → DD → TS → TC → SRC）の親子関係は `chain.order` から legixy v3 が自動解決するので、本文に親 ID を書かなくても良い。ただし可読性のため書くことを推奨。

## 6. RED / GREEN ステータス（TP / GAP / FCR）

TP と GAP は本文 metadata の `**ステータス**:` 行で状態管理する。FCR は `**frontend_status**:` で前段検証結果を保持する。

| typecode | 値 | 意味 |
|---|---|---|
| TP | `red` | 仕様（親 SPEC / UC）が TP の問いに答えていない |
| TP | `green` | 仕様が修正され、TP の全観点に答えている |
| GAP | `open` | 改善を要する状態 |
| GAP | `closed (YYYY-MM-DD)` | 解消済み |
| GAP | `pending-event-confirmation` | 修正イベントの発火候補。開発者の確認を待っている (`10-modification-events.md` §9) |
| FCR | `ACCEPTED` | 親 SPEC が前段ループを通過。TP/UC 着手可能 |
| FCR | `NEEDS_QUESTIONNAIRE` | 親 SPEC に未解決の質問あり。次の QSET/SPP 反復が必要 |

これらのステータス集計は `scripts/trace-check.sh` が grep ベースで検査し、SPEC レベル TDD ゲートおよび前段ループゲートに反映する。書式が崩れると検査が誤判定するので、上記の `**ステータス**:` / `**frontend_status**:` 形式を厳守する。

**FCR の使い方**: SPEC に対して前段ループを 1 周回すたびに 1 つの FCR を発行する。同一 SPEC に対する複数の FCR が存在する場合、**ID 連番が最大のもの**が現在の status とみなされる（古い FCR は履歴として残す）。

**注記 - 修正イベント発火候補**: SCP で導入された修正イベントフロー (`10-modification-events.md`) において、Support 層からの不具合報告のような **外部トリガー** は、即座に `defect-fix` イベントを発火するのではなく、`GAP` の status を `pending-event-confirmation` として保留する。開発者の確認を経て status が `active` に変わると、`defect-fix` フローが本格起動する。この機構により、独立した FixProposal type code を導入せずに、Support 起点と DEV 起点を同一フレームで扱える。

## 7. graph.toml への登録

legixy v3 では全成果物を `docs/traceability/graph.toml` に `[[nodes]]` として登録する。

```toml
[[nodes]]
id = "SPEC-<AREA>-001"
type = "SPEC"
path = "docs/specs/SPEC-<AREA>-001_<description>.md"

[[nodes]]
id = "TP-<AREA>-001"
type = "TP"
path = "docs/test-perspectives/TP-<AREA>-001.md"

[[edges]]
from = "UC-<AREA>-001"
to = "RB-<AREA>-001"
kind = "chain"
```

- `[[nodes]]` の `type` フィールドは必須
- `[[edges]]` の `kind` は `chain` / `parent_child` / `custom` 等
- chain 内成果物の親子関係は `chain.order` から自動推測されるため、edges に書かなくてよい
- chain 外成果物の関連（TP → SPEC, GAP → TP, ADR → SPEC 等）は本文 metadata で管理

未登録ファイルは `OrphanFile` として `check` で INFO / WARNING 報告される。

## 8. 新規 typecode を追加するときの手順

ハードルール 4: **新しい成果物タイプは `.legixy.toml` 更新が先**。

1. `.legixy.toml` の `[id.types.<TYPE>]` セクションを追加（dir / ext / file_pattern を指定）
2. `[id.chain] order` または `independent` のどちらに入るかを判断し、追加
3. ID を 3 パート `{type}-<AREA>-NNN` 形式で命名
4. ファイル先頭に `Document ID:` 行を必置（`file_pattern = "contains"` のとき）または `prefix` 命名規則に従う
5. `docs/traceability/graph.toml` の `[[nodes]]` に登録
6. 新規 typecode 用のテンプレートを `templates/<TYPE>-template.md` に作成（推奨）
7. CLAUDE.md または本フォルダのドキュメントに簡潔に役割を追記
