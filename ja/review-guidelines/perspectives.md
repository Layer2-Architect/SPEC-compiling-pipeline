# 9 観点（AI レビュア観点）

このドキュメントは AI レビュアが 1 セッション内で **順次チェックする 9 観点** を規定する。各観点はタグ（角括弧表記）で識別される。

## 1. 9 観点一覧（俯瞰）

| タグ | 観点 | 主な対象 | 主要 severity |
|---|---|---|---|
| `[Trace]` | traceability 整合性 | Document ID、graph.toml、親 ID 引用 | Major |
| `[Frontend]` | 前段ループ完了状態 | FCR.frontend_status、スキップ ADR | Critical |
| `[Spec-TDD]` | 仕様レベル TDD ゲート | red TP / open GAP の残存 | Critical |
| `[Layer]` | レイヤ汚染検査 | 抽象側/具体側/DD の語彙混入 | Critical / Major |
| `[Consistency]` | 三者整合性 | UC ⇄ RBA ⇄ SEQA / UC ⇄ RBA ⇄ SPEC | Major |
| `[Coverage]` | TP / 観点ナレッジ網羅性 | 汎用観点 + 領域固有観点のカバー | Major |
| `[Doc]` | ドキュメント整合性 | コード変更に対する SPEC/DD/perspectives 追従 | Critical |
| `[AI-Antipattern]` | AI 特有の罠 | 埋め合わせ、推測進行、scope creep | Critical |
| `[Recurrence]` | 再発防止判断 | AT 失敗の昇格、新観点追加、ADR 化 | Major |

## 2. 観点間の関係

9 観点は独立に走るのではなく、**前の観点の findings を保ったまま次に進む** よう設計されている。観点間で findings を相互参照することで、単観点では拾えない問題が検出できる:

- `[Trace]` で chain 不整合 → `[Spec-TDD]` のゲート結果が不正確になる可能性
- `[Layer]` で具体側汚染 → `[Consistency]` の三者整合性検証もやり直し
- `[Coverage]` で観点漏れ → `[Spec-TDD]` の GAP 起票も不十分
- `[AI-Antipattern]` で埋め合わせ検出 → `[Doc]` でドキュメント更新漏れも検出されやすい

そのため 9 観点は **1 セッション順次** で実行する（並列 sub-agent ではない）。

## 3. 各観点の詳細

### `[Trace]` — traceability 整合性

**目的**: 機械検証層が拾えなかった traceability 違反、または機械検証を補強する意味的判定。

| severity | scope | 観点 |
|---|---|---|
| Major | 全成果物 | Document ID 行の漏れ |
| Major | 全成果物 | `docs/traceability/graph.toml` への `[[nodes]]` 登録漏れ |
| Major | chain 外成果物 | 本文 metadata の `**親 SPEC**:` / `**親 TP**:` 等の親 ID 引用漏れ |
| Major | chain 内成果物 | chain 順 `UC → RBA → SEQA → RBD → SEQD → DD → TS → TC → SRC` への違反 |
| Critical | 全成果物 | 存在しない ID への引用（幻覚 ID。`[AI-Antipattern]` と二重カウント可）|
| Minor | 全成果物 | ID 表記の揺れ（`SPEC-AREA-001` vs `SPEC-AREA-1`）|

**機械検証との関係**: `legixy check --formal` が大半を拾う。AI レビュアは「機械検証 pass しているが意味的におかしい」ケース（存在する ID だが文脈が違う、など）を補強する。

### `[Frontend]` — 前段ループ完了状態

**目的**: ハードルール 9（FCR ACCEPTED 必須）の遵守。

| severity | scope | 観点 |
|---|---|---|
| Critical | TP[SPEC] / UC | 対象 SPEC の最新 FCR が ACCEPTED でないのに着手している |
| Critical | TP[SPEC] / UC | FCR.frontend_status が NEEDS_QUESTIONNAIRE のまま QSET が未起票 |
| Major | SPEC | 前段スキップ時に ADR 引用が SPEC 本文に記載されていない（`**前段スキップ**: ADR-...`）|
| Major | SPEC | ADR スキップが連続しているのに警告 ADR が起票されていない |

**機械検証との関係**: `bash scripts/trace-check.sh` の前段ループゲートが大半を拾う。AI レビュアは ADR スキップの妥当性レビューを担う。

### `[Spec-TDD]` — 仕様レベル TDD ゲート

**目的**: ハードルール 2（GAP がクローズしないうちに次フェーズへ進まない）の遵守。

| severity | scope | 観点 |
|---|---|---|
| Critical | UC / RBA / 下流全般 | 親 SPEC に対して open 状態の GAP[SPEC] が残っている |
| Critical | RBA / 下流全般 | 親 UC に対して open 状態の GAP[UC] が残っている |
| Major | GAP | 「解決経緯」セクションが空のまま closed に更新されている |
| Major | TP | 全観点が GREEN なのに TP ステータスが red のまま |
| Major | TP | RED 観点に対応する GAP が起票されていない |

