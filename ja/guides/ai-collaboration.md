# AI と人間の分担ガイド

このドキュメントは、本プロセスを AI と協働で運用するときの分担を整理する。

## 0. 第一目的との関係

本ガイドの分担はすべて `00-philosophy.md` の第一目的(品質偏向防止)から導かれる:

- 人間関与の集中は、最も重要な防御線(SPEC + UC + AT)に限られた人間認知資源を集中することで、防御線全体の効率を最大化する(00 §3.1 根拠 1, 2)
- 下流(RBA 以降)は AI 自律実行 + AI Reviewer 層 + AT の組み合わせで多重防御を構成する(00 §2.3, §2.4)
- 関与境界は **ハードルール 11** として規範化されている

## 1. 人間関与境界(ハードルール 11)

> **人間関与は SPEC と UC に限定する。** RBA 以降(SEQA, RBD, SEQD, DD, TS, TC, SRC)は AI 自律実行 + AI Reviewer 層 + AT の組み合わせで品質保証する。

### 1.1 人間が直接関与する作業

- SPEC 起草・改訂・最終承認
- QSET への回答
- SPP の承認 / 却下
- UC のフロー妥当性レビュー・最終承認
- TP[SPEC] / TP[UC] の観点漏れ確認
- GAP の重要度判断・close 判定
- AT 実施(被験者観察)
- NFR 閾値設定
- ADR 承認
- リリース判断
- 修正イベント(`/defect-fix`, `/spec-change`, `/spec-add`)の発火と承認
- 品質基準変更(`review-guidelines/`, `.legixy.toml`, ハードルール本文)の最終承認

### 1.2 人間が直接関与しない作業

- RBA, SEQA, RBD, SEQD, DD の生成
- TS, TC, SRC の生成
- 上記下流成果物の品質レビュー(AI Reviewer 層が代行)
- レイヤ汚染検査(機械検証で代行)
- 三者整合性検証の実施(AI Adversary が代行、判定結果のみ AT 段階で照合)

### 1.3 例外: 境界 API 凍結

ハードルール 7(境界 API は DD で凍結)の凍結判断は人間必須として残るが、運用は次のように行う:

1. AI が DD 確定時に「凍結対象 API リスト」を提示する
2. リストには各 API のシグネチャ・エラー型・冪等性保証・スレッド契約・バージョン互換性ポリシーを含む
3. 人間は DD 全文を読まず、API リストのみをレビューして一括承認する
4. 凍結後の変更は次バージョンの SPEC 改訂として扱う(`spec-change` イベント経由)

凍結対象 API は通常 1 つの UC につき数件であり、100 クレート規模で UC が 100 本あっても凍結対象 API の総数は数百件オーダーに収まる想定。これは現実的な人間レビュー範囲である。

### 1.4 関与境界が成立する前提条件

人間関与を SPEC + UC に絞ることが成立する前提:

- SPEC と UC が下流の AI 自律実行に十分な情報密度を持つこと
- AI Reviewer 層が機能していること(`08-gates.md` の VERDICT 機構、`review-guidelines/` の 9 観点)
- AT が独立検証チャネルとして実施されていること(`07-at-and-nfr.md`)
- `ai-antipattern.md` カタログが運用で育成されていること(human-on-the-loop)
- legixy による traceability が機能していること(`06-trace-engine.md`)

これらの前提が崩れている状態で関与境界を SPEC + UC に絞ると、下流品質が無防備になる。Phase E0(検証フェーズ)で前提条件の成立を経験的に確認する手順は `guides/adoption-phases.md` を参照。

## 2. AI ロールの分離: Author / Reviewer / Adversary

本プロセスでは AI を **3 つのロール** で運用する:

