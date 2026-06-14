# VERDICT マーカー仕様

このドキュメントは AI レビュアの判定結果を **機械可読な形** で記述するためのマーカー仕様を規定する。

## 1. なぜ機械可読マーカーが必要か

AI レビュアの判定が自然言語コメントとして散文に埋め込まれていると、以下の運用問題が起こる:

- パイプライン側で「Approve か Request_Changes か」を抽出できない
- 同一 PR 内で複数のレビュー指摘が出たとき総合判定が不明確
- 人間レビュアが大量の散文を読まないと結果が分からない

機械可読 VERDICT マーカーは、これらを 1 行で解決する。

```html
<!-- VERDICT:APPROVE -->
<!-- VERDICT:REQUEST_CHANGES -->
```

レビュア出力の **末尾** に必ず 1 つ書く。スクリプト側はこれを grep / 正規表現で読み取って、PR ステータスに反映する。

## 2. マーカーの基本形

```
<!-- VERDICT:<判定> -->
```

`<判定>` の取りうる値:

| 判定 | 意味 | アクション |
|---|---|---|
| `APPROVE` | 指摘なし、または Nit のみ。AI レビュアが Approve 権限を持つゲートでのみ有効 | スクリプトが `gh pr review --approve` または相当の操作 |
| `REQUEST_CHANGES` | Critical / Major / Minor のいずれかを含む。または判定不能 | スクリプトが `gh pr review --request-changes` または相当の操作 |
| `NEEDS_HUMAN` | AI Approve 権限のないゲート（SPEC, UC, ADR, NFR, リリース）で「人間判断必須」を明示 | スクリプトは人間レビュア通知のみ |

判定は **3 値**（APPROVE / REQUEST_CHANGES / NEEDS_HUMAN）。`COMMENT` のような第 4 値は採用しない。記事の運用と同じく、3 値以上にすると「コメントのみで宙ぶらりん」のアンチパターンが頻発するため。

## 3. 出力位置のルール

- レビュアの出力の **末尾** に必ず 1 つ
- 末尾以外に複数出現しないこと（複数出現時は最後のものを採用、ただし `[AI-Antipattern]` で警告）
- マーカーの後にはテキストを書かない

```markdown
（指摘内容...）

---
`<!-- VERDICT:REQUEST_CHANGES -->`
```

## 4. 判定欠落時の fail-safe

マーカーが欠落しているレビュア出力は、スクリプト側で自動的に `REQUEST_CHANGES` として扱う。

理由: 判定不能なまま PR が宙ぶらりんになるよりも、止める側に倒したほうが品質が守られる。「判定がぶれるなら fail-safe に振って止める側に倒す」の運用設計。

## 5. severity と VERDICT の対応表（再掲）

`severity.md` §5 と同じ:

| 指摘の構成 | VERDICT |
|---|---|
| Critical を 1 件以上含む | `REQUEST_CHANGES` |
| Major を 1 件以上含む | `REQUEST_CHANGES` |
| Minor のみ | `REQUEST_CHANGES`（resolve 必須）|
| Nit のみ、または指摘なし、かつ Approve 権限あり | `APPROVE` |
| Nit のみ、または指摘なし、かつ Approve 権限なし | `NEEDS_HUMAN` |
| 判定マーカー欠落 | `REQUEST_CHANGES`（fail-safe）|

## 6. 既存ステータスフィールドとの統合

SCP は既にいくつかの機械可読ステータスフィールドを持つ。VERDICT マーカーはこれを **置き換えるのではなく補完** する位置付け:

| 既存フィールド | 対応する成果物 | VERDICT との関係 |
|---|---|---|
| `frontend_status: ACCEPTED / NEEDS_QUESTIONNAIRE` | FCR | FCR 内に保持。VERDICT は FCR を発行する AI レビュア出力の末尾 |
| `ステータス: red / green` | TP | TP 内に保持。VERDICT は TP レビュー時の判定 |
| `ステータス: open / closed` | GAP | GAP 内に保持。VERDICT は GAP クローズ判定時の AI レビュア出力 |

つまり成果物本体のステータスは従来通り。VERDICT マーカーは **AI レビュアの出力末尾** に書く別物。

## 7. ゲート別の VERDICT 出力ルール

`08-gates.md` の各ゲートにおける AI レビュアの VERDICT 出力ルール:

### Raw SPEC → Accepted SPEC ゲート（前段ループ）

| 条件 | VERDICT |
|---|---|
| FCR.frontend_status が ACCEPTED で、AI レビュア指摘が Nit 以下 | `NEEDS_HUMAN`（SPEC 変更は人間承認必須） |
| QSET 未回答 / SPP 未承認 | `REQUEST_CHANGES` |
| 前段スキップ ADR の妥当性に Critical / Major 指摘あり | `REQUEST_CHANGES` |

### SPEC → UC ゲート

| 条件 | VERDICT |
|---|---|
| 全 GAP[SPEC] closed、red TP[SPEC] なし、AI レビュア指摘が Nit 以下 | `NEEDS_HUMAN`（TP 網羅性は人間判断）|
| open GAP / red TP が残っている | `REQUEST_CHANGES` |
| `[Coverage]` で Major 以上の網羅性不足 | `REQUEST_CHANGES` |

