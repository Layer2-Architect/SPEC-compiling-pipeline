# 08 — フェーズ進行ゲート

このドキュメントは「次のフェーズに進んでよいか」を判断するときに参照する。

## 1. 基本原則

**ゲート未通過のまま下流に進むのは、本プロセスにおける最重大の規律違反。** 旧プロセスでの破綻の主因はこれ。

各ゲートは **3 層** で構成される:

```
[1] 機械検証          ─ bash scripts/trace-check.sh / legixy check
        ↓ pass
[2] AI レビュア層     ─ 9 観点 + severity 階層 + VERDICT マーカー
        ↓ APPROVE または NEEDS_HUMAN
[3] 人間判断          ─ Critical 領域、最終 Approve、品質基準緩和判断
```

AI レビュア層は機械検証と人間判断の間を埋める。9 観点・severity・降格禁止ルール・VERDICT マーカーの詳細は `review-guidelines/` を参照（`review-guidelines/README.md` が入口）。

**AI レビュア Approve 権限**: ICONIX 具体層(SEQA→RBD 以降)〜SRC では AI が APPROVE 可能、上流(SPEC, UC, ADR, NFR, RBA→SEQA 抽象層 GREEN 確定, リリース)では `REQUEST_CHANGES` か `NEEDS_HUMAN` のみ。これは **ハードルール 11(人間関与は SPEC と UC に限定)** と整合する: 人間関与必須ゲート(NEEDS_HUMAN のみ返せるゲート)は SPEC, UC, AT に関わる境界に集中している。詳細は `review-guidelines/README.md` §「ゲート別の AI レビュア権限」。

**第一目的との関係**: ゲート 3 層構造は `00-philosophy.md` §2 の多重独立検証経路の実装である:

- 機械検証 = 決定論的判定経路(`scripts/trace-check.sh` の grep ベース検査、`legixy check --formal` の形式検証)
- AI レビュア層 = 意味的判定経路(9 観点による相補的検出)
- 人間判断 = 確率分布外側からの観察(SPEC + UC + AT 境界での最終判定)

3 層が独立に機能することで、確率論的変換器の左裾サンプル(`00-philosophy.md` §1.2)が下流に流出するリスクを多重に防ぐ。

## 2. ゲート一覧（要約）

| ゲート | 機械検証 | AI レビュア主観点 | 人間判断の主軸 |
|---|---|---|---|
| **Raw SPEC → Accepted SPEC**（前段ループ） | `bash scripts/trace-check.sh` pass（対象 SPEC を持つ最新 FCR が ACCEPTED）| `[Trace]` `[Frontend]` `[AI-Antipattern]`（Approve 不可）| QSET 質問の十分性、SPP 差分案の妥当性、SPEC が UC 生成可能な粒度に閉じているか |
| SPEC → UC | `bash scripts/trace-check.sh` pass（全 GAP[SPEC] closed、red TP[SPEC] なし、最新 FCR が ACCEPTED）| `[Frontend]` `[Spec-TDD]` `[Coverage]`（Approve 不可）| TP[SPEC] の網羅性、SPEC の成功定義の観察可能化 |
| UC → RBA | `bash scripts/trace-check.sh` pass（全 GAP[UC] closed、UC が SPEC を引用）| `[Spec-TDD]` `[Coverage]`（Approve 不可）| UC の基本/代替/例外フロー、TP[UC] の十分性 |
| **RBA → SEQA**（ICONIX 抽象層） | `legixy check --formal` pass | `[Layer]` `[Consistency]`（Approve 不可、Adversary 役の専門化）| ドメイン主語抽出の十分性、通信制約遵守 |
| **SEQA → RBD**（抽象 → 具体への翻訳） | `legixy check --formal` pass + レイヤ汚染検査(具体側に言語固有要素なし) | `[Layer]` `[Consistency]`（Approve 可）| クラス境界の妥当性、操作名が人間の言語か |
| **RBD → SEQD** | `legixy check --formal` pass + レイヤ汚染検査 | `[Layer]` `[Consistency]`（Approve 可）| クラス間メッセージング設計の妥当性 |
| **RPC（抽象→具体 責務保存）**（v1.0）| `legixy check --formal` + RPC presence + VERDICT 抽出 | `[Consistency]` `[Layer]`（Approve 可）| 原則なし。`11` §9 分解 (b)（UC 不備の露呈）の場合のみ SPEC/UC 遡及承認 |
| SEQD → DD | `legixy check`（第 2 層 semantic）pass | `[Layer]` `[Doc]`（API 凍結のみ Approve 不可）| 言語仕様反映、API 凍結 |
| DD → TS | `legixy check`（第 2 層 semantic）pass | `[Coverage]` `[Trace]`（Approve 可）| TS が TP の全観点を継承しているか |
| TS → TC[RED] | TS ID 引用が全解決、コンパイル成功 | `[Coverage]` `[AI-Antipattern]`（Approve 可）| assertion の具体性、テスト名の可読性 |
| TC[RED] → SRC | テスト失敗が「未実装」起因であること | `[AI-Antipattern]`（Approve 可）| (なし) |
| SRC → TC[GREEN] | 全テスト pass、`bash scripts/trace-check.sh` pass | `[AI-Antipattern]` `[Doc]` `[Recurrence]`（Approve 可）| 最小実装か、API surface に意図しない関数が無いか |
| **契約適合（配送層、v1.0）** | ①ビルド → ②TC[DLV] 実バイナリ E2E pass → ③契約項目↔TC mapping 全数照合 → ④`check --formal`（配送チェーン構造）＋ **ChainIntegrity WARNING の escalate** | `[Trace]` `[Doc]`（Approve 可: 配送=構造翻訳層相当）| 凍結契約項目の網羅、終了コード規約、グローバル仕様 |
| リリース（AT 通過）| 全機能/property/NFR pass、第 1 層・第 2 層 trace check pass、**契約適合ゲート pass** | `[Recurrence]` `[Doc]`（Approve 不可）| AT 結果評価、新観点の perspectives.md 追記 |