| ロール | 役割 | 起動時 CLAUDE.md |
|---|---|---|
| **Author** | 成果物の生成、実装、修正 | `bootstrap/CLAUDE.md.template` |
| **Reviewer** | 各ゲートで成果物を 9 観点 + severity + VERDICT で判定 | `bootstrap/CLAUDE-reviewer.md.template` |
| **Adversary** | 三者整合性検証、概念汚染検査、コントローラ責務検証(ICONIX 二段化層) | Reviewer の `[Consistency]` `[Layer]` 観点として統合運用 |

**1 セッションで複数ロールを兼務しない**。同一 AI が自分の生成物を自分でレビューすると判定の独立性が壊れる。Author と Reviewer は別セッション・別 CLAUDE.md で動かす。

Reviewer ロールの詳細は `review-guidelines/README.md` を参照。

### 2.1 同質モデル結託リスクの構造的位置付け

Author と Reviewer が同じモデル(Claude)である場合、訓練分布由来の盲点を共有する。これは prompt 工夫や CLAUDE.md 差し替えでは消えない構造的限界である。

ただしこのリスクは「AI Reviewer 層を改善すれば解消する」ものではなく、**レビュー機構一般の構造的限界**として位置付けられる(人間ペアレビューでも同質性を共有するレビュアー間で同じ現象が起きる)。

対抗手段は AI Reviewer 内部の改善(異モデル投入)ではなく、AI Reviewer 外部の独立検証経路の維持である:

- 機械検証層(`trace-check.sh`, `cargo test`, `clippy`)は AI と独立した決定論的判定
- AT(人間観察)は確率分布外側からの観察として AI と独立
- `ai-antipattern.md` カタログは AI Reviewer の見逃しパターンを事後蓄積

これらの組み合わせで AI Reviewer の構造的限界を補う。詳細は `00-philosophy.md` §2.3〜2.5、`review-guidelines/ai-antipattern.md` D-1, E-1, E-2。

異モデル Reviewer(Gemini, codex 等)の投入は Phase E0 以降で評価する選択肢として保持されるが、必須ではない。

## 3. 工程別の分担表

### 3.1 前段ループ(フロントエンド・パス)

| 作業 | AI 主体 | 人間主体 |
|---|---|---|
| 必要項目テンプレート仮充填(AI 内部) | ◯ | (なし、内部処理) |
| 不足・曖昧性・矛盾・境界不明・例外未定義の検出 | ◯ | (なし) |
| Adversary による異議申し立て | ◯ | (なし) |
| QSET 生成 | ◯ | (なし、ただし質問の妥当性は Adversary が監査) |
| **QSET への回答** | × | **必須**(推測で埋めない、ハードルール 1) |
| SPP 生成(差分案作成) | ◯ | レビュー |
| **SPP の承認 / 却下** | × | **必須**(ハードルール 1) |
| SPEC への差分反映 | ◯(承認後のみ) | 結果確認 |
| フロントエンド検証実行 | ◯(qa-runner) | (なし) |
| FCR 発行 | ◯(qa-runner) | 内容確認 |
| **反復続行 / 打ち切り判断** | × | **必須**(ハードルール 9 のスキップは ADR 化) |

### 3.2 仕様レベル TDD ループ

| 作業 | AI 主体 | 人間主体 |
|---|---|---|
| SPEC のドラフト作成 | ◯ | レビュー・ドメイン文脈確認 |
| **SPEC の確定** | × | **必須**(ハードルール 1) |
| TP[SPEC] の初稿生成 | ◯ | 観点漏れの確認 |
| 観点ナレッジベース参照 | ◯ | 領域固有観点の追加 |
| GAP[SPEC] の検出・起票 | ◯ | 重要度判断 |
| SPEC 改訂案の作成 | ◯(提案) | **承認・確定** |
| GAP のクローズ判定 | ◯(候補提示) | 確認 |
| TP の RED→GREEN 更新 | ◯ | レビュー |
| **UC のドラフト作成** | ◯ | **フロー妥当性レビュー(必須)** |
| **UC の確定** | × | **必須**(下流自律実行の前提となる) |
| TP[UC] の初稿生成 | ◯ | 観点漏れの確認 |
| GAP[UC] の起票・クローズ | ◯(候補) | 確定 |