### UC → RBA ゲート

| 条件 | VERDICT |
|---|---|
| 全 GAP[UC] closed、AI レビュア指摘が Nit 以下 | `NEEDS_HUMAN`（UC のフロー妥当性は人間判断）|
| open GAP[UC] が残っている、または `[Coverage]` で TP[UC] 不足 | `REQUEST_CHANGES` |

### RBA → SEQA → RBD → SEQD → DD ゲート（ICONIX 二段化層）

| 条件 | VERDICT |
|---|---|
| `[Layer]` 違反なし、`[Consistency]` 三者整合性 OK、機械検証 pass | `APPROVE` または `NEEDS_HUMAN`（DD の API 凍結のみ人間必須）|
| `[Layer]` 違反あり | `REQUEST_CHANGES` |
| `[Consistency]` で三者整合性違反あり | `REQUEST_CHANGES`（Jacobson 流 / ICONIX 流のどちらの違反かを明示）|

### DD → TS ゲート

| 条件 | VERDICT |
|---|---|
| TS が TP の全観点を継承、`[Coverage]` で網羅性 OK | `APPROVE` |
| `[Coverage]` で観点漏れ、または TP→TS の翻訳が抜けている | `REQUEST_CHANGES` |

### TS → TC[RED] ゲート

| 条件 | VERDICT |
|---|---|
| コンパイル成功、ID 引用解決、assertion が具体的 | `APPROVE` |
| weak matcher（`objectContaining` で値検証緩め等）あり | `REQUEST_CHANGES` |

### TC[RED] → SRC ゲート

| 条件 | VERDICT |
|---|---|
| テスト失敗が「未実装」起因 | `APPROVE`（次フェーズへ）|
| その他理由の失敗 | `REQUEST_CHANGES` |

### SRC → TC[GREEN] ゲート

| 条件 | VERDICT |
|---|---|
| 全テスト pass、`[AI-Antipattern]` 違反なし、`[Doc]` 更新済 | `APPROVE` |
| `[AI-Antipattern]` で Critical / Major あり | `REQUEST_CHANGES` |
| `[Recurrence]` でバグ修正の再発防止カテゴリ未明記 | `REQUEST_CHANGES` |

### リリースゲート（AT 通過）

| 条件 | VERDICT |
|---|---|
| 全 AT pass、NFR pass | `NEEDS_HUMAN`（リリース判断は人間必須）|
| AT 失敗あり、または NFR 違反あり | `REQUEST_CHANGES` |

## 8. ローカル運用での VERDICT 消費（一人開発前提）

SCP は **開発者 1 人 + Claude Code** という同期的なローカル環境を主要シナリオとしている。クラウド CI ランナーや GitHub PR ワークフローは構造上不要なため、VERDICT の消費先もローカルに閉じる。

### VERDICT の消費経路

```
[Reviewer subagent 出力]
    末尾の <!-- VERDICT:XXX --> マーカー
        ↓
[Stop hook が抽出]
    .scp/verdict.log に append
        ↓
[開発者 / /advance slash command が読み取り]
    APPROVE         → 次フェーズ tag を打つかの判断
    REQUEST_CHANGES → Author に再指示
    NEEDS_HUMAN     → 開発者の commit / tag 操作必須
```

### NEEDS_HUMAN の読み替え

ローカル一人開発では「人間 Approve 必須」を **開発者の明示操作必須** と読み替える:

| クラウド前提 | ローカル前提 |
|---|---|
| 人間レビュアが PR を Approve | 開発者が `git tag v1-spec-accepted` を打つ |
| マージボタン押下 | 開発者が `git commit` または phase tag を確定 |
| 別のレビュアによる承認 | 開発者が `.scp/verdict.log` を読んで判断 |

つまり VERDICT の **3 値（APPROVE / REQUEST_CHANGES / NEEDS_HUMAN）の意味は変わらない**。変わるのは「承認の意思表示」が PR ボタン押下から git tag 操作に変わる点だけ。

### 自動マージ機構は採用しない

クラウド CI 前提では `APPROVE` で自動マージするオプションがあったが、ローカル一人開発では **採用しない**:

- `main` 直接 commit のため、マージ操作自体が不要
- 「次フェーズに進む」の意思決定は開発者が phase tag を打つ瞬間にしか発生しない
- 自動 tag 付与にすると「気づかないうちに進んでいた」事故が増える

phase tag の規律（`v<N>-spec-accepted`、`v<N>-uc-green`、`v<N>-iconix-green`、`v<N>-rc` 等）を開発者が手で打つことが、PR ボタンの代替として機能する。

### branch / PR の代替

| クラウド前提 | ローカル前提 |
|---|---|
| `feature/<name>` branch | 不要（`main` 直接 commit でよい） |
| PR 起票 | `/advance <stage>` slash command の実行 |
| diff スコープ | `git diff <前phase tag>..HEAD` |
| PR description | commit message footer に再発防止カテゴリ記載 |
| マージコミット | phase tag（`git tag v<N>-<stage>`）|
| PR API への VERDICT 反映 | `.scp/verdict.log` への append |

