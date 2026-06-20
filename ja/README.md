# SPEC Compiling Pipeline (SCP) v1.0 — 品質偏向防止を第一目的とする AI コンパイラ運用フレームワーク

> **確率論的変換器(AI)を SPEC, UC からのソフトウェアコンパイラとして採用する開発プロセスは、品質最大化ではなく品質偏向防止を第一目的とすべきである。**
>
> 本フレームワークは **ICONIX 二段化 + SDD + TDD + Traceability(legixy) + 仕様レベル TDD + 前段ループ + 修正イベントフロー + 9 観点 AI レビュア層 + AT 独立検証** を、品質偏向防止という統一原理の下に多重独立検証経路として統合する。

このフォルダ配下のドキュメントは、特定プロジェクトに依存しない汎用的な記述で書かれている。具体的な適用例（作者プロダクトを匿名化した参照プロジェクト `APP`）は `appendix/` 配下にまとめてある。

## 何を解決するか

**確率論的変換器をコンパイラとして使うとき、品質保証は「最大化」ではなく「偏向防止」の問題になる。**

伝統的コンパイラ(GCC, Clang)は確定論的変換器(同じ入力からは常に同じ出力)であり、品質保証は最大化問題として定式化できた。AI(LLM)は確率論的変換器であり、同じ入力に対しても確率分布 P(y|x) からのサンプリングを返すため、品質保証の本質が異なる:

- 実装で使われるのは分布からの単一サンプル
- そのサンプルが分布の左裾(悪い領域)から出る可能性を防ぐ必要がある
- LLM の訓練分布バイアスにより、複数サンプルが特定方向に偏向蓄積する

本プロセスはこの構造的問題に対して、AI の内部チューニング(プロンプト、fine-tuning、RAG)ではなく、**AI の外側の構造設計**(多重独立検証経路、確率分布外側からの観察、偏向パターンの事後蓄積)で対抗する。

詳細は `00-philosophy.md` を参照。

## 構成

