# 11 — 抽象責務 → 具体責務 保存率検査(RPC)

> **Document ID**: CHECK-RESP-PRESERVE-002
> **Status**: Adopted (SCP v1.0)
> **Classification**: SCP 拡張検査仕様
> **Target position**: `[RBA + SEQA]`(抽象責務集合) → `[RBD + SEQD]`(具体責務集合) の境界
> **Purpose**: 抽象側 ICONIX 成果物に含まれる責務が、具体側 ICONIX 成果物へ降下する際に消失・過剰増殖・誤配置・意味変質しないことを検査する。すなわち「構造翻訳は新しい情報を加えない」という ICONIX 二段化層の不変条件(`04-iconix-layer.md` §1)が、確率論的変換器の下でも実際に成立したかを検証する。

---

## 0. 本書の位置付け

本書は SCP の既存チェーンに対して、**抽象責務 → 具体責務の保存性**を検査する追加仕様である。SCP v1.0 で正式採用された。

SCP 本体では、ICONIX 層は以下の二段に分離される。

```text
UC → RBA → SEQA → RBD → SEQD → DD
```

- `RBA / SEQA`: 抽象側 ICONIX 層。ドメイン主語と責務、Boundary / Control / Entity の役割、概念的な時系列相互作用を扱う。
- `RBD / SEQD`: 具体側 ICONIX 層。クラス境界、操作名、関連、具体的なクラス間メッセージングを扱う。ただし言語固有要素はまだ含めない。

本検査は、`RBA → SEQA` の内部検査でも、`RBD → SEQD` の内部検査でもない。本検査の対象は、抽象側一式と具体側一式の境界である。

```text
[RBA + SEQA]      ← 抽象責務集合(UC に錨着済み、§1.1)
      ↓
[責務保存率検査 RPC]
      ↓
[RBD + SEQD]      ← 具体責務集合
```

### 0.1 既存検査との関係(重複ではなく境界越え拡張)

`04-iconix-layer.md` には既に、責務の妥当性を検査する観点が**抽象側に**存在する。

- §3.5 概念領域の汚染検査(「在庫」概念に「破棄物品」を混入させない等)
- §4.4 コントローラの責務と実行操作の整合検証

RPC はこれらを**新規に追加する検査ではなく、抽象側で成立している責務構造が抽象→具体の境界を越えて保存されたかを検証する拡張**である。§3.5 / §4.4 が「抽象側で責務が正しく置かれているか」を見るのに対し、RPC は「その正しく置かれた責務が具体側でも正しく置かれ続けているか」を見る。観点数を最小に保つ原則(`review-guidelines/perspectives.md` §5)に従い、RPC は新規観点を増やさず既存の `[Consistency]` 観点に統合される(§13.4)。

---

## 1. なぜ RPC が必要か — 不変条件の強制

### 1.1 RBA と SEQA は意味的に同時作成され、UC に錨着している

`04-iconix-layer.md` §11.4 の抽象層 GREEN 確定条件は、Jacobson 流(UC ⇄ RBA ⇄ SEQA)と ICONIX 流(UC ⇄ RBA ⇄ SPEC)の**両整合性**を要求する。これは RBA と SEQA を結合した一つの意味単位として検証することを意味する。RBA(構造: 誰がどの責務を持つか)と SEQA(動態: その責務の時系列実現)は、抽象層 GREEN の時点で互いに整合し、かつ UC / SPEC に錨着している。

したがって RPC が「保存対象」とする**抽象責務集合は、独立した AI 生成物ではなく、UC を構造展開したものと(構造翻訳が情報を加えない限り)等価な、人間記述層に錨着した責務集合**である。RPC の参照点は実質的に UC、すなわち人間関与境界の最終ノードである。この性質が、本検査が人間関与を SPEC/UC に限定する原則(ハードルール 11)を侵食しない構造的根拠になる(§9 参照)。

### 1.2 確率論的変換器の下で不変条件は保証されない

ICONIX 二段化層は「RBA/SEQA/RBD/SEQD は UC を構造的に展開するだけで新しい情報を加えない」(`04-iconix-layer.md` §1)という不変条件に依存している。決定論的な人間が展開する前提では、この不変条件は規律で担保できた。

