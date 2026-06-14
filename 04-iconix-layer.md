# 04 — ICONIX 設計層(RBA → SEQA → RBD → SEQD → DD)

このドキュメントは抽象側 RB/SEQ、具体側 RB/SEQ、DD の作業時に参照する。

> **二段化された ICONIX 層**: 本プロセスは ICONIX を **抽象側(ドメインレベル)** と **具体側(クラス図レベル)** の二段に分けて運用する。両者とも言語非依存。言語固有の表現は DD に追い出す。
>
> これにより同一の抽象側・具体側成果物から、Rust / Go / Scala / C / Python / Ruby / Pascal / TypeScript など複数言語の DD と SRC を生成可能になる(マルチバックエンド分岐点が DD 直前)。

## 0. 参考文献

本層の規律は以下の原典に基づく:

- **Jacobson, I. (1992).** *Object-Oriented Software Engineering: A Use Case Driven Approach.* ACM Press / Addison-Wesley.(B/E/C オブジェクトの原型 = 当初 Entity-Interface-Control、後に Boundary-Entity-Control)
- **Rosenberg, D. & Stephens, M. (2007).** *Use Case Driven Object Modeling with UML: Theory and Practice.* Apress. (ICONIX の体系化、Chapter 5 Robustness Analysis、Chapter 8 Detailed Design)

本層では **両流派の三者整合性検証** を統合する(§11 参照)。

## 1. 前提条件(このフェーズに入る前)

- SPEC とその TP[SPEC] / GAP[SPEC] が GREEN
- UC とその TP[UC] / GAP[UC] が GREEN
- 前段ループ FCR が ACCEPTED(ハードルール 9)
- `bash scripts/trace-check.sh` が pass

GAP がクローズしていない状態で RBA を始めるのは、本プロセスにおける典型的破綻パターン。**RBA/SEQA/RBD/SEQD は UC を構造的に展開するだけで新しい情報を加えない**。UC が不完全なら不完全な構造ができるだけ。

## 2. 段階ごとの責務と検証目的

| 段階 | 何を述べるか | 何を述べないか | 検証目的 |
|---|---|---|---|
| **RBA (抽象 RB)** | ドメイン主語と責務、Boundary/Control/Entity の役割識別、主語間の関係 | クラス境界、操作、属性、関連カーディナリティ | **UC 動作検証装置**: UC text と 1:1 correspondence、Noun-Verb ルール遵守、Object Discovery、UC Disambiguation |
| **SEQA (抽象 SEQ)** | UC の時系列展開、ドメイン主語間のメッセージ流れ(概念レベル) | クラスインスタンス間メソッド呼び出し | **UC ⇄ RBA ⇄ SEQA 三者整合性検証**(Jacobson OOSE 1992 流)、コントローラの責務と実行操作の整合 |
| **RBD (具体 RB)** | クラス境界、属性の存在(概念型)、操作の存在と **操作名(人間の言語)**、関連の意味付け(composition/aggregation/カーディナリティ)、ステレオタイプ | 関数名(言語命名規則)、引数具体型、戻り型、言語固有メカニズム | Object/Operation 発見結果のクラスへの mapping、抽象側との整合性 |
| **SEQD (具体 SEQ)** | 具体 RB のクラスインスタンス間メッセージ呼び出し、操作呼び出し(概念レベル) | 関数の具体名、言語固有同期機構の表記 | **Behavior Allocation**(Rosenberg & Stephens 流): どのクラスにどの操作を割り当てるか |
| **DD** | 言語仕様、動作環境、OS API、関数名、引数型、戻り型、修飾子、所有戦略、トレイト境界、crate/package 境界 | (制約なし、ただし上流の構造を反映) | 言語/環境への翻訳の完全性 |

**操作名と関数名の区別(本層の核)**:

| レイヤ | 内容 | 表記例 |
|---|---|---|
| RBD/SEQD | **操作名**: 人間の言語、操作の意図 | 「注文を確定する」/「place order」/「PlaceOrder」 |
| DD | **関数名**: 言語命名規則に従う実装識別子 | Rust `place_order` / Go `PlaceOrder` / C `order_place` |

## 3. RBA(抽象 RB) — UC 動作検証装置

