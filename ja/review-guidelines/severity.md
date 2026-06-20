# severity 階層と降格禁止ルール

このドキュメントは AI レビュアが指摘を出すときの **重要度分類** と **降格禁止ルール** を規定する。

## 1. severity 4 段階

| severity | 基準 | アクション |
|---|---|---|
| **Critical** | ハードルール違反、信頼境界の崩壊、品質基準の緩和、データ破壊リスク | `REQUEST_CHANGES`。人間 Approve 必須領域は二重ゲート |
| **Major** | チェーン不整合、レイヤ汚染、TP/GAP のクローズ漏れ、API surface 拡大 | `REQUEST_CHANGES` |
| **Minor** | 命名改善、保守性、軽微な refactor、metadata 漏れ | `REQUEST_CHANGES`（resolve 必須） |
| **Nit** | スタイル好み、表記揺れ | `APPROVE`（コメントのみ）|

### Critical の具体例

- ハードルール 1 違反: AI が SPEC を勝手に確定している
- ハードルール 2 違反: open GAP が残ったまま次フェーズに進んでいる
- ハードルール 6 違反: 実装着手後に仕様書 / テストコードを書き換えている
- ハードルール 9 違反: FCR が ACCEPTED でない SPEC に対して TP[SPEC] / UC が起票されている
- ハードルール 10 違反: 抽象側に言語固有要素が混入、または三者整合性検証未実施
- **品質基準そのものを緩める変更**: `.legixy.toml` の chain 順変更、ハードルールスキップ条件の緩和、`scripts/trace-check.sh` のチェック削除、perspectives.md からの観点削除
- 「**埋め合わせ**」進行: 上流 GAP を起票せずに下流成果物を生成
- ドキュメント不整合: コード変更に対する DD / SPEC / perspectives 更新漏れ

### Major の具体例

- chain 内成果物の親子関係が `[id.chain] order` に反する
- 抽象側 RBA/SEQA にクラス名・属性表記が混入（具体側要素の混入）
- 具体側 RBD/SEQD に関数名（`snake_case()` 呼び出し）・型表記（`Result<T,E>`）が混入
- TP に対応する GAP が起票されていない RED 観点
- API surface に意図しない関数が増えている
- ADR を起票していない architectural decision

### Minor の具体例

- Document ID 行の漏れ
- graph.toml への登録忘れ
- 親 ID 引用の表記揺れ（`SPEC-AREA-001` vs `SPEC-AREA-1`）
- 命名の改善余地

### Nit の具体例

- 章節タイトルの表記揺れ
- インデントや空行の好み

## 2. 降格禁止ルール（最重要）

AI レビュアが指摘を出した後、自分で降格させることを禁じる。降格は人間レビュアの判断領域。

### 禁止される降格理由

以下を理由とした降格は **すべて Critical 違反** として扱う:

1. **「既存パターンに従った追加」**

   既存コードがガイドラインに違反している場合、それに従った新規コードも **同じ重要度で指摘する**。既存違反は別途修正対象であって、新規追加を許す根拠にならない。

   例: 既存 RBD に `Result<T,E>` が混入している場合でも、新規 RBD への混入は Major のまま指摘する。

2. **「別 PR で対応」「次のセッションで対応」「スコープ外」「段階的に」**

   Critical / Major を Nit に降格して先送りすることを禁じる。GAP として上流に戻すか、現 PR で解消するかの 2 択。

3. **「TODO/FIXME 残置で先送り」**

   コード内に `TODO: 後で修正` を残して降格する運用を禁じる。GAP として記録するなら GAP テンプレに、ADR として記録するなら ADR テンプレに、と必ず正規の成果物として残す。

4. **「実装の都合に合わせて基準を緩める」**

   レイヤ汚染を Major で指摘した後、「言語仕様上避けられないので Nit に降格」を禁じる。避けられないなら DD に移すか、ADR で例外として記録する。

5. **「AI 生成の手戻りを避けるため」**

   AI が大量に生成したコードを書き直すコストを理由とした降格を禁じる。書き直しコストはハーネスを広げるべきサインであり、品質基準を下げる根拠にしない。

### 降格禁止ルールが効く理由

降格を許すと、AI レビュアは「指摘を出したが結局 Nit にした」という運用が蓄積し、APPROVE が量産される。結果としてレビューの実効性が失われる。

「**典型的な逃げ方を先回りで全部潰す**」のがこのルールの設計思想。新しい逃げ方が見つかったら、その都度ここに追記する（human-on-the-loop）。

## 3. 品質基準緩和の Critical 化（メタレベル安全弁）

AI レビュアと AI 作者が同じ AI ベースで動くため、両者が結託して **品質基準そのものを下げる** リスクがある。これに対する安全弁:

### 自動 APPROVE を渡さない領域