しかし抽象→具体の展開を担うのが確率論的変換器(AI)になると、この不変条件は**保証されなくなる**。同じ抽象責務集合からサンプリングのたびに異なる具体責務集合が生成され、責務が落ちることも、湧出することもありうる。

RPC は、この**フレームワークが既に依存している不変条件を、確率論的変換の下で初めて明示的に強制する機構**である。「ベテランのロバストネス図レビューの暗黙知を外在化する」(§15)という側面と、「既存不変条件の強制」という側面は同じものの二つの言い方である。

---

## 2. 第一目的との関係 — 要求1と要求2への非対称な効き

本検査は SCP の第一目的である **品質偏向防止**(`00-philosophy.md` §1)の下位防御線である。ただし防御の効き方を `00-philosophy.md` §1.3 の二要求に正確に分けて記述する。

確率論的変換器が抽象成果物から具体成果物を生成するとき、以下の偏向が起こりやすい。

1. **責務消失(lost)**: 抽象側にあった責務が具体側で欠落する。
2. **責務過剰増殖(split 濫用)**: 抽象側の一責務が、具体側で不必要に多数のクラス・操作へ分裂する。
3. **責務吸収(merge 濫用 / Service blob)**: 複数の抽象責務が、具体側で単一の万能クラス・万能サービスへ吸収される。
4. **責務誤配置(shifted)**: Boundary / Control / Entity の責務が具体側で別役割へ移動する。
5. **責務意味変質(mutated)**: 名称や構造は似ているが、具体側で意味が変わる。
6. **責務湧出(invented)**: 抽象側に根拠のない責務が具体側で新設される。

### 2.1 要求1(左裾サンプルの catastrophic failure 防止)— 強く効く

`lost` / `mutated` のような単発の致命的崩れ(UC の主要成功条件を担う責務が具体側で消える・変質する)は、これらを絶対ゼロ条件とする §7 のハードゲートでよく止まる。これは確率分布の左裾サンプルが下流に流出することを防ぐ防御線として機能する。

### 2.2 要求2(バイアス蓄積防止 / 山ずれ)— 機械検出層と経時監視に限って効く

`split` / `merge` の正当化判定、`mutated` / `shifted` の認定は、生成側 AI と同じ分布の内側にいる AI Reviewer が行う。生成側が訓練データ的に典型な形(例: Service blob 化)で責務を誤配置したとき、その誤配置を「保存されている」「正当」と最も認定しやすいのが同質の Reviewer である。これは `00-philosophy.md` §2.3 が認める**同質モデルのレビュア結託という不可避な構造限界**そのものであり、RPC の意味判定層はこれを破れない。

したがって要求2に対しては、RPC の意味判定層ではなく次の二つが効く。

- **legixy の機械的候補検出層**(§10.2): 対応不在・対応過多・類似度急変の検出は機械的で、生成側の分布バイアスを共有しない。特に `lost`(対応 CR なし)と `invented`(対応 AR なし)は存在/不在の機械検出に乗る。これは結託の外側にある決定論的経路である。
- **保存率・湧出率の経時監視**(§4.4): 単一 RPC の数値ではなく、プロジェクト横断で `invention_rate` や `lost` の発生傾向を追跡することで、個別サンプルからは見えない分布全体の偏向(山ずれ)の兆候を読む。

**RPC は要求1(per-instance catastrophic)を強く防ぎ、要求2(bias 蓄積)に対しては機械検出層と経時監視を通じて部分的に寄与するが、意味判定だけでは破れない。** この非対称性を運用者が誤認しないことが重要である。

---

## 3. 検査対象

### 3.1 入力成果物

| 成果物 | 役割 |
|---|---|
| `UC` | 検査対象となる振る舞いの起点。基本フロー、代替フロー、例外フローを含む。**AR 抽出の一次アンカー**(§6 Step 1)。 |
| `RBA` | 抽象ロバストネス図。ドメイン主語、役割、抽象責務を含む。 |
| `SEQA` | 抽象シーケンス図。RBA の責務が UC の時系列として実行可能かを示す。 |
| `RBD` | 具体ロバストネス図。クラス境界、操作名、関連、具体責務を含む。 |
| `SEQD` | 具体シーケンス図。RBD の具体責務が時系列呼び出しとして実行可能かを示す。 |

