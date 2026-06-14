# AI レビュアガイドライン

このディレクトリは、SCP における **AI レビュア層** の運用規律を規定する。

## このディレクトリの存在理由

SCP のゲート判定は従来 `機械検証 + 人間判断` の 2 層で構成されていた。AI コーディング時代に下流生成が高速化すると、人間判断がボトルネックになる。記事[^cortex]が指摘する「**書く速度が上がっても、見る側が人間のままだとレビューが詰まる**」現象は本プロセスにも当てはまる。

本ディレクトリは、機械検証と人間判断の **間** に **AI レビュア層** を挟む運用を規定する:

```
機械検証（trace-check.sh）
    ↓
AI レビュア層（9 観点 + severity + VERDICT マーカー）
    ↓
人間判断（最終 Approve、Critical 領域）
```

AI レビュアは個別 PR に対する逐次判定を担い、人間は **AI が間違える瞬間を捕まえてガイドライン側を直す** human-on-the-loop の役回りに移る。

[^cortex]: 辻 亮佑「AIが書いたコードはAIが見る ── レビューが詰まらず、品質はむしろ上がる」(Zenn, 2026-05-26) <https://zenn.dev/aircloset/articles/91824e55b7fc9c>

## 構成

```
review-guidelines/
├── README.md                # 本ファイル（入口）
├── severity.md              # severity 階層 + 降格禁止ルール
├── perspectives.md          # 9 観点（タグ）の定義
├── ai-antipattern.md        # AI 特有の罠の分類
└── verdict-marker.md        # VERDICT マーカー仕様
```

## 4 つの構成要素

| 要素 | 役割 | 参照先 |
|---|---|---|
| **9 観点** | AI レビュアが順次チェックする観点 | `perspectives.md` |
| **severity 階層** | 指摘の重要度分類（Critical / Major / Minor / Nit）| `severity.md` |
| **降格禁止ルール** | AI が「既存もそうだから」と緩めることを禁じる | `severity.md` |
| **VERDICT マーカー** | 機械可読な最終判定（APPROVE / REQUEST_CHANGES）| `verdict-marker.md` |

## AI レビュアの運用フロー

```
[成果物が完成 or PR が起票される]
    ↓
[1] 機械検証: bash scripts/trace-check.sh
    ↓ pass
[2] AI レビュア起動（--mode reviewer）
    ↓ 9 観点を 1 セッションで順次チェック
    ↓ 各指摘に severity を付与
    ↓ 末尾に <!-- VERDICT:APPROVE --> または <!-- VERDICT:REQUEST_CHANGES -->
    ↓
[3] VERDICT が REQUEST_CHANGES なら作成者が修正 → 再レビュー
    VERDICT が APPROVE なら次へ
    ↓
[4] 人間判断（ゲートにより必須/任意）
    ↓ Approve
[次フェーズへ]
```

### 並列 sub-agent ではなく、1 セッション順次レビュー

9 観点を別々の sub-agent で並列実行する案は採用しない。理由:

- 同じコンテキスト（trace graph、SPEC、ガイドライン）を 9 回重複注入することになり、token コストが膨らむ
- 観点間で findings を相互参照できない（例: `[Coverage]` の指摘が `[Spec-TDD]` の GAP 不在と関連していても、別 sub-agent だと見えない）
- 集約ロジックが複雑になる

1 セッション順次にすると、コンテキスト読み込みは 1 回で済み、前の観点の findings を保ったまま次に進めるので **観点間の整合性も自然に拾える**。出力も 1 ストリームで、末尾の VERDICT マーカー 1 つで集約完了。

### Author / Reviewer モードの分離

AI 起動時に CLAUDE.md を差し替える:

- **Author モード**: `bootstrap/CLAUDE.md.template` — 生成手順・ハードルール・出力規律
- **Reviewer モード**: `bootstrap/CLAUDE-reviewer.md.template` — 9 観点・severity・VERDICT 仕様

これは作業目的にコンテキストを集中させる工夫で、判定精度と token コストの両方を改善する。

### Adversary 役との関係

SCP は既に **Adversary 役**（`04-iconix-layer.md` §11、`guides/ai-collaboration.md` §2）を ICONIX 三者整合性検証で運用している。AI レビュア層は Adversary 役を **全ゲートに一般化** した位置付け。三者整合性検証は `[Consistency]` 観点の専門化版として整理する。

