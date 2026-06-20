# 段階的導入ガイド

このドキュメントは、新規プロジェクトまたは既存プロジェクトに SCP を **段階的に** 導入する手順を示す。全層を一気に立ち上げる必要はない。

## 全体像

```
Phase 0  プロジェクト初期化（ツール設置・ディレクトリ作成）
   ↓
Phase 1  前段ループ運用 + SPEC レイヤー TP/GAP 運用
   ↓
Phase 2  UC レイヤーにも展開（フルフロー化）
   ↓
Phase 3  AT を独立 typecode として明示分離・リリース前ゲートに組み込み
   ↓
継続    観点ナレッジベースを育て続ける
```

**効果指標**: 「TS 以降で発見される仕様起因バグの件数」。Phase が進むごとに減れば、信頼境界の上流移動が機能している。

**前段ループはハードルール 9 として常時適用される**。Phase 1 から運用を開始する（既存プロジェクトに後付け導入する場合、移行期は ADR で前段スキップを記録することで段階的に切り替えていく）。詳細は `03a-frontend-pass.md` 参照。

---

## Phase 0: プロジェクト初期化

### Step 0-1: legixy v3 を入手

`~/.local/bin/legixy`（v0.4.0-alpha4 以降）を配置する。配布チャネルはプロジェクトに応じて決める（社内パッケージ・自前ビルド等）。

```bash
legixy --version
# v0.4.0-alpha4 以降であることを確認
```

### Step 0-2: ディレクトリツリーを作成

SCP フレームワーク本体（`docs/SCP/`）をコピーまたは git submodule として配置した上で:

```bash
bash docs/SCP/bootstrap/init-tree.sh
```

これで以下が作成される:

- `docs/{specs,usecases,test-perspectives,gap-analysis,robustness,sequence,detailed-design,test-specs,acceptance-tests,nfr,adr,validation,traceability,perspectives,decisions}/`
- `scripts/trace-check.sh`
- `docs/traceability/graph.toml`
- `.legixy.toml`
- `CLAUDE.md`
- `docs/perspectives/{core,ux}-perspectives.md`

### Step 0-3: プレースホルダを置換

```bash
# .legixy.toml の <YOUR-AREA> を自プロジェクト用 area に置換（例: APP, OPS, PAY, CMS）
# CLAUDE.md の <AREA> も同様に置換
# project.name を実プロジェクト名に置換
```

### Step 0-4: trace-check の動作確認

```bash
bash scripts/trace-check.sh
# まだ成果物が無いので空の集計が出るはず:
#   SPEC: 0, TP: green=0 red=0, GAP: closed=0 open=0, ADR: 0
# PASS が出ればセットアップ成功
```

### Step 0-5: 観点ナレッジベースの初期育成

`docs/perspectives/core-perspectives.md` と `ux-perspectives.md` の「領域固有観点」節を、自プロジェクトの領域に合わせて記述する。**この時点で完璧である必要はない**。Phase 1 / 2 で TP を書きながら、AT で発見しながら、継続的に育てる。

---

## Phase 1: SPEC レイヤー TP/GAP のみ運用

最初の Phase では UC 以降を従来どおり書きつつ、SPEC レベルの観点抽出だけを試す。最小コストで効果指標が取れる。

### 導入手順

1. **SPEC を書く**: `templates/SPEC-template.md` を参考に SPEC-<AREA>-001 を書く。Why と What の確定が目的。
2. **graph.toml に登録**:
   ```toml
   [[nodes]]
   id = "SPEC-<AREA>-001"
   type = "SPEC"
   path = "docs/specs/SPEC-<AREA>-001_<description>.md"
   ```
3. **TP[SPEC] を書く**: `templates/TP-template.md` を参考に。観点ナレッジベース（`docs/perspectives/`）を必ず参照する。
4. **GAP を起票**: TP の各観点について、SPEC が答えていない場合は `templates/GAP-template.md` から GAP を作る。
5. **SPEC を改訂**: GAP に対して SPEC を補強し、GAP を `closed` に更新。
6. **検証**: `bash scripts/trace-check.sh` が pass することを確認。

### Phase 1 のゴール

- 全 SPEC について TP[SPEC] が書かれている
- 全 GAP[SPEC] が closed
- `bash scripts/trace-check.sh` が pass
- AT を後で活用するための観点ベースが「最低限の領域固有観点」を備えている

### Phase 1 の検証指標

- TS 以降で発見される **SPEC 起因のバグ** の件数を計測しておく（Phase 2 / 3 と比較するため）
- TP 観点のうち、領域固有観点 / 汎用観点の比率（汎用に偏りすぎていないか）

### Phase 1 で典型的な落とし穴

- **TP がテストケースになっている**: 具体的な入力値を書いてしまう。TP は「観点」、TS は「具体化」。境界を意識する。
- **GAP がいつまでも close しない**: SPEC のスコープが広すぎる兆候。SPEC を分割する。
- **CLAUDE.md にハードルールを書いたのに無視される**: AI セッション開始時に CLAUDE.md を読み込ませる習慣をつける。

---

## Phase 2: UC レイヤーにも展開（フルフロー化）

SPEC レベルが安定したら、UC レベルでも TP / GAP を回す。ICONIX チェーン（UC → RBA → SEQA → RBD → SEQD → DD → TS → TC → SRC）も本格運用に入る。

### 導入手順

