# 付録: 適用例 — 作者プロダクト（`APP`）

このドキュメントは、本フレームワークの作者が自身のプロダクト開発で得た最も成熟した適用例を、匿名化した参照プロジェクト `APP`（コードベース `app-core`）として記述する。SCP はこの実プロダクト開発の中で育てられた。フレームワークを自プロジェクトに導入する際の具体例として参照する。

> **注意**: このドキュメントの内容は APP プロジェクト固有のもの。フレームワーク本体（`docs/SCP/00-philosophy.md` 〜 `08-gates.md`）から APP 固有要素を取り除いた後の **適用例の最終形** として読むこと。

## 1. プロジェクト概要

- **名称**: app-core
- **領域**: タイムライン編集 + 履歴管理 + プロジェクト管理を統合したデスクトップ・アプリケーションの core
- **採用言語**: Rust（決定論層）+ C# / WPF（非決定論層 / GUI）
- **境界**: FFI（C ABI）で core ↔ GUI を分離
- **エディション**: v1（Steam 版）/ v2（Enterprise 版）の単一コードベース、ポリシー切替

## 2. area の決定

- area = `APP`（サンプルアプリケーション）
- **単一 area** を採用。v1 / v2 の境界は area 分割ではなく **エディションポリシー**（SPEC-APP-006 §6.1）で表現
- 理由: 複数 area にすると ID 解析・graph.toml の管理が煩雑になり、ID redefine の検出が弱くなる

## 3. ディレクトリ構成

```
app-core/
├── Cargo.toml / Cargo.lock                # Rust workspace
├── .trace-engine.toml                     # area=APP, 13 typecode
├── CLAUDE.md                              # AI 向けハードルール
├── crates/                                # Rust workspace 配下
│   ├── app-domain/                        # 決定論層
│   ├── app-application/                   # ユースケース層
│   ├── app-infrastructure/                # 永続化・FFI
│   └── app-ffi/                           # C ABI 境界
├── docs/
│   ├── SCP/                           # 本フレームワーク（APP は源泉プロジェクト）
│   ├── DevelopmentProcess/                # 旧称・互換のため残置（SCPs.md）
│   ├── process/                           # 旧称・互換のため残置（01-08.md）
│   ├── specs/                             # SPEC-APP-001〜008
│   ├── usecases/                          # UC-APP-NNN
│   ├── test-perspectives/                 # TP-APP-NNN
│   ├── gap-analysis/                      # GAP-APP-NNN
│   ├── robustness/                        # RB-APP-NNN
│   ├── sequence/                          # SEQ-APP-NNN
│   ├── detailed-design/                   # DD-APP-NNN
│   ├── test-specs/                        # TS-APP-NNN
│   ├── acceptance-tests/                  # AT-APP-NNN
│   ├── nfr/                               # NFR-APP-NNN
│   ├── adr/                               # ADR-APP-001〜008
│   ├── idl/                               # IDL-APP-001（境界 API 凍結）
│   ├── validation/                        # VAL-APP-NNN
│   ├── traceability/                      # graph.toml, matrix.md
│   ├── perspectives/                      # core, ux 観点ナレッジベース
│   └── manual/legixy/     # ツールマニュアル
├── scripts/
│   └── trace-check.sh                     # 統合検証スクリプト
├── src/                                   # 旧 src/ 残置（crates/ に移行中）
├── tests/                                 # Cargo workspace 共通テスト
└── models/all-MiniLM-L6-v2/                # ONNX モデル（第 2 層 semantic 用）
```

## 4. 既存 SPEC 一覧（2026-04-30 時点）

| ID | タイトル | 概要 |
|---|---|---|
| SPEC-APP-001 | canonical-timeline | 史実タイムライン（正典）の概念 |
| SPEC-APP-002 | track | トラック / レーン構造 |
| SPEC-APP-003 | perspective-timeline | 視点タイムライン（正典の観点による解釈） |
| SPEC-APP-004 | history | 履歴管理・分岐・マージ |
| SPEC-APP-005 | responsibility | 史実 vs 視点の責任分担、人間 vs AI |
| SPEC-APP-006 | top-level | プロジェクト全体方針、エディションポリシー |
| SPEC-APP-007 | srs | システム要件仕様（area 単一体系） |
| SPEC-APP-008 | architecture-and-platform | アーキテクチャ全体、core ライフサイクル |

## 5. 採用した独立 typecode

SCP フレームワーク標準（SPEC / TP / GAP / ADR / AT / NFR / VAL）に加え、以下を追加:

| Typecode | 名称 | 役割 | 場所 |
|---|---|---|---|
| `IDL` | 境界 API 定義 | DD 凍結後の境界 API を独立成果物化 | `docs/idl/` |

理由: FFI 境界 API は core / GUI の両方からの参照対象として独立 ID を持つほうが影響範囲解析（`legixy impact IDL-APP-001`）が明示的。

## 6. ICONIX 設計層の特徴

### 決定論層 / 非決定論層の境界

APP は **FFI で明確に決定論層と非決定論層を分離している**:

- 決定論層（Rust）: タイムライン操作、視点解釈、履歴管理、検証エンジン
- 非決定論層（C# / WPF）: UI / 操作モデル、ローカライズ、設定 UI
- 境界（FFI / C ABI）: opaque handle + POD struct + FlatBuffers バルク

これにより:

- 決定論層は proptest / loom で property test / model checking が効く
- 非決定論層は AT で人間中心検証が効く
- 境界は IDL-APP-001 で凍結し、ABI バージョニング（ADR-APP-008）で互換性管理

### ADR の例

APP で起票された ADR:

- ADR-APP-001: panic-handling（FFI 境界での `catch_unwind` 必須）
- ADR-APP-002: complex-types-marshalling（A: opaque, B: POD struct, C: FlatBuffers）
- ADR-APP-003: c-abi-header-generation（cbindgen 使用）
- ADR-APP-004: csharp-binding-generation（手書き + 部分自動）
- ADR-APP-005: async-boundary（tokio + GCHandle ライフタイム）
- ADR-APP-006: input-validation-layering（段階 1 構文 / 段階 2 形式 / 段階 3 意味）
- ADR-APP-007: localization-keys（key + params 方式、`app.<category>.<entity>.<event>`）
- ADR-APP-008: abi-versioning（`vns_abi_version()` ハードチェック）

## 7. 観点ナレッジベースの育成例

`docs/perspectives/core-perspectives.md` には以下のような領域固有観点が蓄積されている:

- Timeline / Event 操作（空状態・全削除後・同時刻順序・因果整合性）
- Version control 系（Git 由来：分岐マージ結合則・履歴改変検出）
- 永続化（保存中の電源断・部分書き込み回復）
- FFI 境界（marshalling 4 方式・panic 処理・性能予算・ABI 互換）
- core ライフサイクル（init / shutdown / プロジェクト切替・シングルインスタンス）
- ローカライズ（key 命名・パラメータ型・フォールバック）

`docs/perspectives/ux-perspectives.md` には:

- DAW 由来（Track / Timeline / Region 操作）
- VC UI 由来（履歴ビュー・競合・ロック）
- VN / Presentation tool 由来（ビュー切替・複数視点）

## 8. 第 2 層 semantic の運用

APP では ONNX モデル（all-MiniLM-L6-v2）を `models/all-MiniLM-L6-v2/` に配置済み。`bash scripts/trace-check.sh` 実行時に第 2 層も自動実行される。

semantic check で drift が出た場合のフローは ADR で記録（例: ADR-APP-XXX gate-skip-drift-foo）。

## 9. 段階的導入の履歴

APP は当初 ICONIX + Traceability で運用されていたが、AI 時代の手戻り増を受けて以下の順で進化した:

1. **Phase 0 → 1**: SPEC レイヤーに TP / GAP を導入（SPEC-APP-001〜005）
2. **Phase 1 → 2**: UC レイヤーにも TP / GAP を展開、ICONIX チェーン（UC → ... → SRC）を本格運用
3. **Phase 2 → 3**: AT を独立 typecode として `.trace-engine.toml` に登録、リリース前ゲートに組み込み
4. **継続**: 観点ナレッジベース育成、ADR 蓄積、IDL（境界 API 凍結）の独立 typecode 化

各 Phase の効果指標として「TS 以降で発見される SPEC 起因のバグ件数」をモニタリングし、Phase 進行に伴って減少傾向を確認。

## 10. ファイル例（APP の実物への参照）

このフレームワークの実装例として、APP プロジェクト本体の以下を参照すると具体的:

| 種別 | パス | 説明 |
|---|---|---|
| プロセス本体（旧版）| `docs/DevelopmentProcess/SCPs.md` | フレームワーク化前の運用文書 |
| プロセス分割（旧版）| `docs/process/01-overview.md` 〜 `08-gates.md` | 同 |
| trace-engine 設定 | `.trace-engine.toml` | area=APP、13 typecode |
| 統合検証 | `scripts/trace-check.sh` | 第 1 層 + 第 2 層 + GAP/TP gate |
| 観点ベース | `docs/perspectives/{core,ux}-perspectives.md` | 領域固有観点を育成中 |
| AI 向け規律 | `CLAUDE.md` | プロジェクトルート |
| IDL 凍結例 | `docs/idl/IDL-APP-001_connection-api-frozen.md` | 境界 API 凍結 |
| ADR 例 | `docs/adr/ADR-APP-001_panic-handling.md` 等 | architectural decisions |

## 11. 自プロジェクトへの応用

この APP の構成を参考に、自プロジェクトへの応用ポイント:

- **境界 API があるなら IDL を独立 typecode 化**（APP の IDL 採用に倣う）
- **決定論層 / 非決定論層が分かれるなら、観点ベースを 2 系統用意**（APP の core / ux 分離）
- **ADR を architectural concerns ごとに小さく多数起票**（APP は ADR-APP-001〜008 と細粒度）
- **複数 area は避け、エディション・プロダクトはポリシーで表現**（APP の v1/v2 ポリシー切替）

## 12. このドキュメントとフレームワーク本体の関係

- `docs/SCP/` 配下の **00〜08 と templates / bootstrap / perspectives / guides** は **脱 APP 化された汎用版**
- 本ドキュメント（`appendix/app-example.md`）は APP 固有の **適用例**
- APP プロジェクト本体（`docs/DevelopmentProcess/SCPs.md`、`docs/process/`、`.trace-engine.toml` 等）は APP の現行運用文書

新規プロジェクトに SCP を導入する場合、フレームワーク本体（`00-philosophy.md` 以降）と本付録の **両方** を参考にすると、抽象規律と具体例を両方押さえられる。