UC は「人間関与境界の最終ノード」であり、UC が GREEN になった瞬間に下流の AI 自律実行が起動する。**UC の情報密度・例外フロー完全網羅・状態遷移明示・データ所有権遷移明示は、AI 自律実行の品質を直接決定する**。`03-spec-level-tdd.md` §6 の UC 固有観点に加えて、「AI 自律実行のための情報密度」観点を TP[UC] に組み込む(`perspectives/core-perspectives.md` 参照)。

### 3.3 ICONIX 設計層(下流自律実行領域)

ICONIX 設計層は **AI 自律実行領域** である。Toshifumi は直接関与しない。AI Author が生成し、AI Reviewer + Adversary が検証し、AT が下流逸脱を検出する。

| 作業 | AI 主体 | 人間主体 |
|---|---|---|
| RBA(抽象 RB)ドラフト | ◯(Author) | × |
| 1:1 Correspondence 検証(UC ⇄ RBA) | ◯(Adversary) | × |
| Object Discovery と概念汚染検査 | ◯(designer + Adversary) | **発見項目の SPEC/UC 反映承認のみ必須**(SPEC/UC 変更扱い) |
| UC Disambiguation 反復 | ◯(候補提示) | **GAP[UC] 起票と UC 修正承認のみ必須**(SPEC/UC 変更扱い) |
| SEQA(抽象 SEQ)ドラフト | ◯(Author) | × |
| UC text 並列配置 | ◯(Author) | × |
| コントローラ責務と操作の整合検証 | ◯(designer + Adversary) | × |
| Jacobson 流三者整合性検証(UC ⇄ RBA ⇄ SEQA) | ◯(Adversary) | × |
| ICONIX 流三者整合性検証(UC ⇄ RBA ⇄ SPEC) | ◯(Adversary) | × |
| 抽象 → 具体への一括 mapping(Adversary 検査付き) | ◯(designer + Adversary) | × |
| RBD(具体 RB)ドラフト | ◯(Author) | × |
| SEQD(具体 SEQ)ドラフト | ◯(Author) | × |
| レイヤ汚染検査(Adversary + grep 機械検証) | ◯ | × |
| **責務保存率検査(RPC)生成・判定**(v1.0) | ◯(Adversary) | **§9 分解 (b)(UC 不備の露呈)の場合のみ SPEC/UC 遡及承認** |
| DD ドラフト(implementer) | ◯(Author) | × |
| API surface の最小化 | ◯(提案) | × |
| エラー型の設計 | ◯(提案) | × |
| ADR 起票 | ◯(候補提示) | **内容承認のみ必須**(設計判断の記録) |
| **境界 API の凍結対象リスト承認** | ◯(リスト提示) | **必須**(ハードルール 7、§1.3 参照) |

「Object Discovery と概念汚染検査の SPEC/UC 反映」「UC Disambiguation 反復による UC 修正」は形式上は ICONIX 設計層内で発生するが、内容は SPEC/UC への遡及修正であるため、ハードルール 1 と 11 により人間承認必須である。これらは「下流から上流に戻る経路」であり、人間関与境界(SPEC + UC)に含まれる。

### 3.4 コードレベル TDD ループ(下流自律実行領域)

| 作業 | AI 主体 | 人間主体 |
|---|---|---|
| TS の初稿(TP からの翻訳) | ◯(Author) | × |
| TC[RED] の生成 | ◯(Author) | × |
| 「未実装」起因の RED 確認 | ◯(qa-runner) | × |
| SRC 本体の生成 | ◯(Author) | × |
| TC[GREEN] の確認 | ◯(qa-runner) | × |
| リファクタリング | ◯(Author) | × |
| `unsafe` / native interop | ◯(Author + Reviewer) | × |
| compiler warning / lint ゼロ化 | ◯(Author) | × |
| FFI / 境界 API のシグネチャ | ◯(Author + Reviewer) | ×(凍結リスト承認時に確認済) |