1. **UC を書く**: `templates/UC-template.md` を参考に。基本フロー / 代替フロー / 例外フローを揃える。
2. **TP[UC] を書く**: SPEC レベルとは異なる UC 固有観点（フロー網羅・アクター遷移・データフロー）を中心に。
3. **GAP[UC] を起票・close**: UC レベルの不完全性を検出。
4. **RB / SEQ / DD に進む**: UC が GREEN になったら ICONIX 設計層へ。
5. **TS を書く**: TP の翻訳として。ゼロから観点を考えない。
6. **TC[RED] → SRC → TC[GREEN]**: 実装ループに入る。
7. **検証**: `legixy check --formal` + `bash scripts/trace-check.sh` を毎フェーズ。

### Phase 2 のゴール

- 全 UC について TP[UC] が書かれている
- 全 GAP[UC] が closed
- `legixy check --formal` が pass（chain 整合性）
- TC[GREEN] と SRC が同期している
- ADR が architectural な判断ごとに起票されている

### Phase 2 の検証指標

- 仕様起因バグの件数が Phase 1 と比べて減っているか
- ゲートスキップ件数（`docs/decisions/gate-skips.md`）が累積していないか
- legixy の OrphanFile / IdRedefined warning がゼロに保たれているか

### Phase 2 で典型的な落とし穴

- **RB の通信制約違反を見逃す**: Boundary 同士の直接通信を放置すると、責任分離が崩れる。UC レベルに戻る規律を保つ。
- **TS がゼロから書かれる**: TP を翻訳せず、新たに観点を起こしてしまう。「TP のどの観点を翻訳したか」を TS に明示するルールで防ぐ。
- **DD で境界 API を凍結しない**: 凍結しないと SRC 段階で API 変更が常態化し、テストが追従できなくなる。

---

## Phase 3: AT を独立 typecode として明示分離

機能テストが GREEN になっただけで「リリース可」と判断する状態から、AT を独立検証チャネルとして導入する。

### 導入手順

1. **AT 仕様を起票**: マイルストーン到達時に `templates/AT-template.md` から AT-<AREA>-001 を作る。
2. **想定ユーザー観察を実施**: 実機で操作観察・インタビュー・ユーザビリティテスト。
3. **発見事項を GAP 化**: AT 失敗は SPEC または UC への GAP として記録（**最重要**）。
4. **新観点を perspectives.md に昇格**: AT で発見された観点を `docs/perspectives/<core|ux>-perspectives.md` に追記。
5. **リリースゲートに AT 通過を組み込む**: `08-gates.md` §11 のリリースゲート。
6. **AT 失敗放置を禁止**: 「リリース予定があるから」を理由に AT 失敗を放置しない。

### Phase 3 のゴール

- AT がリリース前ゲートとして機能している
- AT 由来の新観点が perspectives.md に蓄積している
- 過去の AT で発見された観点が、次バージョンの TP[SPEC] / TP[UC] で「自動的に」検出可能になっている

### Phase 3 の検証指標

- AT 由来の昇格観点の件数（蓄積していくはず）
- 同種の暗黙知問題が再発する頻度（減少していくはず）
- リリース後の暗黙知起因バグ報告件数

---

## 継続: 観点ナレッジベースを育てる

Phase 3 で完成ではない。**観点ナレッジベースは「育てる資産」**。

- AT で発見された観点を遅滞なく perspectives.md に統合
- 業界・領域の新しい慣行を観点として吸収
- 過去のインシデントを「再発防止のための観点」として記録
- ベンダ / 外部 API のクセを観点として記録（外部依存特性）

ナレッジベースが育つほど、新メンバ（人間 / AI）が同じ品質の TP を書けるようになる。これがプロセスの **複利効果**。

---

## 既存プロジェクトへの後付け

既存プロジェクトに SCP を導入する場合、Phase 0 からやるが、以下の調整が必要:

### 過去の SRC は触らない

既存 SRC を全て TC からトレース可能にしようとすると工数が爆発する。最初は **新規変更分のみ SCP に乗せる**。

### 既存の SPEC を再利用

既存の仕様書がある場合、SPEC として `docs/specs/` に取り込む。Document ID 行を追加し、graph.toml に登録するだけで形式上は SCP に乗る。本格的な仕様レベル TDD 化は次の SPEC 改訂のタイミングで行う。

### 既存テストの取り込み

既存テストは TC として再利用可能。TC ファイル先頭に `Document ID: TC-<AREA>-NNN` を追加し、関連 TS を後付けで起票する。

### CI への組み込み

`.github/workflows/trace.yml` 等で `bash scripts/trace-check.sh` を全 PR で実行する。最初は warning ベースで運用し、慣れてきたら fail ベースに切り替える。

---

## Phase 別チェックリスト要約

### Phase 0 完了条件
- [ ] legixy v3 が動作する
- [ ] `docs/SCP/` を取り込み済
- [ ] `bash scripts/trace-check.sh` が空状態で pass する
- [ ] CLAUDE.md と .legixy.toml の `<AREA>` 等が置換済

### Phase 1 完了条件
- [ ] 全 SPEC について TP[SPEC] が書かれている
- [ ] 全 GAP[SPEC] が closed
- [ ] perspectives.md に領域固有観点が記述されている

### Phase 2 完了条件
- [ ] 全 UC について TP[UC] が書かれている
- [ ] 全 GAP[UC] が closed
- [ ] ICONIX チェーンが pass（chain 整合性）
- [ ] TC[GREEN] と SRC が同期
- [ ] ADR が起票されている

### Phase 3 完了条件
- [ ] AT がリリース前ゲートとして組み込まれている
- [ ] AT 由来の新観点が perspectives.md に蓄積
- [ ] 暗黙知起因バグの再発が減少傾向