### 役割

UC が **正しく動作するかを検証する装置**。UC text から抽出した主語を Boundary/Control/Entity の役割に割り当て、構造的に表現することで、UC text に含まれる曖昧性・不整合・データ漏れ・責務範囲の混乱を **観察可能化** する。Toshifumi が学んだ Jacobson OOSE 1992 流の検証構造の中核に位置する。

> Rosenberg & Stephens (2007) の表現を借りれば、ロバストネス分析は「analysis(UC)と design(class diagram)の間の **murky middle ground**」に位置する preliminary design である。

### 3.1 含むべき

- ドメイン主語(Order, Customer, Inventory 等の概念主語、クラス名にしない)
- 主語の責務(「注文を確定する」「在庫を引当てる」)
- 主語間の関係(「Order は Customer に紐付く」「Order は Inventory に問い合わせる」)
- Boundary/Control/Entity の役割識別(主語がどの役割を担うか)
- 通信制約遵守(後述)
- UC text の各ステップと 1:1 で対応するフロー

### 3.2 含むべきでない

- クラス境界、クラス名
- 属性、操作
- 関連カーディナリティ
- 言語要素(型、関数名、修飾子)

### 3.3 検証手順 1: 1:1 Correspondence(UC ⇄ RBA)

ロバストネス分析の核心検証。**RBA のフローと UC text の各ステップが 1 対 1 に対応している** こと。

| 検査 | 内容 | 違反時の対応 |
|---|---|---|
| UC ステップ → RBA フロー | UC の各ステップが RBA のフロー上に表現されているか | RBA にフロー追加 |
| RBA フロー → UC ステップ | RBA のフローに対応する UC ステップが存在するか | UC に該当ステップを追加(UC 修正) |
| 順序整合 | UC の時系列と RBA のフロー方向が一致するか | どちらかを修正 |

対応しない箇所が見つかったら、それは **UC の曖昧性または RBA の不備** を示す。両者の修正反復が UC を disambiguate する。

### 3.4 検証手順 2: Noun-Verb ルール

Jacobson オリジナルから ICONIX に継承された通信制約。**Boundary と Entity は名詞(noun)、Controller は動詞(verb)** として扱い、以下のルールで通信を制限する。

| 通信パターン | 結果 | 理由 |
|---|---|---|
| Actor ⇄ Boundary | OK | アクターとシステムの境界 |
| Boundary ⇄ Control | OK | 表示層と制御層の正常な連携 |
| Control ⇄ Entity | OK | 制御層がデータを読み書き |
| Control ⇄ Control | OK | Verb 同士の協調 |
| Entity ⇄ Control | OK(戻り値・通知) | データ層からの応答 |
| **Boundary → Boundary** | **NG** | Noun → Noun の典型的違反。UI 責務分離崩壊 |
| **Entity → Entity** | **NG** | Noun → Noun の典型的違反。データ層責務分離崩壊 |
| **Boundary → Entity** | **NG** | Noun → Noun の極端違反。表示層が永続層に直結 |
| **Actor → Control / Entity** | **NG** | アクターがシステム内部に直接アクセス |

違反を見つけたら UC レベルに戻って責任分離を再検討する(UC を修正)。

### 3.5 検証手順 3: Object Discovery

RBA を描く過程で **新オブジェクト・新責務・新属性** が発見される。Rosenberg & Stephens (2007) の表現を借りれば「robustness diagrams は object discovery の手段」。

発見項目:

- 新ドメイン主語(UC で言及されていなかった主語が必要になる)
- 新責務(主語の責任範囲を拡張する必要が出る)
- 新属性(Entity が保持すべきデータが追加で必要になる)
- 新関係(主語間の関係が UC で言及されていなかった)

発見項目は SPEC または UC に反映する(SPEC 起源完全性、ハードルール 1 で人間承認)。**「在庫」と名付けた Entity に「破棄予定品」を送り込んでいないか** のような **概念領域の汚染チェック** もここで行う(Toshifumi 提案の核心検証)。