### 3.2 出力成果物

本検査は独立成果物として `RPC` を生成する。

| Typecode | 名称 | 役割 | 場所 |
|---|---|---|---|
| `RPC` | Responsibility Preservation Check | 抽象責務から具体責務への保存性検査結果 | `docs/responsibility-preservation/` |

`RPC` は chain 本体には入れず、`TP / GAP / AT / NFR / ADR / VAL` と同様に independent として扱う。理由は、`RPC` が新しい変換成果物ではなく、既存変換境界に対する検査成果物だからである。

> **ハードルール 4 の遵守**: 新 typecode 追加は `.trace-engine.toml` 更新が先である。RPC の登録手順は §13.1 を参照。

---

## 4. 責務保存率の定義

### 4.1 抽象責務

抽象責務とは、RBA / SEQA に現れる、ドメイン主語または Boundary / Control / Entity が担うべき振る舞いである。各抽象責務は可能な限り UC ステップに紐づけて識別する(§6 Step 1)。

例:

```text
OrderControl: 注文キャンセルの可否を判定する        (UC-001 Step 2)
Order: 注文状態を cancelled に変更する               (UC-001 Step 3)
OrderBoundary: キャンセル要求を受け付け、結果を表示する (UC-001 Step 1, 4)
```

### 4.2 具体責務

具体責務とは、RBD / SEQD に現れる、具体クラスまたは具体操作が担う振る舞いである。

例:

```text
OrderCancellationController: キャンセル条件を検証する
OrderAggregate: 注文状態を cancelled に遷移する
OrderCancellationView: キャンセル結果を表示する
```

### 4.3 保存関係

抽象責務 `AR` と具体責務 `CR` の間には、以下の関係を付与する。

| 関係 | 意味 | 保存率上の扱い |
|---|---|---|
| `preserved` | 抽象責務が具体側で適切に保存されている。 | 成功 |
| `split` | 抽象責務が複数の具体責務に妥当に分割されている。 | 正当化済みなら成功 |
| `merged` | 複数の抽象責務が単一の具体責務に統合されている。 | 正当化済みなら成功 |
| `shifted` | 責務が別の役割・クラスへ移動している。 | **保存失敗**(原則警告) |
| `lost` | 抽象責務が具体側で欠落している。 | **保存失敗** |
| `invented` | 具体側に抽象側根拠のない責務が出現している。 | 分母外、湧出率で記録 |
| `mutated` | 表面的には対応するが、意味が変質している。 | **保存失敗** |
| `ambiguous` | 対応関係が不明瞭。 | **未解決**(§9 で REQUEST_CHANGES、人間にはエスカレートしない) |

### 4.4 保存率は「監視指標」であって「合否閾値」ではない

責務保存率と湧出率を次で定義する。

```text
preservation_rate =
  (preserved + justified_split + justified_merge)
  / total_abstract_responsibilities

invention_rate = invented_concrete_responsibilities / total_concrete_responsibilities
```

ただし `justified_split` と `justified_merge` は、RBD / SEQD 内で根拠が明示され、AI Reviewer が妥当と判定したものに限る。`lost`, `shifted`, `mutated`, `ambiguous` は保存率の分子に入らない(分母には含まれ、率を下げる)。

**重要(まとめ採用点)**: これらの率を単一 RPC の pass/fail 閾値として信頼してはならない。率を算出するのは、まさに疑っている当の分布の内側にいる AI であり、数値の信頼性は AR/CR のカテゴリ付けの安定性以上にはならない。さらに §7 のハードゲートは既に `lost = 0 / mutated = 0 / shifted = 0` という絶対条件を持つため、率を閾値ゲートにする必要はない。

率の正しい用途は二つである。

1. **要求1のハードゲート**: 個別 RPC の合否は「`lost = 0 かつ mutated = 0 かつ shifted = 0 かつ ambiguous 解消済`」という**絶対条件**で判定する(§7)。
2. **要求2の経時監視(山ずれ検出)**: `preservation_rate` と `invention_rate` をプロジェクト横断で時系列記録し、傾向の悪化(例: invention_rate が全クレートで徐々に上昇)を分布全体の偏向の兆候として読む(§14 の monitoring 指標)。

---

## 5. 検査観点