**機械検証との関係**: `bash scripts/trace-check.sh` の grep ベース GAP/TP gate が大半を拾う。AI レビュアは「ステータスは closed だが内容が解決していない」ケースを補強する。

### `[Layer]` — レイヤ汚染検査

**目的**: ハードルール 10（ICONIX 二段化レイヤ汚染禁止）の遵守。

| severity | scope | 観点 |
|---|---|---|
| Critical | RBA / SEQA | クラス名・属性表記など具体側要素の混入 |
| Critical | RBD / SEQD | 関数名（`snake_case()` / `camelCase()` 呼び出し）、引数具体型、戻り型の混入 |
| Critical | RBD / SEQD | 修飾子（`pub`, `async`）、crate 識別子（`tokio::`, `std::`）の混入 |
| Critical | RBD / SEQD | 言語固有ジェネリック型（`Result<T,E>`, `Vec<T>`, `Arc<Mutex<T>>`）の混入 |
| Major | RBA / SEQA | UC のドメイン語彙から外れた表現 |
| Major | DD | 抽象側・具体側で記述すべき内容が DD に重複している |

**機械検証との関係**: `bash scripts/trace-check.sh` [5/5] のレイヤ汚染検査が grep ベースで拾う。AI レビュアは grep で拾えない意味的汚染（「クラス名そのものではないが、明らかに実装言語の概念を持ち込んでいる表現」など）を補強する。

### `[Consistency]` — 三者整合性検証

**目的**: ハードルール 10 後段（**Jacobson 流三者整合性** + **ICONIX 流三者整合性** の両検証）の遵守。これは既存の Adversary 役（`04-iconix-layer.md` §11）を観点として一般化したもの。

| severity | scope | 観点 |
|---|---|---|
| Major | RBA + SEQA GREEN 前 | Jacobson 流: UC text の各ステップが RBA のフローと 1:1 対応しているか |
| Major | RBA + SEQA GREEN 前 | Jacobson 流: RBA の主語が SEQA のレーンと一致するか |
| Major | RBA + SEQA GREEN 前 | Jacobson 流: Noun-Verb ルールが SEQA でも守られているか |
| Major | RBA + SEQA GREEN 前 | ICONIX 流: RBA の主語が SPEC で定義された用語・概念と一致するか |
| Critical | RBA + SEQA GREEN 前 | ICONIX 流: 概念領域の汚染がない（例: 「在庫」概念に「破棄物品」が混入していない）|
| Major | RBA + SEQA GREEN 前 | ICONIX 流: UC が SPEC の責任分担・不変条件・境界条件と整合する |
| Critical | RPC（抽象→具体境界、v1.0）| 抽象責務が具体側で欠落・変質・役割越境している（lost / mutated / shifted）|
| Major | RPC（抽象→具体境界、v1.0）| 抽象側に根拠のない具体責務の湧出（未正当化 invented）、万能 Service/Manager/Helper への責務吸収、未正当化の split / merge |

**機械検証との関係**: 機械検証では原理的に拾えない。AI レビュア（または Adversary 役）の判定のみが頼り。RPC 観点(`11-responsibility-preservation-check.md`)は既存 Adversary 役を抽象→具体境界へ延長したもので、新規観点は増やさず本観点に統合する。NEEDS_HUMAN は RPC §9 分解 (b)（UC 不備の露呈）に限り、それ以外は REQUEST_CHANGES で AI が自律修正する。

### `[Coverage]` — TP / 観点ナレッジ網羅性

**目的**: TP が観点ナレッジベースの主要カテゴリを網羅しているかの判定。

| severity | scope | 観点 |
|---|---|---|
| Major | TP[SPEC] | 汎用観点（境界値・エラーハンドリング・権限・状態・競合・外部連携・ライフサイクル・バージョニング）の主要カテゴリが網羅されていない |
| Major | TP[SPEC] | `docs/perspectives/core-perspectives.md` の領域固有観点が反映されていない |
| Major | TP[UC] | UC レベル固有観点（基本/代替/例外フロー、アクター遷移、データフロー）の網羅性 |
| Minor | TP | 観点が「テストケース」として記述されている（具体化は TS 層の責務）|

**機械検証との関係**: 機械検証では拾えない。AI レビュアと人間レビュアの判断領域。

### `[Doc]` — ドキュメント整合性

**目的**: コード・構造変更に対するドキュメント追従の遵守。

| severity | scope | 観点 |
|---|---|---|
| Critical | 全 PR | コード変更（SRC）に対する DD / SPEC / perspectives の更新漏れ |
| Critical | 全 PR | API surface 変更に対する DD の更新漏れ |
| Major | 全 PR | architectural decision に対する ADR 起票漏れ |
| Major | AT 失敗時 | 失敗 AT に対する perspectives.md への新観点昇格漏れ |
| Major | NFR 変更時 | NFR 閾値変更に対する ADR 起票漏れ |
| Minor | 全 PR | 章節構成の表記揺れ |