| 概念汚染検査パターン | 検査内容 | 例 |
|---|---|---|
| Entity 概念領域外の操作混入 | Entity 概念名が示す領域から外れる操作を送っていないか | 「在庫」に破棄物品を保存する → 別 Entity「廃棄物管理」が必要 |
| Control 責務概念名と操作の不一致 | Control 名が示す責務と実行操作が一致するか | 「注文確定処理」が顧客情報を更新する → 責務逸脱 |
| Boundary 概念名と通信先の不整合 | Boundary 名が示す通信境界が実際の通信と一致するか | 「認証 API」が在庫照会する → 境界違反 |

機械検証不能。Adversary 役 LLM と人間判断による。

### 3.6 検証手順 4: UC Disambiguation

RBA を描く過程で UC の曖昧性が露呈する。Rosenberg & Stephens (2007) の表現を借りれば「When the diagram is created, the use case is usually also revised」。

曖昧性の典型パターン:

- 主語が不明(誰が何をするか)
- 責務が複数主体に渡っている(責任分離されていない)
- 境界が曖昧(外部依存と自システムの区別がない)
- 例外フローが Boundary までしか遡っていない

これらは TP[UC] で観点として捕捉すべき項目だが、RBA 段階で見つかったら GAP[UC] として記録し、UC を修正してから RBA に戻る(UC ⇄ RBA の反復ループ)。

### 3.7 出力

テンプレ: `templates/RBA-template.md`。各 UC につき 1 つ以上の RBA 図とドメイン記述。

## 4. SEQA(抽象 SEQ) — Jacobson 流三者整合性検証

### 役割

RBA で識別したドメイン主語をレーンとして、UC のフロー(基本/代替/例外)を時系列で展開する。**Jacobson OOSE 1992 の Interaction Diagram に相当** し、UC ⇄ RBA ⇄ SEQA の三者整合性を確認する。

> Toshifumi が学んだ「UC-RB-SEQ の 3 つを使ったチェック」は、Jacobson OOSE 1992 オリジナルの Requirements Model(UC)⇄ Analysis Model(B/E/C)⇄ Design Model の中の Interaction Diagram(SEQ)による三者整合性検証である。本層はこの検証を SEQA で実施する。

### 4.1 含むべき

- UC の時系列展開(基本・代替・例外)
- ドメイン主語間のメッセージ流れ(ドメイン語彙)
- 並行に発生する主体間相互作用(概念として)
- **UC text を SEQA の左側に並列配置**(原典 ICONIX の手法、UC ⇄ SEQA 同期を維持)

### 4.2 含むべきでない

- クラスインスタンス間メソッド呼び出し
- 関数名、API 名、引数型、戻り型
- 言語固有同期機構(`async`, `await`, channel 等)

### 4.3 検証手順 1: UC text 並列配置

Rosenberg & Stephens (2007) の手法を採用。**SEQA の左側に UC text を直接コピーして配置** することで、UC と SEQA が乖離した時に即座に検出可能にする。

並列配置の効果:

- UC text の各ステップが SEQA のメッセージで表現されているか視覚的に確認できる
- どちらかが修正されたとき、もう一方も同期更新する規律が働く
- レビュー時に UC ⇄ SEQA の整合性確認が一目で可能

### 4.4 検証手順 2: コントローラの責務と実行操作の整合

Toshifumi 提案の核心検証。**Control レーン上で実行される操作が、Control の概念名(責務)と一致するか** を確認する。

| 検査 | 内容 | 違反時の対応 |
|---|---|---|
| Control 名 ⇄ 実行操作 | Control の概念名が示す責務範囲内の操作のみ実行しているか | Control 分割または UC 修正 |
| Control 間メッセージの妥当性 | Control 同士の協調が UC の振る舞いを実現しているか | UC 修正または Control 再設計 |
| 操作の必要性 | 各操作が UC のステップに対応しているか(余剰操作なし) | 操作削除または UC 修正 |

機械検証不能。Adversary 役 LLM と人間判断による。

### 4.5 出力

テンプレ: `templates/SEQA-template.md`。

## 5. RBD(具体 RB) — クラス図レベル

### 役割

RBA の主語をクラスに mapping し、クラス境界・属性・操作を識別する。**操作名は人間の言語**。関数名(言語命名規則)は DD で確定。

### 5.1 含むべき