(§5.1〜§5.6 は元仕様 CHECK-RESP-PRESERVE-001 から変更なし。要約のみ再掲。)

- **5.1 Coverage**: 各 RBA/SEQA 責務に対応する RBD/SEQD 責務が存在するか。
- **5.2 Role Fitness**: Boundary overreach / Control leakage / Entity anemia / Entity overreach / Service blob の検出。
- **5.3 Sequential Executability**: UC の基本/代替/例外フローを SEQA/SEQD 上で順に実行したとき責務が自然に流れるか。
- **5.4 Data Fitness**: Entity が保持・操作するデータが UC/RBA のドメイン概念に沿っているか。
- **5.5 Boundary Fitness**: Boundary への操作がその Boundary の責務にふさわしいか。
- **5.6 Control Fitness**: Control が UC の流れを調停する責務に留まっているか(万能化していないか)。

各観点の RED/GREEN 条件と GREEN/RED 例は、元仕様(本書 V1 = CHECK-RESP-PRESERVE-001)の §5 をそのまま継承する。

---

## 6. 検査手順

### Step 1: 抽象責務一覧の抽出(UC ステップを一次アンカーとする)

RBA / SEQA から抽象責務を抽出する。**抽出の安定性と監査可能性を確保するため、各抽象責務は可能な限り UC ステップに紐づける**(まとめ採用点)。UC ステップは人間が記述し前段ループ・仕様レベル TDD で確定済みの安定した参照点であり、これにアンカーすることで、(a) run ごとの AR 列挙のブレを抑え経時比較を可能にし、(b) 責務を人間記述層に紐づけてハードルール 11 と整合させる。

```markdown
## Abstract Responsibilities

| AR-ID | Source | Role | Subject | Responsibility | UC step |
|---|---|---|---|---|---|
| AR-001 | RBA | Boundary | OrderBoundary | キャンセル要求を受け付ける | UC-001 Step 1 |
| AR-002 | RBA | Control | OrderCancelControl | キャンセル可否を判定する | UC-001 Step 2 |
| AR-003 | SEQA | Entity | Order | 注文状態を cancelled に変更する | UC-001 Step 3 |
```

UC ステップに紐づかない抽象責務が現れた場合、それは「構造翻訳が情報を加えた」兆候であり、§9 のエスカレーション判定の対象になる(UC への遡及候補)。

### Step 2: 具体責務一覧の抽出

RBD / SEQD から具体責務を抽出する。(出力形式は元仕様の Step 2 と同じ。)

### Step 3: 対応表の作成

抽象責務と具体責務の対応表を作る。(出力形式は元仕様の Step 3 と同じ。)

### Step 4: 不一致の検出

Lost / Invented / Shifted / Mutated / Ambiguous を列挙する。(出力形式は元仕様の Step 4 と同じ。)

### Step 5: メトリクスの算出

§4.4 に従い `preservation_rate` と `invention_rate` を算出する。これらは監視指標であり、合否は §7 の絶対条件で判定する。

### Step 6: VERDICT(§9 のエスカレーション規律に従う)

`RPC` の末尾には機械可読な VERDICT を置く。VERDICT の選び方は §9 で厳密に規定する。

```markdown
<!-- VERDICT:APPROVE -->
<!-- VERDICT:REQUEST_CHANGES -->
<!-- VERDICT:NEEDS_HUMAN -->
```

---

## 7. RED / GREEN 条件(絶対条件ゲート)

### GREEN(以下をすべて満たす)

- `lost` が 0
- `mutated` が 0
- `shifted` が 0
- `ambiguous` が 0(解消済)
- `invented` がすべて正当化されている
- 未正当化の `split` / `merge` がない
- Boundary / Control / Entity の責務違反がない(§5.2)
- UC の基本・代替・例外フローが SEQA / SEQD 上で実行可能(§5.3)

### RED(いずれかを満たす)

- 抽象責務が具体側で欠落している(lost)
- 抽象責務の意味が具体側で変質している(mutated)
- 責務が役割境界を越えて移動している(shifted)
- 具体側で根拠のない責務が追加されている(未正当化 invented)
- Boundary / Control / Entity の責務境界が崩れている
- UC のフローを具体側で順に実行できない
- Control が万能化している / Entity が貧血化または肥大化している
- 対応関係が不明瞭なまま残っている(ambiguous)