```
docs/SCP/
├── README.md                   # 本ファイル（入口）
├── TESTBED-USAGE.md            # テストベッドとしての運用ガイド・観察ログ手順
├── 00-philosophy.md            # 品質偏向防止を第一目的とする設計原理
├── 01-overview.md              # 全体像・4 層構造・観察可能化
├── 02-typecodes.md             # 成果物タイプコード一覧・ID 規則
├── 03a-frontend-pass.md        # 前段ループ（Raw SPEC → Accepted SPEC の正規化）= 入力分布の狭隘化(00 §2.1)
├── 03-spec-level-tdd.md        # SPEC ⇄ TP ⇄ GAP / UC ⇄ TP ⇄ GAP ループ = 出力偏向の検出可能化(00 §2.2)
├── 04-iconix-layer.md          # ICONIX 二段化: RBA → SEQA → RBD → SEQD → DD = 多重独立検証経路(00 §2.3)
├── 05-test-and-impl.md         # TS → TC[RED] → SRC → TC[GREEN]
├── 06-trace-engine.md          # legixy v3 の運用
├── 07-at-and-nfr.md            # AT（受け入れテスト）と NFR(非機能要件)= 確率分布外側からの観察(00 §2.4)
├── 08-gates.md                 # フェーズ進行ゲート（機械検証 + AI レビュア層 + 人間判断の 3 層構造）
├── 09-compiler-lens.md         # コンパイラ構造レンズ（伝統的/インクリメンタル・コンパイラと対応付ける視点）
├── 10-modification-events.md   # 修正イベントフロー（仕様変更/不具合修正/仕様追加/新規作成 の 4 イベント、共通中核、インクリメンタル再構築、3 サイクル警告）
├── 11-responsibility-preservation-check.md  # 抽象責務→具体責務 保存率検査(RPC)= 構造翻訳の不変条件強制(v1.0, 00 §2.2/§2.3)
├── 12-delivery-layer.md         # 配送層(契約サーフェス=CLI/API/MCP)をチェーン定置。CTR(境界契約・根)/DLV/multi-area/契約適合ゲート(v1.0, 機能軸と直交する配送軸)
├── 13-product-acceptance-inspection.md  # 完成品適合検査(PAI)= 作者と独立な黒箱・実環境での完成品契約適合検査(v1.0, 00 §2.4。TC[DLV]=回帰 / PAI=発見)
│
├── templates/                  # 各成果物の Markdown テンプレート
│   ├── SPEC-template.md
│   ├── QSET-template.md        # 前段ループ: 質問票
│   ├── SPP-template.md         # 前段ループ: SPEC 差分案
│   ├── FCR-template.md         # 前段ループ: 検証結果
│   ├── UC-template.md
│   ├── TP-template.md
│   ├── GAP-template.md
│   ├── RBA-template.md         # ICONIX 抽象層: ドメインレベル ロバストネス図
│   ├── SEQA-template.md        # ICONIX 抽象層: ドメイン主語の交互作用
│   ├── RBD-template.md         # ICONIX 具体層: クラス図レベル(言語非依存)
│   ├── SEQD-template.md        # ICONIX 具体層: クラス間メッセージング(言語非依存)
│   ├── RB-template.md          # DEPRECATED (RBA/RBD に分離)
│   ├── SEQ-template.md         # DEPRECATED (SEQA/SEQD に分離)
│   ├── DD-template.md
│   ├── TS-template.md
│   ├── TC-template.md
│   ├── SRC-template.md
│   ├── AT-template.md
│   ├── NFR-template.md
│   ├── ADR-template.md
│   ├── VAL-template.md
│   ├── RPC-template.md         # 抽象責務→具体責務 保存率検査(v1.0)
│   ├── CTR-template.md         # 配送軸: 境界契約(根)(v1.0)
│   ├── DLV-template.md         # 配送軸: 配送設計(v1.0)
│   └── PAI-template.md         # 完成品適合検査(独立・黒箱・実環境)(v1.0)
│
├── review-guidelines/         # AI レビュア層の運用規律
│   ├── README.md               # 入口（9 観点 + severity + VERDICT の全体像）
│   ├── severity.md             # severity 階層 + 降格禁止ルール
│   ├── perspectives.md         # 9 観点（タグ）の定義
│   ├── ai-antipattern.md       # AI 特有の罠のカタログ
│   └── verdict-marker.md       # VERDICT マーカー仕様
│
├── bootstrap/                  # 新規プロジェクト初期化キット
│   ├── legixy.toml.template
│   ├── graph.toml.template
│   ├── trace-check.sh          # 前段ループゲート含む統合検証
│   ├── init-tree.sh            # docs/ 配下のディレクトリと placeholder を作る
│   ├── CLAUDE.md.template      # Author モード: 生成・実装作業向け
│   ├── CLAUDE-reviewer.md.template  # Reviewer モード: AI レビュア専用
│   ├── scripts/                # ローカル運用スクリプト群（08-gates.md §17）
│   │   ├── extract-verdict.sh         # Stop hook から VERDICT を抽出
│   │   ├── check-latest-verdict.sh    # /advance から最新 VERDICT 読み取り
│   │   ├── guard-quality-baseline.sh  # PreToolUse hook で品質基準ファイル保護
│   │   ├── check-pending-verdict.sh   # Stop hook で未解決 VERDICT 警告
│   │   └── count-fix-cycle.sh         # 修正イベント 3 サイクル超過警告
│   ├── .claude/                # Claude Code hooks / commands / subagents
│   │   ├── settings.json.template     # hooks 定義
│   │   ├── commands/
│   │   │   ├── advance.md.template            # /advance slash command
│   │   │   ├── defect-fix.md.template         # /defect-fix (不具合修正イベント)
│   │   │   ├── spec-change.md.template        # /spec-change (仕様変更イベント)
│   │   │   └── spec-add.md.template           # /spec-add (仕様追加イベント)
│   │   └── agents/
│   │       └── reviewer.md.template   # Reviewer subagent 定義
│   └── .git-hooks/
│       └── pre-commit.template        # trace-check.sh の deterministic 起動
│
├── perspectives/               # 観点ナレッジベースの汎用テンプレ
│   ├── core-perspectives.md    # 決定論層（型・状態・並行性・永続化…）
│   └── ux-perspectives.md      # 非決定論層（入力・可視化・Undo・操作モデル…）
│
├── guides/
│   ├── adoption-phases.md      # 既存プロジェクトへの段階的導入
│   ├── ai-collaboration.md     # AI と人間の分担詳細
│   └── language-stacks/        # 言語別 DD / TC / SRC ガイド
│       ├── rust.md
│       ├── typescript.md
│       ├── python.md
│       └── csharp.md
│
├── appendix/
│   └── app-example.md          # 作者プロダクト（匿名化 `APP`）への適用例
│
└── manual/
    └── legixy/
        └── manual.md           # legixy v3 公式マニュアル（コピー）
```

## はじめての導入手順（要約）