- クラス境界とクラス名(ドメイン語彙ベース、命名規則は未定)
- 属性の存在と概念的型(「文字列」「数値」「Customer への参照」)
- 操作の存在と **操作名**(「注文を確定する」「place order」)
- 関連の意味付け(composition / aggregation / カーディナリティ)
- ステレオタイプ(`<<persistent>>`, `<<external>>`, `<<boundary>>`, `<<concurrent>>` 等)
- 通信制約遵守経路(Noun-Verb ルール、§3.4 参照)

### 5.2 含むべきでない

- **関数名**(言語命名規則: `place_order`, `PlaceOrder`, `placeOrder`, `order_place`)
- 引数の具体型(`&str`, `string`, `String`, `&String`)
- 戻り型(`Result<T, E>`, `error`, `Option[T]`, `Maybe T`)
- 修飾子(`pub`, `async`, `static`, `inline`, `public`)
- 型パラメータ・ジェネリクス(`Vec<T>`, `Arc<Mutex<T>>`, `List<T>`)
- 言語/ライブラリ識別子(`tokio::`, `std::`, `sqlx::`, `import x`)

### 5.3 表記例(言語非依存)

```
Order
─────────
- id : 識別子
- status : 注文状態
- items : OrderItem のコレクション
─────────
+ 注文を確定する() : 結果
+ 注文をキャンセルする(理由) : 結果
─────────
<<persistent>>
```

この表記は Rust にも Go にも Scala にも C にも Python にも Ruby にも Pascal にも mapping 可能。

### 5.4 出力

テンプレ: `templates/RBD-template.md`。

## 6. SEQD(具体 SEQ) — Behavior Allocation

### 役割

Rosenberg & Stephens (2007) の表現を借りれば、SEQ の主目的は **Behavior Allocation**(クラスに操作を割り当てる作業)。これが make-or-break design issue。RBD のクラスをレーンとして、クラス間メッセージ呼び出し時系列を描く。**操作呼び出しは操作名(人間の言語)**、関数名は DD で確定。

### 6.1 含むべき

- 具体 RB のクラス間メッセージ呼び出し時系列
- 操作呼び出し(操作名レベル)
- 戻り値(概念レベル)
- 並行性、永続化、失敗伝搬の概念表現(ステレオタイプ的)
- **どのクラスがどの操作を担うかの確定**(Behavior Allocation)

### 6.2 含むべきでない

- 関数の具体名、引数の具体型
- 言語固有同期機構の表記
- `async fn`, `tokio::spawn`, `Promise.all` 等の具体機構

### 6.3 Behavior Allocation の指針

Rosenberg & Stephens (2007) より:「the allocation of operations to classes tends to be a make-or-break design issue」。

- 各操作はどれか一つのクラスに帰属する(複数クラスへの操作分散は責務曖昧化の兆候)
- Boundary クラスは外部との境界操作のみ
- Control クラスは複数 Entity を協調させる操作
- Entity クラスは自身のデータに対する操作のみ

割り当てに迷う操作は **責務再検討の兆候** であり、RBD または UC への戻りを示唆する。

### 6.4 出力

テンプレ: `templates/SEQD-template.md`。

## 6.5 責務保存率検査(RPC) — 抽象→具体境界(v1.0)

RBD / SEQD を生成したら、**DD に進む前に** RPC(Responsibility Preservation Check)を生成し、抽象責務(RBA/SEQA)が具体責務(RBD/SEQD)へ保存されていることを検査する。詳細仕様は `11-responsibility-preservation-check.md`。

RPC は本章 §3.5(概念領域の汚染検査)と §4.4(コントローラ責務と操作の整合検証)を**新規追加するものではなく、抽象側で成立した責務構造が抽象→具体の境界を越えて保存されたかを検証する拡張**である。§3.5 / §4.4 が抽象側内部を見るのに対し、RPC は抽象側と具体側の対応を見る。

RPC の参照点は、RBA と SEQA の意味的同時作成により UC(人間記述層)に錨着している(§11.4 の抽象層 GREEN 確定条件)。そのため RPC の保存失敗は必ず「具体側生成の逸脱(AI 自律修正)」か「UC 自体の不備の露呈(SPEC/UC 遡及)」に分解され、人間関与境界(ハードルール 11)を侵食しない。エスカレーション規律は `11-responsibility-preservation-check.md` §9。