> 契約適合ゲートは配送サーフェス（CLI/API/MCP）の凍結境界契約への適合を**実バイナリ E2E**で検証する。エンジンの構造検査（孤児/chain/DAG）と**役割分担**: 構造強制はエンジン、振る舞い適合は TC[DLV] の実行（ビルド→実行→mapping）が担う。実行順序・根拠は `12-delivery-layer.md` §6/§7。
>
> 🔴 **F2（最重要・ゲート化の必須条件）**: 配送チェーンの断裂は `ChainIntegrity` で「検出」されるが、これは
> `Severity::Warning` であり、`legixy` の終了コードは **ERROR 数のみ**で決まる。すなわち配送エッジが
> 切れていても `check --formal` は **WARNING を出すが exit=0**（再現: `../spikes/multi-area-2026-06-14/`）。
> **「検出」≠「ゲート」**。④を実ゲート化するには、ラッパ（`scripts/trace-check.sh` 等）が出力中の
> `ChainIntegrity` WARNING を grep して **非ゼロ exit に escalate** しなければならない。これを欠くと、配送層を
> 足しても孤児・断裂が素通りし、本ゲートの目的（契約サーフェスの孤児防止）が達成されない。

## 3. Raw SPEC → Accepted SPEC ゲート（前段ループ）

### 機械検証

```bash
bash scripts/trace-check.sh
# 内部で実行されるチェック（前段ループ関連）:
#   1. 各 SPEC に対する最新 FCR を探す（docs/frontend-pass/check-results/ を grep）
#   2. その FCR の **frontend_status**: が ACCEPTED であること
#   3. SPEC ファイルに **前段スキップ**: ADR-... metadata があれば pass 扱い
```

### AI レビュア層

**Approve 権限**: なし（SPEC 変更は人間承認必須 / ハードルール 1）

**主観点**:

- `[Trace]`: SPEC / QSET / SPP / FCR の Document ID、graph.toml 登録、本文 metadata の親 ID 引用
- `[Frontend]`: FCR.frontend_status の正当性、前段スキップ ADR の妥当性
- `[AI-Antipattern]`: QSET 質問が「埋め合わせ」を誘発する形になっていないか、SPP 差分案が推測埋めをしていないか

**返しうる VERDICT**:

| 状況 | VERDICT |
|---|---|
| FCR.frontend_status = ACCEPTED で AI レビュア指摘が Nit 以下 | `NEEDS_HUMAN`（人間 Approve 必須）|
| QSET 未回答、SPP 未承認、FCR が NEEDS_QUESTIONNAIRE | `REQUEST_CHANGES` |
| 前段スキップ ADR の妥当性に Critical / Major 指摘あり | `REQUEST_CHANGES` |
| ADR スキップが連続している | `REQUEST_CHANGES`（`[Frontend]` Major）|

### 人間判断

- QSET の質問が後段コンパイル必須項目に結びついているか（雑談質問でないか）
- SPP の差分案が QSET 回答の意図を正確に反映しているか
- SPEC が UC 生成可能な粒度まで閉じているか（成功条件、例外経路、境界が明確か）
- 検出されない不足が残存している懸念がないか

### 通過しない場合

QSET 未回答 / SPP 未承認 / FCR が NEEDS_QUESTIONNAIRE の状態で TP[SPEC] / UC に進むと、**TP / UC が SPEC の不完備を埋め合わせる**。これは旧プロセスの典型的破綻パターン。前段ループの反復を続けるか、ADR でスキップを記録する。

### スキップする場合

`docs/adr/ADR-<AREA>-NNN_frontend-pass-skip-<SPEC-ID>.md` を発行し、SPEC ファイルに `**前段スキップ**: ADR-<AREA>-NNN` を記載する。スキップ件数の累積は早期警戒指標として monitoring する。詳細は `03a-frontend-pass.md` §11。

## 4. SPEC → UC ゲート

### 機械検証

```bash
bash scripts/trace-check.sh
# 内部で実行されるチェック:
#   1. legixy check --formal   （第 1 層形式検証）
#   2. red 状態の TP がない                  （grep ベース、SPEC レベル TDD ゲート）
#   3. open 状態の GAP がない                （grep ベース、SPEC レベル TDD ゲート）
```

### AI レビュア層

**Approve 権限**: なし（TP[SPEC] の網羅性は人間判断、ハードルール 1）

**主観点**:

- `[Frontend]`: 親 SPEC の FCR が ACCEPTED であること（再確認）
- `[Spec-TDD]`: red TP / open GAP の残存、GAP の「解決経緯」セクションが空のまま closed になっていないか
- `[Coverage]`: TP が汎用観点（境界値・エラー・権限・状態・競合・外部連携・ライフサイクル・バージョニング）の主要カテゴリを網羅しているか、領域固有観点が反映されているか

**返しうる VERDICT**:

| 状況 | VERDICT |
|---|---|
| 全 GAP[SPEC] closed、red TP[SPEC] なし、AI レビュア指摘が Nit 以下 | `NEEDS_HUMAN` |
| open GAP / red TP が残っている | `REQUEST_CHANGES` |
| `[Coverage]` で Major 以上の網羅性不足 | `REQUEST_CHANGES` |
| GAP が「内容未解決のまま closed」になっている | `REQUEST_CHANGES`（`[Spec-TDD]` Major）|

### 人間判断

- TP[SPEC] の網羅性レビュー（汎用観点 + 領域固有観点が両方カバーされているか）
- SPEC §「成功の定義」が観察可能化されているか
- ハードな制約（責任分離、不変条件）が明示されているか

### 通過しない場合

GAP がクローズしない、または TP に観点漏れがある状態で UC に進むと、**UC が SPEC の不完全性を埋め合わせる**。これが旧プロセスの典型的破綻パターン。SPEC を修正するか、TP を追加して再分析する。

## 5. UC → RBA ゲート

### 機械検証

```bash
bash scripts/trace-check.sh
# UC レベルでも red TP / open GAP の検出は同様に動作する
# OrphanFile は legixy check --formal が報告する
# 親無し UC（SPEC を引用していない UC）は本文 metadata の **親 SPEC**: を grep ベースで検査
```

### AI レビュア層

**Approve 権限**: なし（UC のフロー妥当性は人間判断）

**主観点**:

- `[Spec-TDD]`: open GAP[UC] / red TP[UC] の残存
- `[Coverage]`: TP[UC] が UC レベル固有観点（基本/代替/例外フロー、アクター遷移、データフロー）を網羅しているか
- `[Trace]`: UC の親 SPEC 引用の整合性

**返しうる VERDICT**:

| 状況 | VERDICT |
|---|---|
| 全 GAP[UC] closed、AI レビュア指摘が Nit 以下 | `NEEDS_HUMAN` |
| open GAP[UC] / red TP[UC] が残っている | `REQUEST_CHANGES` |
| `[Coverage]` で TP[UC] が代替/例外フローを拾えていない | `REQUEST_CHANGES` |

### 人間判断

- 各 UC の基本フロー・代替フロー・例外フローが揃っているか
- アクター・前提条件・事後条件が明示されているか
- TP[UC] の観点が UC に対して十分か

### 通過しない場合

UC レベルの不完全性は RBA/SEQA/RBD/SEQD では検出されにくい（これらは UC を構造的に展開するだけで、UC が不完全なら不完全な構造ができる）。必ず UC レベルで完結させる。

## 6. RBA → SEQA → RBD → SEQD → DD ゲート（ICONIX 二段化層）

これらのゲートは個々には比較的軽いが、**抽象側と具体側のレイヤ汚染検査(ハードルール 10)** が追加される。RBA/SEQA/RBD/SEQD/DD は UC からの構造翻訳なので、原理的に新しい情報は加わらない。

### 機械検証

```bash
legixy check --formal
# 親子関係の整合性（chain 順 UC → RBA → SEQA → RBD → SEQD → DD → TS → TC → SRC に従う）、ID の一意性、OrphanFile、IdRedefined

bash scripts/trace-check.sh
# 内部で実行:
#   - レイヤ汚染検査（具体側 RBD/SEQD に言語固有要素が混入していないか grep）
#   - 関数名(snake_case/camelCase 呼び出し)、型表記(Result<T,E>, Vec<T> 等)、
#     修飾子(pub, async)、crate 識別子(tokio::, std::) を検出
```

### 段階ごとの人間判断

#### RBA(抽象 RB)

- ドメイン主語が UC から十分に抽出されているか
- Boundary/Control/Entity の役割識別が適切か
- 通信制約が遵守されているか
- クラス名・属性・操作などの具体側要素が混入していないか

#### SEQA(抽象 SEQ)

- レーンが RBA の主語と一致するか
- メッセージがドメイン語彙のままか(関数呼び出し表記が混入していないか)
- UC の基本/代替/例外フローを網羅しているか
- **UC text が SEQA の左側に並列配置されているか**(原典 ICONIX 手法、`04-iconix-layer.md` §4.3)

#### 抽象層 GREEN 確定の三者整合性検証(両流派)

抽象層 RBA + SEQA を GREEN として確定する前に、**両流派の三者整合性検証** を実施する(`04-iconix-layer.md` §11):

**Jacobson 流(UC ⇄ RBA ⇄ SEQA)**:
- UC text の各ステップが RBA のフローと 1:1 で対応する
- RBA の主語が SEQA のレーンと一致する
- Noun-Verb ルールが SEQA でも守られている
- UC text と SEQA のメッセージが対応する