### 3.5 独立検証(分布外側からの観察)

AT は **確率分布外側からの観察**として位置付けられる(`00-philosophy.md` §2.4)。人間が SPEC + UC で関与を止める運用において、AT は下流品質の最終防衛線である。

| 作業 | AI 主体 | 人間主体 |
|---|---|---|
| AT のシナリオ起票(テンプレ埋め) | ◯ | 内容確定 |
| **AT の実施(被験者観察)** | × | **必須**(分布外側観察として代替不能) |
| AT 失敗の GAP 化 | ◯(候補提示) | 確定 |
| 新観点の perspectives.md 昇格 | ◯(提案) | 確定 |
| NFR の閾値設定 | × | **必須**(領域知識) |
| ベンチマーク実装 | ◯ | レビュー |
| loom / kani 等 formal verification 設定 | ◯ | レビュー |
| NFR 違反時の改善案 | ◯ | 採用判断・ADR 化 |
| セキュリティレビュー | △ | **必須**(人間 + 専門家) |

AT 失敗は単なる「機能バグ」ではなく、確率論的変換器が分布の左裾サンプルを出した可能性を示すシグナルである。AT 失敗時の対応は `07-at-and-nfr.md` §2 を参照。

### 3.6 ゲート判定

| ゲート | 機械検証(AI も実行可) | AI Reviewer 層 | 人間判断 |
|---|---|---|---|
| Raw SPEC → Accepted SPEC | `trace-check.sh` pass | NEEDS_HUMAN のみ(Approve 不可) | 必須 |
| SPEC → UC | `trace-check.sh` pass | NEEDS_HUMAN のみ(Approve 不可) | 必須 |
| UC → RBA | `trace-check.sh` pass | NEEDS_HUMAN のみ(Approve 不可) | 必須 |
| RBA → SEQA(抽象層 GREEN) | `legixy check --formal` | NEEDS_HUMAN のみ(Adversary 検証範囲) | × (SPEC/UC 変更が発生した場合のみ承認) |
| SEQA → RBD | `legixy check --formal` + レイヤ汚染検査 | APPROVE 可 | × |
| RBD → SEQD | 同上 | APPROVE 可 | × |
| RPC（抽象→具体 責務保存、v1.0）| `legixy check --formal` + RPC presence + VERDICT | APPROVE 可 | ×（§9 分解 (b) の UC 不備露呈時のみ SPEC/UC 遡及承認）|
| SEQD → DD | `legixy check`(semantic) | APPROVE 可(API 凍結のみ凍結リスト承認必須) | API 凍結リスト一括承認 |
| DD → TS | `legixy check`(semantic) | APPROVE 可 | × |
| TS → TC[RED] | コンパイル成功 + ID 引用解決 | APPROVE 可 | × |
| TC[RED] → SRC | 「未実装」起因の失敗確認 | APPROVE 可 | × |
| SRC → TC[GREEN] | 全テスト pass + `trace-check.sh` pass | APPROVE 可 | × |
| リリース(AT 通過) | 全 NFR pass + AT 通過 | NEEDS_HUMAN のみ(Approve 不可) | 必須(AT 結果評価、新観点昇格) |

人間関与必須ゲート(NEEDS_HUMAN のみ)はすべて SPEC, UC, AT に関わる境界に集中している。RBA → SRC の構造翻訳・実装段階は人間関与なしで進行する。

## 4. AI セッション開始時の儀式

新規 AI セッションを開始するたびに、以下を AI に明示する:

1. **CLAUDE.md を読ませる**: ハードルールと検証コマンドが頭に入る
2. **対象範囲を限定**: 「SPEC-<AREA>-NNN の TP を書いてほしい」のように、上流 ID を明示
3. **参照ナレッジベースを指示**: `docs/perspectives/core-perspectives.md` を読み込ませる
4. **アウトプット規律を明示**: テンプレートを使う、Document ID 行を入れる、graph.toml に登録する
5. **ロール明示**: Author / Reviewer / Adversary のどのロールで動くかを宣言

良い指示の例(Author):

> SPEC-<AREA>-008 を読んで、その TP を書いてほしい。`docs/SCP/templates/TP-template.md` のフォーマットに従って、`docs/perspectives/core-perspectives.md` の汎用観点と領域固有観点を両方カバーすること。観点が SPEC に答えられているかを判定し、答えていないものについては GAP を起票(ステータス: open)して `docs/gap-analysis/` に置く。`docs/traceability/graph.toml` の登録も忘れずに。

良い指示の例(下流自律実行):

> UC-<AREA>-005 が GREEN になった。`/advance uc-to-rba` を実行する前提で、RBA → SEQA → RBD → SEQD → DD → TS → TC[RED] → SRC → TC[GREEN] の chain を Author セッションで進めてほしい。各段階で Reviewer subagent を spawn し、APPROVE が出たら次に進む。NEEDS_HUMAN または REQUEST_CHANGES が出たら停止して報告する。`/spec-change` / `/defect-fix` 起動が必要なら判断材料を提示する。

悪い指示の例:

> SPEC を読んで TP を書いて。

## 5. AI が「埋め合わせ」始めたら止める(`ai-antipattern.md` A 系)

AI が SPEC / UC の曖昧さに対して、勝手に「合理的な解釈」を提示して下流を生成し始めたら止める。これは旧プロセスの破綻の主因であり、確率論的変換器の入力分布が広がる典型パターン(`00-philosophy.md` §2.1)。

兆候:

- AI が「ここは XX という前提で進めます」と言う(前提の確認なしに進めようとする)
- AI が「SPEC に明示はないが恐らく…」と言う
- AI が GAP を起票せずに RBA を描き始める

対処:

> その箇所は SPEC が答えていないので、推測で進めず GAP として起票してください。私が判断します。

下流自律実行領域では、AI Reviewer の `[AI-Antipattern]` 観点(A-1, A-2)がこれを検出する。検出された場合 REQUEST_CHANGES が返り、Author に GAP[UC] / GAP[SPEC] 起票が要求される。

## 6. AI が見落としがちなこと(下流自律実行領域での Reviewer チェックリスト)

実運用で AI が落としがちなチェックリスト。Reviewer は以下を逐次確認する:

- [ ] graph.toml への登録漏れ
- [ ] Document ID 行の付け忘れ
- [ ] 親 ID 引用の漏れ(特に独立成果物を作るとき)
- [ ] TP[UC] と TP[SPEC] の混同(観点カテゴリが違う)
- [ ] GAP の影響範囲セクションが空
- [ ] AT 失敗を「軽微なバグ」として SRC で直そうとする(GAP[UC] 化が正しい)
- [ ] NFR を SPEC の中に書く(NFR は独立 typecode)
- [ ] ADR を起票しない設計判断(後で誰も理由が分からなくなる)
- [ ] レイヤ汚染(RBD/SEQD に Rust 識別子が混入)
- [ ] API surface に意図しない関数追加(DD 凍結対象外の関数を pub にする)
- [ ] dead code 残置
- [ ] 不要な後方互換コード
- [ ] 幻覚 API(存在しない依存メソッドの呼び出し)
- [ ] エラー握り潰し / フォールバック濫用

Reviewer subagent の起動時にこのチェックリストが反映される。

## 7. 多 AI 運用(現運用は Claude 主体だが将来拡張)

将来、複数の AI モデル(Claude, Gemini, codex)を並行運用する場合の整理:

### 7.1 同時編集の衝突回避