新規プロジェクトに本プロセスを導入する手順は以下。詳細は `guides/adoption-phases.md` を参照。

1. **ツール設置**: `legixy` v3（v0.4.0-alpha4 以降）を `~/.local/bin/` 等に配置。なお `legixy` は SCP の開発時に `traceability-engine` として実装されたツールを改称・再構築したもので、現行配布の実バイナリ名は `traceability-engine` の場合がある（同一の実体。詳細は `06-trace-engine.md`）。
2. **ディレクトリ初期化**: `bootstrap/init-tree.sh` を実行 or 手動で `docs/{specs,frontend-pass/questionnaires,frontend-pass/check-results,spec-patches,usecases,test-perspectives,gap-analysis,robustness,sequence,detailed-design,test-specs,acceptance-tests,nfr,adr,validation,responsibility-preservation,product-acceptance,contracts,delivery-design,traceability,perspectives}/` を作成。
3. **設定ファイル配置**:
   - `.legixy.toml` ← `bootstrap/legixy.toml.template`（`area` を自プロジェクト 3 文字に置換）
   - `docs/traceability/graph.toml` ← `bootstrap/graph.toml.template`
   - `scripts/trace-check.sh` ← `bootstrap/trace-check.sh`
   - `CLAUDE.md`（プロジェクトルート）← `bootstrap/CLAUDE.md.template`
4. **観点ベース配置**: `docs/perspectives/core-perspectives.md`, `ux-perspectives.md` ← `perspectives/*.md` をコピーして領域固有観点を追記。
5. **段階的導入**: Phase 1（前段ループ + SPEC レイヤー TP/GAP）から開始 → Phase 2（UC レイヤー追加）→ Phase 3（AT 独立分離）。`guides/adoption-phases.md` 参照。

## ハードルール（常時適用、AI も人間も従う）

1. **SPEC の変更は人間承認が必要。** AI は提案する、人間が決定する。
2. **GAP がクローズしないうちに次フェーズへ進まない。** GAP[SPEC] open のうちは UC 着手禁止。GAP[UC] open のうちは RBA 着手禁止。`bash scripts/trace-check.sh` がこれを機械検証する。
3. **すべての成果物は親への参照を持つ。** chain 内成果物は legixy v3 の `check --formal` で、chain 外成果物は本文 metadata + `scripts/trace-check.sh` で検証する。
4. **新しい成果物タイプは `.legixy.toml` 更新が先。** チェーンに無いタイプを勝手に作らない。
5. **AT は終端ではなく独立した検証チャネル。** 仕様レベル TDD で原理的に検出不能な領域（暗黙知・ドメイン慣行・前提の不一致）専用。確率分布外側からの観察として位置付けられる(`00-philosophy.md` §2.4)。
5b. **完成品の契約適合は、作者と独立な黒箱検査 PAI で検証する。** 機能 GREEN（TC[DLV] 含む）は契約適合を意味しない（実証: 全チェーン GREEN でも契約違反 54 件）。リリース前に Author と独立な主体が完成品を実環境で黒箱検査する(`13-product-acceptance-inspection.md`)。AT（UX）と PAI（契約/機能）は別チャネルで相互に代替しない。
6. **仕様書とテストコードは実装着手後に変更しない。** 実装がテストに合わせる。ただし不具合修正イベント(`/defect-fix`)・仕様変更イベント(`/spec-change`)を経由する上流ドキュメント修正は本ルールの対象外(`10-modification-events.md` §4.1.2)。
7. **境界 API の契約は DD 段階で凍結する。** 凍結後の変更は次バージョンの SPEC 改訂として扱う。
8. **テストが通らない実装はマージしない。**
9. **SPEC は前段ループで FCR.frontend_status = ACCEPTED に到達していなければ TP[SPEC] / UC 着手禁止。** Raw SPEC を直接 TP/UC に流すのは旧プロセスの破綻パターンで、SPEC の不完備を下流が埋め合わせる原因となる。`bash scripts/trace-check.sh` がこれを機械検証する。スキップする場合は ADR で記録（詳細は `03a-frontend-pass.md` §11）。確率論的変換器の入力分布狭隘化(`00-philosophy.md` §2.1)。
10. **ICONIX 二段化レイヤ汚染禁止 + 三者整合性検証必須。** 抽象側 RBA/SEQA にはドメイン語彙のみ、具体側 RBD/SEQD には操作名(人間の言語)とクラス図表記まで。関数名(snake_case/camelCase 呼び出し)・引数具体型・戻り型・修飾子(`pub`, `async`)・crate/module 識別子(`tokio::`, `std::`)・言語固有ジェネリック型(`Result<T,E>`, `Vec<T>`, `Arc<Mutex<T>>`)は DD でのみ書く。`bash scripts/trace-check.sh` の [5/5] レイヤ汚染検査が grep ベースで違反を検出する。加えて抽象層 GREEN 確定には **Jacobson 流三者整合性(UC ⇄ RBA ⇄ SEQA)** と **ICONIX 流三者整合性(UC ⇄ RBA ⇄ SPEC)** の両検証が必要。詳細は `04-iconix-layer.md`。多重独立検証経路の構造保持(`00-philosophy.md` §2.3)。
11. **人間関与は SPEC と UC に限定する。** RBA 以降(SEQA, RBD, SEQD, DD, TS, TC, SRC)は AI 自律実行 + AI Reviewer 層 + AT の組み合わせで品質保証する。人間の限られた認知資源を最も重要な防御線(入力品質向上と分布外側からの観察基準)に集中することで、防御線全体の効率が最大化される。例外として境界 API の凍結判断(ハードルール 7)は人間必須として残るが、AI が凍結対象 API リストを提示して人間が一括承認する形で運用する。関与境界の構造的根拠は `00-philosophy.md` §3、操作的定義は `guides/ai-collaboration.md` §1 を参照。