`preservation_rate` の数値そのものは GREEN/RED 判定に使わない(§4.4)。

---

## 8. Severity

| Severity | 条件 | 対応 |
|---|---|---|
| Critical | UC の主要成功条件が具体側で失われている / 責務変質により仕様違反が発生する。**かつ原因が抽象責務集合(=UC)側にある** | §9 により NEEDS_HUMAN(SPEC/UC 遡及承認) |
| Critical | 上記のうち**原因が具体側生成のみにある**(UC は正しい) | §9 により REQUEST_CHANGES(AI が RBD/SEQD 再生成) |
| Major | 主要責務の誤配置、未正当化の split / merge、根拠不明の具体責務追加 | REQUEST_CHANGES(AI 自律修正) |
| Minor | 命名揺れ、対応根拠の記述不足、軽微な責務境界の曖昧さ | REQUEST_CHANGES(AI 自律修正) |
| Nit | 表現改善、表の補足 | APPROVE(コメントのみ) |

Severity の区分軸は「重大さ」だけでなく「**原因が具体側にあるか UC 側にあるか**」である。これが §9 のエスカレーション分岐を決める。

---

## 9. エスカレーション構造 — 人間関与は SPEC/UC のみ、漏れた場合にのみ人へ

本章が SCP v1.0 における RPC の中核設計である。基本方針は次の二段構えである。

> **まず人間関与を SPEC/UC に限定する構造を堅持する。RPC の不一致は原則として下流自律実行領域の内側で AI が解消する。どうしてもそこから漏れた場合(=原因が UC/SPEC 自体の不備にある場合)にのみ、人間へエスカレートする。**

### 9.1 不一致が必ず二つに分解されること

§1.1 の通り、抽象責務集合は UC に錨着している。したがって RPC が検出する保存失敗は、必ず次のどちらかに分解される。

- **(a) 具体側逸脱**: 抽象責務集合(=UC)は正しいが、RBD/SEQD の生成が逸脱した。
- **(b) 上流不備の露呈**: 保存失敗が、抽象責務集合(=UC)自体の不備・曖昧さを露呈した。

(a)(b) のいずれにも「RBA/SEQA/RBD/SEQD を成果物それ自体として人間が裁定する」ケースは現れない。これが、RPC を導入してもハードルール 11(人間関与は SPEC/UC のみ)が侵食されない構造的根拠である。RPC は、抽象層 GREEN 確定の NEEDS_HUMAN ゲートが既に採っている理屈(人間の役割は UC/SPEC 改訂の判断であって RBA の裁定ではない)を、境界一つ下流へ延長したものである。

### 9.2 VERDICT 判定規律

| 状況 | 分解 | VERDICT | 関与主体 |
|---|---|---|---|
| 保存失敗なし(GREEN)、指摘が Nit 以下 | — | `APPROVE` | AI(本ゲートは具体層、AI Approve 権限あり) |
| `lost` / `mutated` / `shifted` / 未正当化 split・merge / 未正当化 invented を検出。**原因は具体側生成にあり、UC は正しい** | (a) | `REQUEST_CHANGES` | AI が RBD/SEQD を UC ステップに再アンカーして自律再生成。**人間関与なし** |
| `ambiguous` が残っている | (a) | `REQUEST_CHANGES` | AI が UC ステップへの対応根拠を提示して再生成。**人間にエスカレートしない** |
| 保存失敗が、**抽象責務集合(UC)自体の不備・曖昧さを露呈**している(UC ステップに紐づかない責務が必要、UC に責務の欠落がある等) | (b) | `NEEDS_HUMAN` | SPEC/UC への遡及修正承認(ハードルール 1・11) |

### 9.3 NEEDS_HUMAN を厳格に縛る

NEEDS_HUMAN は**分解 (b)、すなわち修正が SPEC/UC への遡及を必要とする場合に限る**。これを縛らないと、自律実行領域に人間の注意が漏れ戻り、ハードルール 11 が形骸化する(`review-guidelines/ai-antipattern.md` §H-1「人間関与の下流への誘発」に該当)。

特に重要な縛り:

- **`ambiguous` は人間にエスカレートしない。** 抽象責務集合が UC に錨着している以上、曖昧さは「UC ステップへの対応根拠を AI が明示して再生成する」ことで畳める。曖昧さを安易に NEEDS_HUMAN へ逃がすことは禁止する。
- **REQUEST_CHANGES の修正は review-fix loop(AI Reviewer → author AI 修正 → 再レビュー)で回す。** これは下流自律実行領域の内側で完結する。
- NEEDS_HUMAN を選ぶ RPC は、本文に「なぜ修正が UC/SPEC への遡及を必要とするか」を必ず記述する。記述なき NEEDS_HUMAN は fail-safe で REQUEST_CHANGES に倒す。

---

## 10. legixy での扱い

### 10.1 graph.toml

`RPC` は independent node として登録する。

```toml
[[nodes]]
id = "RPC-<AREA>-001"
type = "RPC"
path = "docs/responsibility-preservation/RPC-<AREA>-001_<description>.md"
```

関連は本文 metadata で表現する。

```markdown
**対象 UC**: UC-<AREA>-001
**対象 RBA**: RBA-<AREA>-001
**対象 SEQA**: SEQA-<AREA>-001
**対象 RBD**: RBD-<AREA>-001
**対象 SEQD**: SEQD-<AREA>-001
```

### 10.2 二層構造(機械的候補検出 + AI 意味判定)

legixy は以下のペアを監視対象にできる。

| Pair | 目的 |
|---|---|
| RBA responsibility chunk ↔ RBD class / operation chunk | 抽象責務が具体責務に保存されているか |
| SEQA message chunk ↔ SEQD message chunk | 時系列意味が保存されているか |
| UC step chunk ↔ SEQD message group | UC 操作が具体側で実行可能か |
| RBA role chunk ↔ RBD stereotype chunk | Boundary / Control / Entity の役割が保存されているか |

embedding 類似度だけでは意味保存性を完全には判定できないため、legixy の機械検査は二層に分ける。

1. **候補検出(決定論的、結託の外側)**: 類似度低下、突然の類似度上昇、対応不在、対応過多を検出する。**この層は生成側 AI の分布バイアスを共有しないため、要求2(山ずれ)に対して決定論的に寄与する**(§2.2)。
2. **AI Reviewer 判定(分布の内側)**: 候補について、責務消失・責務変質・責務湧出かを意味的に判定する。この層は同質モデル結託の限界を持つ(§2.2)ことを運用上認識する。

---

## 11. AI Reviewer プロンプト要件

RPC を生成・レビューする AI Reviewer は、以下を必ず行う。

1. RBA / SEQA から抽象責務を抽出する(**UC ステップを一次アンカーとする**、§6 Step 1)。
2. RBD / SEQD から具体責務を抽出する。
3. 抽象責務と具体責務の対応表を作る。
4. 各対応に `preserved / split / merged / shifted / lost / invented / mutated / ambiguous` を付ける。
5. split / merged / invented には根拠を要求する。
6. Boundary / Control / Entity の責務境界違反を検査する(§5.2)。
7. UC の基本・代替・例外フローを、SEQA / SEQD 上でシーケンシャルに実行してみる(§5.3)。
8. 保存率と湧出率を算出する(**監視指標として**、§4.4)。
9. 各不一致について Severity と**原因の所在(具体側 / UC 側)**を付ける(§8)。
10. §9 の規律に従って VERDICT を出す(**NEEDS_HUMAN は UC/SPEC 遡及が必要な場合に限る**)。

---

## 12. RPC テンプレート

テンプレートは `templates/RPC-template.md` を参照(SCP v1.0 で追加)。VERDICT セクションには §9 の判定規律を必ず反映する。

---

## 13. 既存 SCP 文書への反映(SCP v1.0 で実施済)

### 13.1 `.trace-engine.toml`(ハードルール 4 — これが先)

`[id.types.RPC]` セクションを追加し、`independent` 配列に `RPC` を加える。

```toml
[id.chain]
independent = ["SPEC", "TP", "GAP", "ADR", "AT", "NFR", "VAL", "QSET", "SPP", "FCR", "RPC"]

[id.types.RPC]
dir = "docs/responsibility-preservation/"
ext = ".md"
file_pattern = "prefix"
```

### 13.2 `02-typecodes.md`