**`RPC` が RED(`lost` / `mutated` / `shifted` / 未解決 `ambiguous` 等)の場合、DD に進んではならない。** ただし保存率の数値そのものは合否判定に使わず、絶対条件ゲート(lost=0 / mutated=0 / shifted=0 / ambiguous 解消済)で判定する。

## 7. DD(詳細設計) — 言語と環境への翻訳

### 役割

RBD/SEQD で確定したクラス図と相互作用を、**採用言語 + 動作環境 + OS API + ライブラリ** に mapping する。境界 API の最終契約はここで凍結する(ハードルール 7)。

### 7.1 含むべき(=RBD/SEQD に含まれないものすべて)

- 関数名(言語命名規則準拠)
- API surface 修飾子(`pub`, `pub(crate)`, `public`, `internal`)
- 引数の具体型、戻り型
- トレイト境界、ジェネリクス、ライフタイム、所有戦略(言語による)
- 並行性の具体表記(`async fn`, `tokio::spawn`, goroutine, `std::thread`, `Arc<Mutex<T>>`)
- 永続化ライブラリ(sqlx, diesel, sled, ファイル, インメモリ)
- 外部依存ライブラリ(reqwest, hyper, tonic)
- OS API(fs, net, signal)
- crate/package/module 境界
- export 規約(Go の大文字始まり、C の static、Rust の `pub(crate)`)

### 7.2 マルチバックエンド分岐点

DD は採用言語に応じて分岐する。同一の RBD/SEQD から:

```
RBD/SEQD ─┬─→ DD (Rust)    → SRC (Rust)
          ├─→ DD (Scala)   → SRC (Scala)
          ├─→ DD (Go)      → SRC (Go)
          ├─→ DD (Python)  → SRC (Python)
          ├─→ DD (TypeScript) → SRC (TypeScript)
          ├─→ DD (C)       → SRC (C)
          ├─→ DD (Ruby)    → SRC (Ruby)
          └─→ DD (Pascal)  → SRC (Pascal)
```

言語移行や複数言語実装時は DD だけを書き直す。RBA/SEQA/RBD/SEQD は再利用される。

### 7.3 言語別ガイド

具体的な書き方は `guides/language-stacks/` を参照:

- Rust: `guides/language-stacks/rust.md`
- TypeScript: `guides/language-stacks/typescript.md`
- Python: `guides/language-stacks/python.md`
- C# / .NET: `guides/language-stacks/csharp.md`

(他言語の guide は必要に応じて追加)

### 7.4 テンプレ

`templates/DD-template.md`

## 8. レイヤ汚染の検出(ハードルール 10 の機械検証)

`scripts/trace-check.sh` は具体側ファイル(RBD/SEQD)に対して以下のパターンを grep ベースで検出し、検出されたら違反として fail する:

| 検査項目 | 違反パターン(grep 正規表現) | 補足 |
|---|---|---|
| snake_case 関数呼び出し | `[a-z][a-z_]*\(` | `place_order(` を検出。日本語操作名は OK |
| camelCase 関数呼び出し | `[a-z][a-zA-Z]*[A-Z][a-zA-Z]*\(` | `placeOrder(` を検出 |
| async 修飾子 | `\basync\b` | |
| pub 修飾子 | `\bpub\b` | Rust |
| ジェネリック型 | `<[A-Z][a-zA-Z]*(,\s*[A-Z][a-zA-Z]*)*>` | `Result<T, E>`, `Vec<T>`, `Arc<Mutex<T>>` |
| crate/module 経由呼び出し | `[a-z][a-z_]*::` | `tokio::`, `std::`, `sqlx::` |
| Go error 慣習 | `\b\w+\s+error\b` | |

これらの記号が具体側にあれば「DD に移動すべき」と Adversary が指摘する。

## 9. 境界 API の凍結

DD 段階で **境界 API の最終契約**(シグネチャ・エラー型・不変条件・冪等性・バージョン)を凍結する。凍結後の変更は「実装中の仕様書修正」ではなく「次バージョンの SPEC 改訂」として扱う(ハードルール 7)。

凍結すべき要素:

- 関数 / メソッドのシグネチャ(型レベルで完全固定)
- エラー型の値域(追加だけは許容、削除・改名は SPEC 改訂)
- 戻り値の不変条件
- 冪等性の保証範囲
- スレッド契約・同期契約
- バージョン互換性ポリシー

凍結した API を別ドキュメント(独立 typecode `IDL` など)として切り出すことで、複数実装系が共有する境界として明示できる。

## 10. ADR(設計判断記録)

DD レベルの判断のうち、後の保守性に重大な影響を与えるものは ADR として独立記録する:

- module / file の境界をどう引くか
- 公開 API の最小集合
- エラー型の設計方針
- 並行性の境界(async / sync, thread, channel 等の選択)
- FFI 境界の通信プロトコル
- 永続化フォーマット
- バージョン互換性戦略

ADR は独立 typecode(`ADR-<AREA>-NNN`、`docs/adr/`)として記録。テンプレ: `templates/ADR-template.md`。

## 11. 三者整合性検証(両流派の統合)

抽象層 GREEN 確定の前提として、**Jacobson 流と ICONIX 流の両整合性検証** を同時に行う。両者は補完的で対立しない。

### 11.1 Jacobson 流の三者整合性: UC ⇄ RBA ⇄ SEQA

Jacobson OOSE 1992 オリジナルの検証構造(Toshifumi が学んだ方法)。動的構造(SEQA)を 3 番目の視点として使う。

| 検査 | 確認内容 |
|---|---|
| UC ⇄ RBA | UC text の各ステップが RBA のフローと 1:1 で対応する(§3.3) |
| RBA ⇄ SEQA | RBA で識別した主語が SEQA のレーンと一致する、Noun-Verb ルールが SEQA でも守られている |
| UC ⇄ SEQA | UC text を SEQA の左側に並列配置(§4.3)、各 UC ステップが SEQA のメッセージと対応する |

3 者が同じ振る舞いを **動的に** 表現していることを確認する。

### 11.2 ICONIX 流の三者整合性: UC ⇄ RBA ⇄ SPEC

Rosenberg & Stephens (2007) の PDR(Preliminary Design Review)に相当。静的構造(ドメイン概念)を 3 番目の視点として使う。

SCP では **SPEC が ICONIX の Domain Model 役割を担う**(用語、概念、責任分担、不変条件、境界条件などが SPEC で確定済み、前段ループで担保)。これにより ICONIX 公式の PDR が SCP でも自然に成立する。

| 検査 | 確認内容 |
|---|---|
| UC ⇄ RBA | UC text の各ステップが RBA のフローと 1:1 で対応する(§3.3) |
| RBA ⇄ SPEC | RBA の主語が SPEC で定義された用語・概念と一致する、概念領域の汚染(§3.5)がない |
| UC ⇄ SPEC | UC が SPEC の責任分担・不変条件・境界条件と整合する |

3 者が同じドメイン概念を **静的に** 表現していることを確認する。

### 11.3 両流派の補完関係

| 視点 | Jacobson 流 | ICONIX 流 |
|---|---|---|
| 視点 1(主) | UC text | UC text |
| 視点 2(構造) | RBA (B/C/E 構造) | RBA (B/C/E 構造) |
| 視点 3(整合性確認用) | SEQA(動的構造) | SPEC(静的ドメイン概念) |
| 検証の重点 | 振る舞いの整合 | 概念の整合 |
| 検出可能な不備の典型 | 操作の流れ不整合、責務範囲の混乱 | 概念領域の汚染、用語不一致 |

両者は補完的であり、対立しない。**両方を実施することで、動的整合性と静的整合性の両方が確認される**。

### 11.4 抽象層 GREEN の確定条件

抽象層 RBA + SEQA を GREEN として確定するには以下をすべて満たす:

1. Jacobson 流の三者整合性(UC ⇄ RBA ⇄ SEQA)が確認されている
2. ICONIX 流の三者整合性(UC ⇄ RBA ⇄ SPEC)が確認されている
3. Noun-Verb ルール違反がない(§3.4)
4. Object Discovery 結果が SPEC または UC に反映されている(§3.5)
5. UC Disambiguation で生じた GAP[UC] がすべて closed(§3.6)
6. 概念領域の汚染検査が通っている(§3.5)
7. Behavior Allocation の指針が SEQA で示されている(SEQD で確定)
8. `legixy check --formal` pass
9. `bash scripts/trace-check.sh` pass(レイヤ汚染なし、§8)