- 1 SPEC につき 1 セッション原則(同時に 2 つの AI が同じ SPEC を編集しない)
- TP / GAP は新規追加が中心なのでセッション間衝突は少ない
- merge 時は graph.toml の重複チェックが重要(`legixy check --formal` が IdRedefined を検出)

### 7.2 異モデル Reviewer の導入

同質モデル結託リスクの構造的限界(§2.1)に対して、異モデル Reviewer を投入する選択肢。Phase E0 以降で評価する:

- **Phase E0**: Adversary 役のみ Gemini または codex に切り替え、Claude Reviewer との判定差分を観察
- **Phase E1**: 上流ゲート(SPEC → UC、UC → RBA、抽象層 GREEN 確定)のみ Claude + 異モデルの二重 Reviewer
- **Phase E2**: SRC → TC[GREEN] ゲートに異モデル Reviewer を加える

ただし異モデル投入は AI Reviewer 内部の改善であり、`00-philosophy.md` §2.3〜2.5 の多重独立検証経路の代替にはならない。AT、機械検証層、`ai-antipattern.md` カタログ育成は異モデル投入の有無に関わらず維持する。

### 7.3 知識の引き継ぎ

- 各セッションの最後に、生成・改訂した成果物の ID 一覧を残す
- 次セッションは前セッションの ID 一覧から再開
- CLAUDE.md は静的な知識、セッション履歴は動的な知識として分ける

## 8. AI の限界と人間の最終責任

AI は以下を **保証しない**:

- 業界規制・法令遵守(医療・金融・個人情報保護)
- 倫理的判断
- ステークホルダー間の合意形成
- 実機操作の自然さ(→ AT で人間が確認)
- パフォーマンス目標値の妥当性(→ NFR で人間が設定)
- セキュリティ要件の網羅性(→ 専門家レビュー)

これらは **人間の最終責任**。AI が「問題ない」と言っても、人間が確認する責任は残る。これらが SPEC + UC + AT の人間関与境界に含まれる理由でもある。

## 9. AI レビュアロールの運用詳細

### 9.1 起動方法

各ゲートの判定時、`bootstrap/CLAUDE-reviewer.md.template` を `CLAUDE.md` として配置して AI を起動する。Author セッション(実装中)とは別プロセスとして動かす。

### 9.2 9 観点の順次チェック

1. `[Trace]` → `[Frontend]` → `[Spec-TDD]` → `[Layer]` → `[Consistency]` → `[Coverage]` → `[Doc]` → `[AI-Antipattern]` → `[Recurrence]`
2. **1 セッション内で順次**実行。並列 sub-agent ではない(前の観点の findings を後段が参照できるよう設計)
3. 観点ごとに severity(Critical / Major / Minor / Nit)を付与
4. 末尾に `<!-- VERDICT:APPROVE -->` / `<!-- VERDICT:REQUEST_CHANGES -->` / `<!-- VERDICT:NEEDS_HUMAN -->` を 1 つだけ出力

### 9.3 Adversary 役との統合

ICONIX 二段化層の **Adversary 役** は、AI レビュア層の `[Consistency]` `[Layer]` 観点として再整理される。具体的には:

- 既存の Jacobson 流三者整合性検証 → `[Consistency]` の一部
- 既存の ICONIX 流三者整合性検証 → `[Consistency]` の一部
- 既存のレイヤ汚染検査 → `[Layer]`

Adversary 役で運用している箇所はそのまま AI レビュア層に組み込まれ、追加の運用負荷はない。

### 9.4 降格禁止と品質基準保護

AI レビュアは指摘を出した後、自分で降格してはいけない(`review-guidelines/severity.md` §2)。また、**品質基準そのものを緩める PR**(ハードルール変更、`.legixy.toml` chain 順変更、`scripts/trace-check.sh` のチェック削除など)は AI Approve 不可。人間 Approve 必須領域として `REQUEST_CHANGES` または `NEEDS_HUMAN` を返す。

これは AI 同士(Author AI と Reviewer AI)が結託して品質基準を下げることを防ぐ **メタレベル安全弁**。