## ゲート別の AI レビュア権限

すべてのゲートで AI レビュア観点を実行できるが、**APPROVE 権限**はゲートにより異なる:

| 領域 | APPROVE 権限 | 根拠 |
|---|---|---|
| 上流（SPEC, UC, ADR, NFR）| **REQUEST_CHANGES のみ**。Approve は人間必須 | ハードルール 1（SPEC 変更は人間承認）、品質基準緩和禁止 |
| ICONIX 抽象層（RBA, SEQA） | REQUEST_CHANGES のみ。Approve は人間（三者整合性検証として既存運用）| ハードルール 10、`04-iconix-layer.md` §11 |
| ICONIX 具体層（RBD, SEQD, DD）| AI Approve 可（ただし API 凍結は人間必須）| 構造翻訳が原理的に情報を加えないため |
| コードレベル（TS, TC, SRC）| AI Approve 可 | 記事の運用と同型 |
| AT 通過（リリース）| **REQUEST_CHANGES のみ**。Approve は人間必須 | 暗黙知・ドメイン慣行が領域 |

「AI Approve 可」のゲートでも、**品質基準を緩める変更を含む PR は必ず REQUEST_CHANGES に倒す**（`severity.md` 参照）。

## ガイドラインを育てる（human-on-the-loop）

AI レビュアが定期的に同じ種類のミスをするパターンが見えてきたら、**個別 PR にコメントして上書きするのではなく、ガイドラインを書き換えて次回以降の AI に正しく振る舞わせる**。これが human-on-the-loop の実態。

ガイドライン書き換えの典型例:

| AI が間違える瞬間 | ガイドラインの直し方 |
|---|---|
| 「既存も同じだから」で降格 | `severity.md` の降格禁止ルールに追記 |
| 判定が PR ごとにぶれる | `perspectives.md` の各観点に severity / scope 列を追加 |
| AI 特有の罠を拾えない | `ai-antipattern.md` に新カテゴリ追加 |
| AI がハードルール緩和を提案してくる | `severity.md` に「品質基準緩和」を Critical 固定 |

`perspectives.md` への昇格は、本フレームワークが既に AT 経由で運用している仕組み（`07-at-and-nfr.md`）を AI レビュア由来の失敗にも拡張する。

## 段階的導入

既存プロジェクトに後付けする場合の推奨順序:

1. **Phase A**: `severity.md` + `verdict-marker.md` を導入。AI レビュアを起動せず、ハードルール違反を Critical に固定するだけ
2. **Phase B**: `perspectives.md` を導入。ICONIX 三者整合性検証を `[Consistency]` 観点として再整理
3. **Phase C**: `CLAUDE-reviewer.md.template` を導入。実際に AI レビュアを各ゲートで起動
4. **Phase D**: REQUEST_CHANGES が連続したら、`ai-antipattern.md` に新パターンを追記する運用を回す（human-on-the-loop の本格運用）

`guides/adoption-phases.md` の Phase 4 / Phase 5 として位置付けることもできる。

### ローカル運用の有効化（Phase C と並行）

`bootstrap/.claude/` 配下のテンプレを `.claude/` にコピーすると、Claude Code が以下を自動で扱える:

| ファイル | 役割 |
|---|---|
| `.claude/settings.json` | hooks 定義（PreToolUse で品質基準ファイル保護、SubagentStop で VERDICT 抽出）|
| `.claude/commands/advance.md` | `/advance <stage>` slash command で明示的ゲート起動 |
| `.claude/agents/reviewer.md` | Reviewer subagent 定義（9 観点 + VERDICT 出力） |
| `.git/hooks/pre-commit` | commit 時に `trace-check.sh` を deterministic に強制 |
| `.scp/verdict.log` | VERDICT の append log（PR API の代替）|

詳細は `../08-gates.md` §17、`verdict-marker.md` §8〜9。

---

関連:

- ゲート判定: `../08-gates.md`
- AI と人間の分担: `../guides/ai-collaboration.md`
- 観点ナレッジベース（汎用観点）: `../perspectives/core-perspectives.md`
- CLAUDE.md テンプレ（Author / Reviewer）: `../bootstrap/CLAUDE.md.template`, `../bootstrap/CLAUDE-reviewer.md.template`