3〜7 は機械検証不能。Adversary 役 LLM と人間判断による。

## 12. ICONIX 二段化層の検証コマンド

```bash
# RBA → SEQA → RBD → SEQD → DD chain の整合性
legixy check --formal

# 第 2 層 semantic(DD と上流の意味的整合性)— ONNX モデル必須
legixy check

# レイヤ汚染検出(ハードルール 10)
bash scripts/trace-check.sh
```

人間判断:

- RBA の主語抽出が UC と整合しているか(§3)
- SEQA がドメイン語彙のままか(クラス語彙が混入していないか)(§4)
- RBD の通信制約遵守(§5)
- RBD/SEQD に関数名・型・修飾子が混入していないか(Adversary 検査の補完)(§8)
- DD の architectural decision の ADR 化(§10)
- 境界 API surface が SPEC レベルで明示されているか(§9)
- §11 の両流派三者整合性検証

## 13. AI と人間の分担

### 二段化された ICONIX 層の作業

| 作業 | AI 主体 | 人間主体 |
|---|---|---|
| UC のドラフト作成 | ◯ | フロー妥当性レビュー |
| TP[UC] の初稿生成 | ◯ | 観点漏れの確認 |
| GAP[UC] の起票・クローズ | ◯(候補)| 確定 |
| **RBA(抽象 RB)ドラフト** | ◯ | ドメイン主語抽出、Noun-Verb ルールレビュー |
| **1:1 Correspondence 検証(§3.3)** | ◯ | UC との対応関係レビュー |
| **Object Discovery と概念汚染検査(§3.5)** | ◯(designer + Adversary)| 発見項目の SPEC/UC 反映承認 |
| **UC Disambiguation 反復(§3.6)** | ◯(候補提示)| GAP[UC] 起票と UC 修正承認 |
| **SEQA(抽象 SEQ)ドラフト** | ◯ | UC text 並列配置レビュー(§4.3)|
| **コントローラ責務と操作の整合検証(§4.4)** | ◯(designer + Adversary)| 違反指摘レビュー |
| **抽象 → 具体への一括 mapping(Adversary 検査付き)** | ◯(designer + Adversary)| 結果レビュー |
| **RBD(具体 RB)ドラフト** | ◯ | クラス境界、操作名(人間の言語)レビュー |
| **SEQD(具体 SEQ)ドラフト** | ◯ | Behavior Allocation レビュー(§6.3)|
| **レイヤ汚染検査(Adversary)** | ◯ | 違反指摘のレビュー、修正方針確認 |
| **Jacobson 流三者整合性検証(§11.1)** | ◯(Adversary)| 検証結果レビュー |
| **ICONIX 流三者整合性検証(§11.2)** | ◯(Adversary)| 検証結果レビュー |
| DD ドラフト(implementer)| ◯ | architectural decision の確定 |
| API surface の最小化 | ◯(提案)| 確定 |
| エラー型の設計 | ◯(提案)| 確定 |
| ADR 起票 | ◯(候補提示)| 内容承認 |
| **境界 API の凍結** | × | **必須**(ハードルール 7)|

**Q3 確定済みの遷移手順**: 抽象層 RBA/SEQA → 具体層 RBD/SEQD への移行は LLM に一括描画させ、Adversary が両層の区別を保つよう検査する(1 ステップ)。検査基準は §8、機械検証は `scripts/trace-check.sh` [5/5]。

**境界 API の凍結は人間が承認**。凍結後は変更困難になるため、最後の確認は省略不可。

## 14. TS の準備

DD が確定したら TS 生成に進む。**TS はゼロから書かない**。上流で確定した TP(観点)を、DD の構造に合わせて実行可能形式に翻訳する作業である。具体的な TS の書き方は `05-test-and-impl.md`。

---

別視点: ICONIX 二段化がコンパイラの IR 多段方言(MLIR)に対応する構造的説明は `09-compiler-lens.md` §4。