### 9.5 ガイドラインを育てる(human-on-the-loop)

AI レビュアが同じ種類のミスを繰り返すパターンが見えてきたら、**個別 PR で上書きするのではなく** `review-guidelines/` 配下のガイドラインを書き換える。書き換え判断は人間レビュアの責務。

これにより:

- 個別 PR レビューはほぼ全て AI に任せられる
- 人間は「AI が間違える瞬間を捕まえてルール側を直す」役回りに集中
- ガイドラインが「最初に完璧に書く」のではなく「AI の運用で見えた失敗を吸収しながら育つ」生きたドキュメントになる

これが human-in-the-loop ではなく **human-on-the-loop** の運用形態。`00-philosophy.md` §2.5 の偏向パターン事後蓄積機構の運用面でもある。

### 9.6 Reviewer ロールが SPEC / UC / リリースを Approve できない理由

ハードルール 1(SPEC 変更は人間承認必須)と ハードルール 11(人間関与は SPEC と UC に限定)に加えて、AI レビュアと AI 作者が同じ AI ベースのため、両者が結託する形で SPEC を自律確定したり、品質基準そのものを緩めるリスクがある(`ai-antipattern.md` D-1, E-1, E-2)。これを防ぐため、以下では AI Approve 権限を渡さない:

- 前段ループ(Raw SPEC → Accepted SPEC)
- SPEC, UC の確定
- ADR, NFR の確定
- ICONIX 抽象層(RBA, SEQA)の GREEN 確定(三者整合性検証 = Adversary の専門領域)
- リリースゲート(AT 通過判定)
- `review-guidelines/` / `bootstrap/CLAUDE*.md.template` / `.legixy.toml` 等の品質基準変更

これらの領域で AI レビュアが返せるのは `REQUEST_CHANGES` または `NEEDS_HUMAN` のみ。`APPROVE` は人間レビュアの責務。

## 10. 修正イベント発火時の分担

`10-modification-events.md` で規定される修正イベント(`/defect-fix`, `/spec-change`, `/spec-add`)発火時の分担:

| イベント | 起動 | 内容 | 人間関与 |
|---|---|---|---|
| `/defect-fix` | 人間 or AT | 不具合の検出と上流追跡 | Step 5 原因選別、Step 6 ドキュメント修正承認(SPEC/UC 変更が含まれる場合) |
| `/spec-change` | 人間 | 既存 SPEC/UC の意図的変更 | Step 4 影響範囲レビュー、Step 5 人間承認(ハードルール 1) |
| `/spec-add` | 人間 | 既存システムに新規 SPEC 追加 | Step 5 人間承認、前段ループ全工程 |

修正イベント発火の判断自体が人間関与境界に含まれる(ハードルール 11)。AI Reviewer が REQUEST_CHANGES を返したとき、それが `/defect-fix` 起動条件に該当するかは人間が判断する。

3 サイクル超過警告発動時の継続判断も人間関与必須(`10-modification-events.md` §6)。

---

関連:

- ハードルール一覧(特にハードルール 11): `README.md`
- 第一目的(品質偏向防止): `00-philosophy.md` §1
- 人間関与境界の構造的根拠: `00-philosophy.md` §3
- ゲート別の判断基準: `08-gates.md`
- AI への指示テンプレ(Author): `bootstrap/CLAUDE.md.template`
- AI への指示テンプレ(Reviewer): `bootstrap/CLAUDE-reviewer.md.template`
- AI レビュア層の運用規律: `review-guidelines/README.md`
- 9 観点の詳細: `review-guidelines/perspectives.md`
- severity 階層と降格禁止: `review-guidelines/severity.md`
- AI 特有の罠カタログ: `review-guidelines/ai-antipattern.md`
- VERDICT マーカー仕様: `review-guidelines/verdict-marker.md`
- 修正イベントフロー: `10-modification-events.md`