ハードルール 1〜10 は本フレームワークの基盤であり、品質偏向防止の枠組み(`00-philosophy.md` §1)の下に位置付けられている。ハードルール 11 は人間関与を SPEC と UC に集中させる規律を加える。

## レンズ文書

通常の 00〜08 + 03a はプロセスを **規定する** ドキュメントだが、`09-compiler-lens.md` はプロセスを **別の語彙で記述する** レンズ仕様書(`LENS-SCP-COMPILER-002`)。実装手順を変更せず、設計判断の参照領域を切り替えるための視点を提供する。具体的には:

- 前段ループ(SPEC 不完備の正規化機構)をフロントエンド・パスとして整理
- SCP の段階構造を伝統的コンパイラの IR 階層と対応付け
- 日常運用がインクリメンタル・コンパイラ(Salsa / Rust Incremental / Roslyn 系)に構造的に対応することを明示
- 冪等性を「フル再生成の冪等性」と「グラフ操作の冪等性」に分離して再定義

レンズ文書は「紹介」を目的とし、理解の強要は行わない。プロセスの規定 (00〜08, 03a) とは独立に読める。

## 修正イベントフロー

SCP で導入されたイベント駆動の修正フローは、既存連鎖への変更を 4 つのイベントとして分類して扱う:

| イベント | slash command | 説明 |
|---|---|---|
| **新規作成** | (通常の chain) | プロジェクト初期 / 独立した新規連鎖 |
| **仕様追加** | `/spec-add` | 既存システムに新 SPEC を追加 |
| **仕様変更** | `/spec-change` | 既存 SPEC / UC の意図的変更 |
| **不具合修正** | `/defect-fix` | 不具合検出から原因分析・修正・再構築まで |

これらは V-DRS-ARCH-001 §6 の DEV / Support 共通フローを **origin-agnostic に統一** したもの。Support 層が実装される将来も同フローがそのまま稼働する。詳細は `10-modification-events.md`。

主要な機能:

- **共通中核操作**: `investigate` → `impact` → 成果物参照 → 修正候補生成
- **インクリメンタル再構築**: 修正されたドキュメントから下流を選択的に再生成 (`09-compiler-lens.md` のレンズを literal に運用)
- **3 サイクル超過警告**: 修正フローが収束しない場合に設計レベルの見直しを促す
- **イベントログ**: `.scp/event-log.txt` に発火履歴を append

**修正イベントフローの未検証性**: イベントフローは思考実験を経て構築された仕様であり、運用検証されていない。Phase E1 〜 E5 の段階的有効化により、実運用での妥当性を順次確認する (`10-modification-events.md` §10、§11)。

## AI レビュア層

各ゲートは従来 `機械検証 + 人間判断` の 2 層で構成されていたが、両者の間に **AI レビュア層** を挟む 3 層構成に拡張されている:

```
機械検証（trace-check.sh）→ AI レビュア層（9 観点 + severity + VERDICT）→ 人間判断
```