**ICONIX 流(UC ⇄ RBA ⇄ SPEC)**:
- RBA の主語が SPEC で定義された用語・概念と一致する
- 概念領域の汚染がない(「在庫」概念に「破棄物品」が混入していない等)
- UC が SPEC の責任分担・不変条件・境界条件と整合する

機械検証不能(Adversary 役 LLM + 人間判断による)。両者が確認されない場合、UC または SPEC への修正反復に戻る。

#### RBD(具体 RB)

- クラス境界が妥当か
- 操作名が人間の言語(自然言語または概念名)で書かれているか
- 属性の概念型(言語非依存)で書かれているか
- 関連カーディナリティと composition/aggregation の意味付けが妥当か
- **レイヤ汚染なし**: 関数名・引数型・戻り型・修飾子・言語識別子が混入していない

#### SEQD(具体 SEQ)

- レーンが RBD のクラスと一致するか
- 操作呼び出しが RBD で識別した操作と対応するか
- **レイヤ汚染なし**: SEQD と同じ検査

#### DD

- 言語仕様・動作環境・OS API への mapping が完結しているか
- API surface が確定し、凍結されているか(ハードルール 7)
- architectural decision が ADR として記録されているか
- 並行性、エラー型、所有戦略、crate 境界が明示されているか

### AI レビュア層（ICONIX 二段化層 共通）

ICONIX 二段化のゲートでは、既存の **Adversary 役**（`04-iconix-layer.md` §11、`guides/ai-collaboration.md` §2）が AI レビュア層の `[Layer]` `[Consistency]` 観点として再整理される。Adversary 役は AI レビュアの **専門化版** で、ここでの観点は Adversary が従来から担っていたものと一致する。

**Approve 権限**（段階別）:

| 段階 | Approve 権限 | 理由 |
|---|---|---|
| RBA → SEQA（抽象層 GREEN 確定）| なし | 三者整合性検証は Adversary + 人間判断の領域（`04-iconix-layer.md` §11）|
| SEQA → RBD（抽象 → 具体翻訳）| あり | 構造翻訳が原理的に情報を加えないため |
| RBD → SEQD | あり | 同上 |
| SEQD → DD | あり（ただし **API 凍結のみ人間必須**、ハードルール 7）| DD では API surface 凍結が人間判断 |

**主観点**（全段階共通）:

- `[Layer]`: 抽象側 RBA/SEQA にクラス名・属性混入なし、具体側 RBD/SEQD に言語固有要素混入なし
- `[Consistency]`: Jacobson 流（UC ⇄ RBA ⇄ SEQA）と ICONIX 流（UC ⇄ RBA ⇄ SPEC）の両整合性
- `[Trace]`: chain 順 UC → RBA → SEQA → RBD → SEQD → DD の遵守
- `[Doc]`（DD のみ）: API surface 変更の DD への反映、ADR 起票

**返しうる VERDICT**:

| 状況 | VERDICT |
|---|---|
| 抽象層（RBA / SEQA）: `[Layer]` `[Consistency]` 違反なし | `NEEDS_HUMAN`（Adversary 役の延長として人間判断必須）|
| 具体層（RBD / SEQD）: `[Layer]` 違反なし、構造翻訳整合 | `APPROVE` |
| DD: `[Layer]` 違反なし、API 凍結が明示されている | `APPROVE`（API 凍結内容自体の判断は `NEEDS_HUMAN`）|
| `[Layer]` で具体側に言語固有要素混入 | `REQUEST_CHANGES`（Critical）|
| `[Consistency]` で三者整合性違反（Jacobson 流 / ICONIX 流のいずれか）| `REQUEST_CHANGES`（Major、違反流派を明示）|
| 抽象側にクラス名・属性混入（概念汚染）| `REQUEST_CHANGES`（Critical）|

### 通過しない場合(レイヤ汚染検出時)

`scripts/trace-check.sh` が具体側に言語固有要素を検出した場合:

- 該当箇所を DD に移動する
- RBD/SEQD は操作名・概念表現のみに戻す
- 再度 `scripts/trace-check.sh` を実行して pass を確認

このゲートは ICONIX の構造翻訳が原理的に新しい情報を加えないという性質を保つために重要。レイヤ汚染を許すと、抽象側・具体側・DD の責務境界が崩れ、マルチバックエンド分岐点(SEQD → DD)が機能しなくなる。

## 6.5 RPC ゲート（抽象→具体 責務保存、v1.0）

RBD/SEQD 生成後・DD 着手前に置く境界ゲート。詳細仕様は `11-responsibility-preservation-check.md`。

### 機械検証

```bash
legixy check --formal     # chain 整合性、ID 一意性、OrphanFile
# + RPC 成果物の存在確認（docs/responsibility-preservation/ に対象 UC の RPC があるか）
# + RPC 末尾の VERDICT マーカー抽出
```

### AI レビュア層

**Approve 権限**: あり（具体層、構造翻訳が原理的に情報を加えないため）

**主観点**: `[Consistency]`（責務保存 — 既存 Adversary 役の延長）、`[Layer]`

**返しうる VERDICT**（`11` §9 のエスカレーション規律に従う）:

| 状況 | 分解 | VERDICT |
|---|---|---|
| 保存失敗なし（lost=0 / mutated=0 / shifted=0 / ambiguous 解消済）、指摘 Nit 以下 | — | `APPROVE` |
| 具体側生成の逸脱（lost / mutated / shifted / 未正当化 split・merge・invented）。UC は正しい | (a) | `REQUEST_CHANGES`（AI が RBD/SEQD を UC ステップに再アンカーして自律再生成） |
| `ambiguous` 残存 | (a) | `REQUEST_CHANGES`（AI が UC ステップ対応根拠を提示して再生成。**人間にエスカレートしない**） |
| 保存失敗が UC 自体の不備・曖昧さを露呈 | (b) | `NEEDS_HUMAN`（SPEC/UC 遡及承認。本文に遡及理由を必須記述） |

### 人間判断

**原則なし。** RPC の不一致は下流自律実行領域の内側で AI が解消する（review-fix loop）。例外は §9 分解 (b)（UC 不備の露呈）の場合のみで、このとき SPEC/UC への遡及修正承認が人間関与となる（ハードルール 1・11）。NEEDS_HUMAN を分解 (b) 以外で乱発することは `ai-antipattern.md` §H-1（人間関与の下流への誘発）に該当する。

### 通過しない場合

`lost` / `mutated` / `shifted` / 未解決 `ambiguous` のいずれかがある状態で DD に進んではならない（`11` §7）。保存率の数値は合否に使わず、絶対条件ゲートで判定する。

## 7. DD → TS ゲート

### 機械検証

```bash
legixy check
# 第 1 層 + 第 2 層（semantic）。ONNX モデル必須。
# DD と上流（UC, TP）の意味的整合性、SemanticSimilarity / LinkCandidate / Drift の検出。
```

### AI レビュア層

**Approve 権限**: あり

**主観点**:

- `[Coverage]`: TS が TP の全観点を継承しているか
- `[Trace]`: TS の親 TP / 親 DD 引用が解決すること
- `[AI-Antipattern]`: TS のテストケースが「具体化不足」のまま観点と同じ抽象レベルで止まっていないか

**返しうる VERDICT**:

| 状況 | VERDICT |
|---|---|
| TS が TP の全観点を継承、`[Coverage]` で網羅性 OK | `APPROVE` |
| `[Coverage]` で TP の観点が TS に翻訳されていない（漏れあり）| `REQUEST_CHANGES`（Major）|
| TS のテストケースが具体化されていない（入力・期待値の記述漏れ）| `REQUEST_CHANGES`（Major）|

### 人間判断

- TS が **TP の全観点を継承しているか**
- TS の各テストケースが具体的（入力・期待値・前提条件が記述）か
- Property-based testing が適用可能な領域で活用されているか

## 8. TS → TC[RED] ゲート

### 機械検証

- TC のコメント内 ID 引用 (`// @ts: TS-<AREA>-NNN ケース 1`) が全て解決すること
- 各 TC ファイル先頭に `Document ID: TC-<AREA>-NNN` 行が存在すること（`file_pattern = "contains"`）
- 該当言語のコンパイル / 型チェックが成功

### AI レビュア層

**Approve 権限**: あり

**主観点**:

- `[Coverage]`: TC の各ケースが TS の各ケースに 1:1 対応しているか、weak matcher（`objectContaining` で値検証緩めなど）に逃げていないか
- `[AI-Antipattern]`: assertion が「曖昧な true/false」だけになっていないか、テスト名が機械的命名（test_1, test_2）になっていないか
- `[Trace]`: TC コメントの `@ts: TS-...` 引用整合

**返しうる VERDICT**:

| 状況 | VERDICT |
|---|---|
| コンパイル成功、ID 引用解決、assertion が具体的 | `APPROVE` |
| weak matcher 多用、または assertion が曖昧 | `REQUEST_CHANGES`（Minor〜Major）|
| TS のケースが TC で抜けている | `REQUEST_CHANGES`（`[Coverage]` Major）|

### 人間判断

- assertion が具体的か（曖昧な true/false だけでないか）
- テスト名から検証内容が読み取れるか

## 9. TC[RED] → SRC ゲート

### 機械検証

- TC を実行して失敗することの確認
- 失敗が「未実装」起因であって他の理由でないこと

```bash
# 言語に応じたコマンドで「未実装」エラーを確認
cargo test 2>&1 | grep -E "not yet implemented|FAILED"
```

### AI レビュア層

**Approve 権限**: あり

**主観点**:

- `[AI-Antipattern]`: 失敗が「未実装」以外の理由（型エラー、parse エラーなど）になっていないか

**返しうる VERDICT**:

| 状況 | VERDICT |
|---|---|
| テスト失敗が「未実装」起因のみ | `APPROVE`（次フェーズへ）|
| その他理由の失敗を含む | `REQUEST_CHANGES`（TS / TC の修正に戻る）|

## 10. SRC → TC[GREEN] ゲート

### 機械検証

```bash
# 全テスト実行
cargo test          # Rust
npx vitest run      # TypeScript
pytest              # Python
dotnet test         # C#

# trace 整合性
bash scripts/trace-check.sh         # 第 1 層 + SPEC レベル TDD ゲート
legixy check           # 第 2 層 semantic（ONNX モデル配置時のみ）
```

### AI レビュア層

**Approve 権限**: あり（記事[^cortex]のメイン適用領域）