以下の変更を含む PR は、AI レビュアは **必ず REQUEST_CHANGES を返す**。人間レビュアの Approve を必須化する:

- `docs/SCP/` 配下の規定文書（00-philosophy.md, 01-overview.md, 08-gates.md など）の変更
- `bootstrap/CLAUDE.md.template`, `CLAUDE-reviewer.md.template` の変更
- `review-guidelines/` 配下の変更
- `.legixy.toml` の `[id.chain]` セクション変更
- `scripts/trace-check.sh` のチェック削除・条件緩和
- `docs/perspectives/` 配下の観点削除（追加は OK）
- ハードルール本体の文言変更
- ハードルール 9 スキップ ADR の連続発行（過去 N 件で警告）

### 緩和の正当化として認めない理由

- 「既存実装がすでに違反しているので基準側を実装に合わせる」
- 「現実的な運用負荷を考慮して」
- 「AI が間違えやすいので閾値を下げる」

これらの理由は、緩和ではなく **ハーネスの改善** で対処すべき問題。基準を下げて運用を維持するのは旧プロセスの破綻パターン。

## 4. ハードルールの severity マッピング（参照表）

`README.md` のハードルール 10 個を severity に対応付ける:

| # | ハードルール | severity | 検出 |
|---|---|---|---|
| 1 | SPEC の変更は人間承認が必要 | **Critical** | AI が SPEC を自律確定した形跡を `[AI-Antipattern]` で検出 |
| 2 | GAP がクローズしないうちに次フェーズへ進まない | **Critical** | `trace-check.sh` のゲート、`[Spec-TDD]` で再検査 |
| 3 | すべての成果物は親への参照を持つ | **Major** | `legixy check --formal`、`[Trace]` |
| 4 | 新しい成果物タイプは `.legixy.toml` 更新が先 | **Major** | `[Trace]` |
| 5 | AT は終端ではなく独立した検証チャネル | **Critical**（混同時）| `[Recurrence]` |
| 6 | 仕様書とテストコードは実装着手後に変更しない | **Critical** | `[AI-Antipattern]` |
| 7 | 境界 API の契約は DD 段階で凍結する | **Critical** | `[Doc]`、API surface diff |
| 8 | テストが通らない実装はマージしない | **Critical** | CI |
| 9 | SPEC は前段ループで ACCEPTED 必須 | **Critical** | `[Frontend]`、`trace-check.sh` |
| 10 | ICONIX 二段化レイヤ汚染禁止 + 三者整合性検証必須 | **Critical**（汚染）/ **Major**（整合性未実施）| `[Layer]`, `[Consistency]` |

## 5. severity と VERDICT の対応

AI レビュアが最終判定を出すルール:

| 指摘の構成 | VERDICT |
|---|---|
| Critical を 1 件以上含む | `REQUEST_CHANGES` |
| Major を 1 件以上含む | `REQUEST_CHANGES` |
| Minor のみ | `REQUEST_CHANGES`（resolve 必須）|
| Nit のみ、または指摘なし | `APPROVE`（権限のあるゲートのみ）|
| 判定マーカー欠落 | `REQUEST_CHANGES`（fail-safe）|

「**判定がぶれるなら fail-safe に振って止める側に倒す**」のが基本設計。3 択にして `COMMENT` を含めると、PR が宙ぶらりんになる運用パターンが頻発するため採用しない。

VERDICT マーカーの記法は `verdict-marker.md` を参照。

## 6. severity / scope / 観点の表形式統一

ガイドライン内の各チェック項目は、以下の表形式で記述する。判定の再現性を上げるため:

| severity | scope | 観点 |
|---|---|---|
| Critical | 全成果物 | ハードルール 1（SPEC の AI 自律確定）|
| Critical | 全成果物 | ハードルール 9（FCR ACCEPTED 未満で TP[SPEC] 着手）|
| Major | RBD / SEQD | レイヤ汚染（関数呼び出し表記）|
| Minor | 全成果物 | Document ID 行の漏れ |
| Nit | 全成果物 | 章節タイトルの表記揺れ |

scope 列は **そのチェックがどのパスに適用されるか** を機械判定するためのもの。AI レビュアは scope に該当しない成果物では該当項目を発火させない。

## 7. severity の運用と育成

新しいパターンが見つかったら、このドキュメントに追記する:

- どの観点で違反が見つかったか
- なぜ Critical / Major / Minor / Nit に分類するか
- 降格禁止の典型理由になりうるか

ガイドラインは静的な文書ではなく、AI が間違える瞬間を吸収しながら育つ生きたドキュメント。

---

関連:

- 9 観点: `perspectives.md`
- AI 特有の罠: `ai-antipattern.md`
- VERDICT マーカー: `verdict-marker.md`
- ハードルール本体: `../README.md`