**機械検証との関係**: 機械検証では原理的に拾えない（意味的整合性は ONNX モデルがあれば部分的に拾えるが、AI レビュアの判定が中心）。

### `[AI-Antipattern]` — AI 特有の罠

**目的**: AI 生成コード・成果物に固有のアンチパターンの検出。詳細カタログは `ai-antipattern.md`。

| severity | scope | 観点 |
|---|---|---|
| Critical | 全成果物 | **埋め合わせ進行**: 上流 GAP を起票せずに下流着手 |
| Critical | 全成果物 | **基準書き換え**: ハードルール緩和、`.legixy.toml` chain 変更を提案 |
| Critical | SRC | **幻覚 API**: 存在しないメソッド呼び出し（`user.findOrCreate()` のような正しそうな未定義メソッド）|
| Major | SRC | **エラー握り潰し**: 上流失敗を無言で空配列フォールバック |
| Major | SRC | **scope creep**: 1 関数の修正依頼で同ファイル全体 reformat |
| Major | 全成果物 | **既存違反追随による降格**: 「既存も同じ」を理由とした severity 降格 |
| Major | 全成果物 | **TODO/FIXME 残置**: コード内コメントで先送り |
| Minor | SRC | **使われない関数の残置**: refactor で dead code 化した旧実装の未削除 |
| Minor | SRC | **不要な後方互換コード**: 内部関数なのに deprecated alias を新設 |

**機械検証との関係**: 機械検証では原理的に拾えない。AI レビュアの判定領域。降格禁止ルールと密接に関連（`severity.md` §2 参照）。

### `[Recurrence]` — 再発防止判断

**目的**: バグ修正・AT 失敗時に再発防止アクションを必須化する。

| severity | scope | 観点 |
|---|---|---|
| Major | バグ修正 PR | PR description に再発防止カテゴリの選択が明記されていない |
| Major | AT 失敗 | 失敗 AT が GAP[UC] / GAP[SPEC] として記録されていない |
| Major | AT 失敗 | 新観点が perspectives.md に昇格されていない |
| Major | 障害修正 | 同種障害を機械検出する trace-check / lint / 観点が追加されていない |

**再発防止カテゴリ**（バグ修正 PR の description に必須記載）:

- `trace-check に追加` — `scripts/trace-check.sh` に grep ベースのチェックを追加
- `perspectives 昇格` — 新観点を `docs/perspectives/` に追加
- `ガイドライン追加` — `review-guidelines/` 配下に新ルール
- `ADR で例外として記録` — 修正せず例外として明示
- `何もしない` — 一過性で再発リスクなし（理由を PR description に記載）

「何もしない」を選ぶ場合も明記必須。空欄は Major で REQUEST_CHANGES。

**機械検証との関係**: 部分的に機械化可能（PR description に再発防止セクションがあるかの grep）。判定は AI レビュア + 人間。

## 4. 観点の起動順序

AI レビュアは以下の順で観点を巡る（前の観点の findings を後段が参照できるよう設計）:

1. `[Trace]` — 土台。chain 不整合や ID 漏れは下流すべてに影響する
2. `[Frontend]` — 上流ゲートの確認。ハードルール 9 違反は他観点を実行する前提を崩す
3. `[Spec-TDD]` — 上流ゲートの確認。ハードルール 2 違反は同様
4. `[Layer]` — 構造汚染の早期検出。後段の `[Consistency]` 検証の前提
5. `[Consistency]` — 三者整合性。`[Layer]` 違反があれば不正確になる
6. `[Coverage]` — TP 網羅性。`[Spec-TDD]` の GAP 起票漏れと連動
7. `[Doc]` — ドキュメント整合。コード変更全体を見て判定
8. `[AI-Antipattern]` — AI 特有の罠。他観点の findings を踏まえてパターン認識
9. `[Recurrence]` — 再発防止。最後に再発を防げる構造になっているか確認

## 5. 観点の育成

新しいパターンが見つかったら、該当観点の表に追記する。観点自体が増えるケース（10 個目の観点を作るべきか）は、増やす前に「既存 9 観点のどれかに分類できないか」を必ず検討する。観点数を最小に保つことで AI セッションの判定が安定する。

新観点を追加する場合は、`severity.md` の §6 表形式に従い、severity / scope / 観点 の 3 列で記述する。

---

関連:

- severity 階層と降格禁止: `severity.md`
- AI 特有の罠のカタログ: `ai-antipattern.md`
- VERDICT マーカー: `verdict-marker.md`
- 観点ナレッジベース（汎用観点）: `../perspectives/core-perspectives.md`