AI レビュア層は **9 観点を 1 セッションで順次チェック**し、severity 階層と降格禁止ルールに従って指摘を出し、末尾に機械可読な VERDICT マーカーで判定を出力する。これにより人間レビュアは個別 PR の逐次判定から降りて、AI が間違えるパターンを捕まえてガイドラインを直す **human-on-the-loop** の役回りに移る。

ただし **SPEC 変更・リリース判断・品質基準緩和** は AI Approve 不可で、人間判断必須領域として維持される（ハードルール 1 / メタレベル安全弁）。詳細は `review-guidelines/README.md`、各ゲート別のルールは `08-gates.md`。

### ローカル一人開発前提

SCP は **開発者 1 人 + Claude Code** という同期的なローカル環境を主要シナリオとする。クラウド CI ランナーや GitHub PR ワークフローは構造上不要で、AI レビュアは Claude Code の **subagent / hook / slash command** で起動される:

- `/advance <stage>` slash command で明示的にゲート判定を要求
- Author subagent 完了時に `SubagentStop` hook で自動 Reviewer 起動
- `.git/hooks/pre-commit` で機械検証を deterministic に強制
- VERDICT は `.scp/verdict.log` に append、phase tag が PR ボタンの代替

詳細は `08-gates.md` §17、テンプレは `bootstrap/.claude/` 配下。

## 想定読者

- **SCP をテストベッドとして運用する人**（→ `TESTBED-USAGE.md`）
- このプロセスを **新規プロジェクトに導入する人**（→ `guides/adoption-phases.md`）
- 各フェーズで **成果物を作成・レビューする人**（→ 03a, 03〜07）
- **AI に作業を委ねる人**（→ `guides/ai-collaboration.md` および `bootstrap/CLAUDE.md.template`）
- **AI レビュアを起動・運用する人**（→ `review-guidelines/README.md` および `bootstrap/CLAUDE-reviewer.md.template`）
- **CI / ゲートを設計する人**（→ 08, 06）

## 用語

| 略称 | 名称 | 意味 |
|---|---|---|
| SPEC | Specification | プロジェクトの Why と What |
| QSET | Questionnaire Set | 前段ループ: AI が発行する質問票 |
| SPP  | SPEC Patch Proposal | 前段ループ: QSET 回答を反映した SPEC 差分案 |
| FCR  | Frontend Check Result | 前段ループ: フロントエンド検証結果（`frontend_status` を保持） |
| UC   | Use Case | アクター視点の振る舞い記述 |
| TP   | Test Perspective | 仕様検証用の観点リスト（テストケースではない） |
| GAP  | Gap Analysis | TP を仕様にぶつけて検出した欠落の記録 |
| RB   | Robustness Diagram | Boundary / Control / Entity の構造整合性 |
| SEQ  | Sequence Diagram | UC の時系列展開 |
| DD   | Detailed Design | 実装言語構造への mapping |
| TS   | Test Specification | TP を実行可能形式に翻訳した仕様 |
| TC   | Test Code | TS を機械実行可能なテストに変換 |
| SRC  | Source Code | TC を通す最小実装 |
| AT   | Acceptance Test | 暗黙知・ドメイン慣行・前提不一致の検証 |
| NFR  | Non-Functional Requirement | 性能・並行性・リソース・セキュリティ |
| ADR  | Architecture Decision Record | 設計判断の根拠記録 |
| VAL  | Validation | プロジェクト全体に対する横断的検証 |
| RPC  | Responsibility Preservation Check | 抽象責務(RBA/SEQA)→ 具体責務(RBD/SEQD)の保存性検査(v1.0) |

## このフレームワークが採用する哲学

> **確率論的変換器を構造材として採用するソフトウェア開発プロセスは、品質最大化ではなく品質偏向防止を第一目的とすべきである。**

下位原理として、以下が品質偏向防止の枠組みの中で位置付けられる:

- **信頼境界の上流移動**: 確率論的変換器の入力 x の品質を高めて分布 P(y|x) を狭める
- **観察可能化**: 確率論的変換器の出力 y の偏向を観点ぶつけで検出可能化する
- **多重独立検証経路**: 各方法論の盲点を別の方法論が構造的にカバーする
- **確率分布外側からの観察**: AT(人間観察)が下流品質の最終防衛線として機能する
- **偏向パターンの事後蓄積**: `ai-antipattern.md` カタログと `[Recurrence]` 観点で偏向を学習可能にする
- **人間関与の集中**: 最も重要な防御線(SPEC + UC + AT)に人間関与を集中する(ハードルール 11)

詳細は `00-philosophy.md` を参照。