independent type 表に `RPC` を追加(§13.1 の登録手順を踏襲)。

### 13.3 `04-iconix-layer.md`

RBD/SEQD 生成後、DD に進む前に RPC を生成する旨を追記。§3.5 / §4.4 の拡張であることを明示。

### 13.4 `08-gates.md`

ゲート一覧に RPC ゲートを追加。位置は具体層(AI Approve 可能領域)。人間判断は「原則なし。§9 分解 (b) の場合のみ SPEC/UC 遡及承認」。

### 13.5 `review-guidelines/perspectives.md`

新規観点を増やさず、`[Consistency]` に責務保存の観点を追加。

### 13.6 `guides/ai-collaboration.md`

§3.3 の ICONIX 設計層分担表と §3.6 のゲート判定表に RPC を追加(下流自律実行領域、NEEDS_HUMAN は遡及時のみ)。

---

## 14. 未検証事項と monitoring 指標

理論的には SCP の品質偏向防止原理と整合するが、以下は未検証であり、テストベッドで実測する。

1. 抽象責務・具体責務の抽出を AI Reviewer が安定して行えるか(**UC ステップアンカーで緩和を試みる**)。
2. split / merge の正当化判定が過剰に甘くならないか。
3. `invention_rate` がどの程度を超えると危険か(**経時監視で経験的に閾値を探る**)。
4. 100 クレート規模で RPC の生成コストが許容範囲か(**§後述のリスク階層化で制御を試みる**)。
5. RPC が過剰に RED を出して下流自律実行を阻害しないか。
6. embedding 類似度と責務保存性の相関がどの程度あるか。
7. 本検査を入れることで、DD / TS / TC 以降で発見される仕様起因バグが減少するか。

### 14.1 山ずれ monitoring 指標(要求2)

以下をプロジェクト横断で時系列記録し、`.scp/` または VAL で集計する。

- 全 RPC の `lost` / `mutated` / `shifted` 件数の推移(本来 0 のはずの値が増えていないか)
- `invention_rate` の全クレート平均の推移(分布全体の責務湧出傾向)
- NEEDS_HUMAN 発火率(高すぎれば UC 品質不足、`ai-antipattern.md` §H-1 の兆候)

これらは平均的バグ数の減少ではなく、`00-philosophy.md` §8 の通り「左裾サンプルが上流に逆流して仕様レベルで検出される頻度」を測る指標として扱う。

### 14.2 コストのリスク階層化

100 クレート・50〜200 UC 規模で UC チェーンごとにフル RPC を生成するコストを制御するため、検査深度をリスクに比例させる(`00-philosophy.md` §7 の catastrophic failure コスト判断と同じ論理)。

| UC の分類 | RPC 深度 |
|---|---|
| 高クリティカリティ UC(主要成功条件・決済・状態遷移核) | フル RPC(§6 全 Step) |
| legixy 候補検出(§10.2 層1)が異常を出した UC | フル RPC |
| それ以外の UC | 軽量 RPC(Coverage と lost/invented の機械検出に限定、意味判定は省略可) |

---

## 15. 哲学的位置付け

本検査は新しい方法論の追加ではない。二つの言い方ができる。

**外在化としての側面**: 従来のロバストネス図レビューで熟練者が暗黙に行っていた「UC を順に動かす → B/C/E の責務を確認する → 抽象責務が具体責務へ妥当に降りているかを見る → 消失・湧出・誤配置・変質を検出する」という行為を、AI Reviewer と legixy が扱える検査成果物へ変換する。

**不変条件強制としての側面**: ICONIX 二段化層が依存する「構造翻訳は新しい情報を加えない」という不変条件(`04-iconix-layer.md` §1)は、決定論的な人間の下では規律で担保できたが、確率論的変換器の下では保証されない。RPC はこの不変条件を確率論的変換の下で明示的に強制する機構である。

そして §1.1 / §9.1 の通り、RBA と SEQA の意味的同時作成により抽象責務集合が UC に錨着しているため、RPC の保存失敗は必ず「具体側逸脱(AI 自律修正)」か「UC 不備の露呈(SPEC/UC 遡及)」に分解される。RPC を導入しても人間関与境界(SPEC + UC)は構造的に保たれる。

Document End