実験的に壊れる可能性がある変更だけ `phase/<stage>` branch を一時的に切る用途が残るが、これは PR ワークフローではなく単なるローカルバックアップ。

## 9. 集約スクリプトの例（ローカル運用）

`scripts/extract-verdict.sh` は Stop hook から呼び出されて VERDICT を `.scp/verdict.log` に追記する:

```bash
#!/bin/bash
# scripts/extract-verdict.sh
# Stop hook から呼ばれて、Reviewer subagent の最終出力から VERDICT を抽出する。
# 引数: $1 = Reviewer 出力ファイル（Stop hook が transcript path を渡す）

set -euo pipefail

OUTPUT_FILE="${1:-/dev/stdin}"
VERDICT_LOG=".scp/verdict.log"

mkdir -p "$(dirname "$VERDICT_LOG")"

# 末尾の VERDICT マーカーを取得（複数あれば最後を採用）
VERDICT=$(grep -oE "<!-- VERDICT:(APPROVE|REQUEST_CHANGES|NEEDS_HUMAN) -->" "$OUTPUT_FILE" | tail -1 || true)

if [ -z "$VERDICT" ]; then
  # fail-safe: 欠落は REQUEST_CHANGES として扱う
  VALUE="REQUEST_CHANGES"
  REASON="marker-missing"
else
  VALUE=$(echo "$VERDICT" | sed -E 's/<!-- VERDICT:(APPROVE|REQUEST_CHANGES|NEEDS_HUMAN) -->/\1/')
  REASON="explicit"
fi

# 形式: ISO8601 timestamp | git HEAD | VERDICT | reason
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HEAD=$(git rev-parse --short HEAD 2>/dev/null || echo "no-git")

echo "${TIMESTAMP} | ${HEAD} | ${VALUE} | ${REASON}" >> "$VERDICT_LOG"

# stderr に開発者向けに通知
echo ""
echo "═══ AI Reviewer VERDICT ═══"
echo "  ${VALUE}"
echo "  ログ: ${VERDICT_LOG}"
echo "═══════════════════════════"
echo ""

# REQUEST_CHANGES の場合は exit code 1（hook 側で次のアクションを分岐させる用途）
[ "$VALUE" = "REQUEST_CHANGES" ] && exit 1
exit 0
```

`/advance` slash command から呼ばれる際は、`.scp/verdict.log` の最新エントリを読んで次の動作を決める:

```bash
#!/bin/bash
# scripts/check-latest-verdict.sh
# /advance slash command から呼ばれる。最新 VERDICT を読み取って状態を返す。

VERDICT_LOG=".scp/verdict.log"

if [ ! -f "$VERDICT_LOG" ]; then
  echo "NO_VERDICT"
  exit 0
fi

LATEST=$(tail -1 "$VERDICT_LOG" | awk -F'|' '{print $3}' | tr -d ' ')
echo "$LATEST"
```

## 9.1 commit message footer の再発防止カテゴリ

PR description の代わりに、commit message の footer に再発防止カテゴリを記載する規律（バグ修正 commit のみ）:

```
fix: 在庫の負数チェック漏れを修正

`[Recurrence]` 観点で trace-check に grep 検出を追加。

Refs: GAP-INV-007
Recurrence: trace-check に追加
```

`Recurrence:` ヘッダ行があるかは pre-commit hook で grep 検査できる。記事の運用で言う「PR description への記入必須」と同じ機構を、commit message に移したもの。

## 10. 例: AI レビュア出力サンプル

ICONIX RBD レビューの例:

```markdown
## レビュー結果

### `[Layer]` Major: RBD-PROJ-003 にて言語固有型が混入

`RBD-PROJ-003_order-aggregate.md` §3 に `Result<OrderId, OrderError>` が出現しています。
これは言語固有ジェネリック型（ハードルール 10）で、抽象クラス図表記までに留めるべきです。

修正案:

\```
- 戻り型: Result<OrderId, OrderError>
+ 戻り型: 成功時 OrderId、失敗時 OrderError（具体的な戻り型表現は DD で確定）
\```

引用元: `severity.md` §1（Critical 例: ハードルール 10 違反）

### `[Consistency]` Minor: SEQA-PROJ-003 のレーン名

SEQA-PROJ-003 のレーン名「OrderService」が RBA-PROJ-003 では「注文管理」と表記されています。
ドメイン主語表現に揃えるべきです。

---

`<!-- VERDICT:REQUEST_CHANGES -->`
```

末尾の `<!-- VERDICT:REQUEST_CHANGES -->` が **Stop hook の `extract-verdict.sh`** で読み取られて `.scp/verdict.log` に追記され、開発者が `/advance` slash command や `tail .scp/verdict.log` で確認できる。

---

関連:

- 9 観点: `perspectives.md`
- severity 階層: `severity.md`
- ゲート別判定権限: `README.md` §「ゲート別の AI レビュア権限」
- CLAUDE.md テンプレ（Reviewer モード）: `../bootstrap/CLAUDE-reviewer.md.template`