**主観点**（このゲートでは AI レビュアの 9 観点全てが効く）:

- `[AI-Antipattern]`: 幻覚 API、エラー握り潰し、scope creep、dead code、不要な後方互換コード（`ai-antipattern.md` §C 参照）
- `[Doc]`: コード変更に対する DD / SPEC / perspectives の更新漏れ、API surface 変更の DD への反映漏れ、ADR 起票漏れ
- `[Recurrence]`: バグ修正 PR で再発防止カテゴリ（trace-check 追加 / perspectives 昇格 / ガイドライン追加 / ADR 例外 / 何もしない）が明記されているか
- `[Trace]`: SRC が DD の API surface 外の関数を増やしていないか
- `[Layer]`: DD で定義されていない言語固有概念が SRC に混入していないか（DD と SRC の境界）

**返しうる VERDICT**:

| 状況 | VERDICT |
|---|---|
| 全テスト pass、`[AI-Antipattern]` 違反なし、`[Doc]` 更新済、`[Recurrence]` 明記 | `APPROVE` |
| 幻覚 API、エラー握り潰し等の `[AI-Antipattern]` Critical | `REQUEST_CHANGES` |
| API surface に意図しない関数増、DD 未更新 | `REQUEST_CHANGES`（`[Doc]` Critical / `[Trace]` Major）|
| バグ修正 PR で `[Recurrence]` カテゴリ未明記 | `REQUEST_CHANGES`（Major）|
| dead code 残置、weak matcher、不要な後方互換コード | `REQUEST_CHANGES`（Minor〜Major）|

このゲートは **記事の自動レビューが最も効く領域**。review-fix loop（AI レビュア → author AI 修正 → 再レビュー）を回す主戦場。

[^cortex]: 辻 亮佑「AIが書いたコードはAIが見る ── レビューが詰まらず、品質はむしろ上がる」(Zenn, 2026-05-26)

### 人間判断

- SRC が「最小実装」になっているか（過剰実装でないか）
- 公開 API surface に意図しない関数が増えていないか
- compiler warning / lint がゼロか
- `unsafe` / 例外処理の局所化

## 11. TC[GREEN] → 次の TC[RED] サイクル

このサイクルは内部ループなのでゲートは軽い。ただし以下を確認:

- 既存 TC が全て GREEN を維持しているか（リグレッション無し）
- リファクタリングの余地があれば実施（GREEN 維持下で）

## 12. リリースゲート（AT 通過）

### 機械検証

- 全機能テスト・property テスト pass
- NFR 要件全て pass
- `bash scripts/trace-check.sh` pass（第 1 層 + SPEC レベル TDD ゲート）
- `legixy check` pass（第 2 層 semantic、ONNX モデル配置時のみ）

### AI レビュア層

**Approve 権限**: なし（リリース判断は人間必須）

**主観点**:

- `[Recurrence]`: AT 失敗が GAP[UC] / GAP[SPEC] として記録されているか、新観点が perspectives.md に昇格されているか
- `[Doc]`: AT 由来の新観点を perspectives.md に追記漏れがないか
- `[Trace]`: AT 結果と GAP の対応関係の整合性

**返しうる VERDICT**:

| 状況 | VERDICT |
|---|---|
| 全 AT pass、NFR pass、AT 由来昇格処理完了 | `NEEDS_HUMAN`（リリース判断は人間必須）|
| AT 失敗あり、または NFR 違反あり | `REQUEST_CHANGES` |
| AT 失敗を GAP 化せずに放置 | `REQUEST_CHANGES`（Critical、ハードルール 5 違反）|
| 新観点の perspectives.md 昇格漏れ | `REQUEST_CHANGES`（`[Recurrence]` Major）|

### 人間判断

- AT の結果評価
- 想定ユーザーフィードバックの triage
- AT 由来の新観点を perspectives.md に追記
- 失敗 AT は GAP[UC] / GAP[SPEC] として記録済か

### AT で重大問題発見時

UC または SPEC への GAP として記録 → 修正フェーズに戻る。「リリース予定があるから」を理由に AT 失敗を放置しない。

## 13. SPEC 変更時の再ゲート

**注記**: SPEC 変更は `10-modification-events.md` §4.2 の **仕様変更イベント** (`spec-change`) として体系化されている。本セクションは概要のみを記す。詳細フローは Chapter 10 を参照。

SPEC を変更したら、以下を再評価:

```bash
# 影響範囲の特定
legixy impact SPEC-<AREA>-NNN

# 影響を受ける TP の再評価が必要
# 影響を受ける UC の再評価が必要
# 場合により全下流フェーズの再ゲート
```

`impact` コマンドが報告する全成果物について、第 2 層 semantic check が pass することを確認。pass しないものは drift しているので追従修正する。

### イベント駆動フロー

SCP では、SPEC 変更は slash command で起動する:

```bash
/spec-change SPEC-<AREA>-NNN
```

これにより以下の 8 ステップが自動的に進む (Chapter 10 §4.2 参照):

1. イベントログ記録
2. 変更対象ノードの確定
3. `impact` で下流影響範囲特定
4. 影響範囲レビュー (Reviewer subagent)
5. 人間承認 (ハードルール 1)
6. 変更適用
7. インクリメンタル再構築
8. ゲート再評価

SPEC 変更フローは Chapter 10 の修正イベントフレームワーク内に位置付けられている。本セクションは概要のみを記す。

## 14. ゲート違反時の記録

緊急対応等でゲートを意図的にスキップした場合、必ず `docs/adr/ADR-<AREA>-NNN_gate-skip-<context>.md` または `docs/decisions/gate-skips.md` に記録:

- どのゲートをスキップしたか
- 理由
- 解消予定（期限・条件）
- 担当者

スキップが常態化すると本プロセスは形骸化する。スキップ件数の累積は早期警戒指標として monitoring する。

## 15. ゲートを軽くしてはならない理由

「ゲートが厳しすぎて開発速度が落ちる」という主張が出たら、以下のいずれかを疑う:

1. **SPEC が育ちきっていない** → SPEC 改訂で API 契約を見直す（ハードルール 7）
2. **観点ナレッジベースが薄い** → AT を回して観点を追加する
3. **ゲート自動化が不足** → CI 統合・スクリプト化を強化する

ゲート自体を緩めるのは最後の手段。緩めるなら ADR で「なぜ緩めるか・いつ戻すか」を必ず記録する。

**特に AI レビュア層の閾値を緩める提案は警戒する**。例: severity の降格条件を増やす、`[AI-Antipattern]` の検出を無効化、`NEEDS_HUMAN` を `APPROVE` に置き換える。これらは品質基準そのものの緩和に該当し、`review-guidelines/severity.md` §3 で Critical かつ人間 Approve 必須と規定されている。

## 16. AI レビュア層の運用ルール（共通）

各ゲートに記載した「AI レビュア層」セクションの**共通ルール**をここに集約する。詳細は `review-guidelines/` を参照。

### 9 観点（順次チェック）

1. `[Trace]` — traceability 整合性
2. `[Frontend]` — 前段ループ完了状態
3. `[Spec-TDD]` — 仕様レベル TDD ゲート
4. `[Layer]` — レイヤ汚染検査
5. `[Consistency]` — 三者整合性（Adversary 役の一般化）
6. `[Coverage]` — TP / 観点ナレッジ網羅性
7. `[Doc]` — ドキュメント整合性
8. `[AI-Antipattern]` — AI 特有の罠
9. `[Recurrence]` — 再発防止判断

並列 sub-agent ではなく **1 セッション順次** で実行する。理由は `review-guidelines/README.md` 参照。

### severity 階層と降格禁止

| severity | 基準 | アクション |
|---|---|---|
| Critical | ハードルール違反、信頼境界の崩壊、品質基準の緩和 | `REQUEST_CHANGES`、人間 Approve 必須領域では二重ゲート |
| Major | チェーン不整合、レイヤ汚染、TP/GAP のクローズ漏れ | `REQUEST_CHANGES` |
| Minor | metadata 漏れ、命名改善 | `REQUEST_CHANGES`（resolve 必須）|
| Nit | スタイル好み | `APPROVE`（コメントのみ）|

**降格禁止ルール**: 「既存も同じ」「別 PR で」「段階的に」「TODO/FIXME 残置」を理由とした降格は禁止。詳細は `review-guidelines/severity.md` §2。

### VERDICT マーカー（出力末尾必須）

```html
<!-- VERDICT:APPROVE -->         <!-- AI Approve 権限があり、Nit 以下のみ -->
<!-- VERDICT:REQUEST_CHANGES --> <!-- Critical / Major / Minor を含む、判定迷ったらこちらに倒す -->
<!-- VERDICT:NEEDS_HUMAN -->     <!-- 指摘なし、ただし AI Approve 権限なしのゲート -->
```

判定マーカー欠落時は fail-safe で `REQUEST_CHANGES` 扱い。詳細は `review-guidelines/verdict-marker.md`。

### Author / Reviewer モードの分離

AI レビュア起動時は `bootstrap/CLAUDE-reviewer.md.template` に CLAUDE.md を差し替える。Author 用の生成手順コンテキストはノイズなので排除する。同一セッションで Author と Reviewer を兼務しないこと（判定の独立性を守る）。

### ガイドライン育成（human-on-the-loop）

AI レビュアが同じ種類のミスを繰り返すパターンが見えてきたら、個別 PR で上書きせず、ガイドライン側（`review-guidelines/severity.md` / `perspectives.md` / `ai-antipattern.md`）を書き換えて次回以降に伝播させる。ガイドライン書き換えは人間レビュアの判断領域。

## 17. ローカル運用でのゲート起動イベント（一人開発前提）

SCP は **開発者 1 人 + Claude Code** という同期的なローカル環境を主要シナリオとしている。クラウド CI ランナーや GitHub PR ワークフローは構造上不要なため、ゲート起動イベントもローカルに閉じる。

### PR の役割の分解とローカルへの対応

GitHub PR が担っている 6 つの役割のうち、一人開発で本当に必要なのは「区切りの宣言」「diff スコープ」「自動チェック起動」「レビュー要求」「承認/差し戻し」の 5 つで、最後の「マージ（同期点）」は構造上不要:

| PR の役割 | ローカル一人開発での対応 |
|---|---|
| ① PR 起票（区切り宣言）| `/advance <stage>` slash command の実行 |
| ② diff スコープ確定 | `git diff <前 phase tag>..HEAD` |
| ③ CI 起動トリガー | `.claude/settings.json` の hook、または `.git/hooks/pre-commit` |
| ④ レビュー要求 | Reviewer subagent の spawn |
| ⑤ 承認 / 差し戻し | `.scp/verdict.log` への append、開発者の判断 |
| ⑥ マージ（同期点）| **不要**（`main` 直接 commit でよい、phase tag で代替）|

`gh pr review --approve` のような外部 API 呼び出しはすべて不要。VERDICT マーカーは Reviewer subagent の出力末尾に書かれ、Stop hook が抽出してローカル log に追記する。

### ゲート起動の 3 経路

1. **`/advance <stage>` slash command** — 開発者が明示的に「次のゲートを判定してほしい」と宣言する経路。最も基本的なイベント

   ```bash
   /advance spec-to-uc       # SPEC → UC ゲートの判定を起動
   /advance iconix-abstract  # 抽象層 GREEN 確定の判定を起動
   /advance release          # リリースゲートの判定を起動
   ```

2. **Stop hook（Author subagent 完了時）** — Author が成果物生成を終えた瞬間に自動的に Reviewer subagent を起動する経路。明示的な `/advance` を忘れにくくする

3. **`.git/hooks/pre-commit`** — commit 時に必ず `trace-check.sh` を実行する経路。機械検証層を deterministic に強制する

### NEEDS_HUMAN の意味

クラウド前提では `NEEDS_HUMAN` は「人間レビュアが PR を Approve する必要がある」を意味したが、ローカル一人開発では **開発者の明示操作必須** と読み替える:

| 元の意味 | ローカル運用での読み替え |
|---|---|
| 人間レビュアの PR Approve | 開発者が `git tag v<N>-<stage>` を打つ |
| 別レビュアの承認待ち | 開発者が `.scp/verdict.log` を確認後 commit |
| マージボタン押下 | phase tag 確定が承認の意思表示 |

VERDICT の **3 値の意味そのもの**（APPROVE / REQUEST_CHANGES / NEEDS_HUMAN）は変わらない。変わるのは消費経路だけ。

### phase tag の規律

phase tag は「ある chain ステップが GREEN 確定した」ことの不可逆な記録。tag を打つ瞬間が、PR ボタン押下に相当する **承認の意思表示**:

| tag 例 | 意味 |
|---|---|
| `v1-spec-accepted` | Raw SPEC → Accepted SPEC ゲート通過 |
| `v1-uc-green` | SPEC → UC ゲート通過、全 GAP[SPEC] closed |
| `v1-iconix-abstract-green` | RBA → SEQA の三者整合性検証完了 |
| `v1-iconix-concrete-green` | RBD → SEQD → DD 確定 |
| `v1-tc-red` | TS → TC[RED] 通過 |
| `v1-tc-green` | SRC → TC[GREEN] 通過 |
| `v1-rc` | AT 通過、リリース候補 |
| `v1-release` | リリース確定 |

`/advance` slash command が `APPROVE` を確認した後、開発者に「次の tag を打ちますか?」と提案する設計が自然。tag を打つ判断自体は開発者の手で。

### `.scp/` ディレクトリ

ローカル運用のための作業ディレクトリ。`.gitignore` に追加してリポジトリには含めない:

```
.scp/
├── verdict.log              # VERDICT の append log（最新が末尾）
├── reviewer-output/         # Reviewer subagent の出力アーカイブ
│   ├── 2026-05-27T10-30-00.md
│   └── ...
└── current-stage.txt        # 現在地ゲート（次に進むべき stage 名）
```

### bootstrap の追加テンプレ

ローカル運用に必要な hook と slash command は `bootstrap/.claude/` 配下にテンプレを置く:

```
bootstrap/.claude/
├── settings.json.template            # hooks 定義
├── commands/
│   └── advance.md.template           # /advance slash command
└── agents/
    └── reviewer.md.template          # Reviewer subagent 定義

bootstrap/.git-hooks/
└── pre-commit.template               # trace-check.sh の deterministic 強制
```

開発者は `bash bootstrap/init-tree.sh` 実行時にこれらをコピーする。

### branch / PR の不在

一人開発では原則として **`main` 直接 commit**:

- `feature/<name>` branch は不要
- PR 起票も不要
- マージコミットも不要

ただし「壊れる可能性が高い実験的な変更」を試すときだけ、`phase/<stage>` のような短命 branch を切るのは可。これは PR ワークフローではなく、単なるローカルバックアップ目的。

---

関連:

- AI レビュア観点の詳細: `review-guidelines/perspectives.md`
- severity 階層と降格禁止: `review-guidelines/severity.md`
- AI 特有の罠カタログ: `review-guidelines/ai-antipattern.md`
- VERDICT マーカー仕様（§8〜9 にローカル運用詳細）: `review-guidelines/verdict-marker.md`
- Reviewer モード CLAUDE.md: `bootstrap/CLAUDE-reviewer.md.template`
- ローカル運用 hook / slash command: `bootstrap/.claude/`
- Adversary 役の既存運用: `04-iconix-layer.md` §11、`guides/ai-collaboration.md` §2
