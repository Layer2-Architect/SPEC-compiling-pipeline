# 01 — プロセス全体像

## 1. チェーン順序（概念）

```
Raw SPEC → [前段ループ] → Accepted SPEC → TP[SPEC] → GAP[SPEC]
        → UC → TP[UC] → GAP[UC]
        → RBA → SEQA → RBD → SEQD → DD
        → TS → TC[RED] → SRC → TC[GREEN]
```

ここで **前段ループ** とは:

```
Raw SPEC ⇄ QSET ⇄ SPP ⇄ FCR
（質問票 ⇄ SPEC 差分案 ⇄ 検証結果）
```

**ICONIX 二段化**: RB/SEQ は抽象側(RBA/SEQA、ドメインレベル)と具体側(RBD/SEQD、クラス図レベル)に分離されている。両者とも言語非依存。言語固有要素は DD で初出。詳細は `04-iconix-layer.md`。

独立成果物（chain 外）: `QSET`, `SPP`, `FCR`（前段ループ）、`TP`, `GAP`（仕様レベル TDD ループ）、`AT`（受け入れテスト）, `NFR`（非機能要件）, `ADR`（設計判断記録）, `VAL`（横断的妥当性確認）

**実装上の注**: legixy v3 の `[id.chain] order` には `UC → RBA → SEQA → RBD → SEQD → DD → TS → TC → SRC` が入り、`SPEC / QSET / SPP / FCR / TP / GAP / AT / NFR / ADR / VAL` は `independent` として扱う。前段ループ（Raw SPEC ⇄ QSET ⇄ SPP ⇄ FCR）と SPEC レベル TDD ループ（SPEC ⇄ TP ⇄ GAP）は本文 metadata と `scripts/trace-check.sh` の grep ベースゲートで検証する。

**二軸構造（v1.0 追加）**: 上記は **機能軸**（何をするか = UC → ライブラリ）。これと直交する **配送軸**（機能を凍結境界契約越しにどう公開するか = CLI/API/MCP）を別 area の第 2 チェーン `CTR（境界契約・根）→ DLV → TS → TC → SRC(binary)` として持つ。配送軸の SRC はバイナリ／サーフェス source を anchor し、契約サーフェスをチェーン編入する（孤児化防止）。詳細は `12-delivery-layer.md`。

## 2. 5 層の入れ子ループ

```
[前段ループ（フロントエンド・パス）]  Raw SPEC ⇄ QSET ⇄ SPP ⇄ FCR
        ↓ (FCR = ACCEPTED)
[仕様レベル TDD ループ]   SPEC ⇄ TP ⇄ GAP, UC ⇄ TP ⇄ GAP
        ↓
[ICONIX 抽象層]            RBA → SEQA           (ドメインレベル、言語非依存)
        ↓
[ICONIX 具体層]            RBD → SEQD → DD      (クラス図レベル → 言語固有)
        ↓
[コードレベル TDD ループ]  TS → TC[RED] → SRC → TC[GREEN]
        ↓
[独立検証チャネル]         AT, NFR
```

各層が独自の RED / GREEN サイクルを持ち、上位層が GREEN にならない限り下位層に進まない。**前段ループは仕様レベル TDD ループの前提条件** であり、FCR が ACCEPTED でない SPEC は TP[SPEC] / UC 着手の対象にしてはならない(ハードルール 9)。**ICONIX 抽象層と具体層の間にレイヤ汚染があってはならない**(ハードルール 10)。

### 各層の責務（要約）

| 層 | 入力 | 出力 | RED 条件 | GREEN 条件 |
|---|---|---|---|---|
| 前段ループ | Raw SPEC | QSET, SPP, FCR | FCR に未充足項目あり、または開発者未承認 | 最新 FCR が ACCEPTED（必要項目テンプレート充足 + 用語一貫 + 矛盾不在 + 例外経路充足 + 境界整合 + UC 生成可能性 + 人間承認） |
| 仕様レベル TDD（SPEC） | Accepted SPEC | TP, GAP | TP に open GAP がある | 全 GAP closed, 全 TP green |
| 仕様レベル TDD（UC） | UC ドラフト | TP, GAP | TP に open GAP がある | 全 GAP closed, 全 TP green |
| ICONIX 抽象層 | UC（GREEN） | RBA, SEQA | ドメイン主語抽出不足、責務範囲不明、通信制約違反 | 全 UC が抽象側で展開済、通信制約遵守 |
| ICONIX 具体層 | RBA, SEQA（GREEN） | RBD, SEQD, DD | クラス境界曖昧、レイヤ汚染(関数名・型・修飾子が混入) | クラス図完備、`scripts/trace-check.sh` のレイヤ汚染検査 pass、DD で API 凍結 |
| コードレベル TDD | DD, TP | TS, TC, SRC | TC が失敗（未実装由来）| 全 TC pass, trace check pass |
| AT | SRC（GREEN）| AT 結果, 新観点 | AT 失敗あり | AT 全 pass、または失敗が GAP 化済 |
| NFR | SRC（GREEN）| ベンチ結果 | NFR 違反あり | 全 NFR pass、または改善 issue 化済 |

## 3. 信頼境界の上流移動

| 従来プロセスが信頼していたもの | 本プロセスが信頼するもの |
|---|---|
| 人間のコードレビュー | TP 生成の網羅性 |
| 人間の仕様読解 | GAP 分析のフィルタ精度 |
| 人間のテスト設計力 | legixy の整合性チェック |
| ボトムアップの品質構築 | チェーン全体の verified state |

人間がコードを読む 3 つの目的のうち、(1) 仕様の完全性確認 と (2) 仕様↔実装の整合確認 は機械検証可能な層に押し上げる。残るのは (3) コード固有の品質確認のみで、これは性能・並行性・FFI 境界・アーキテクチャ判断に圧縮される。

## 4. 観察可能化という核心操作

仕様の不完全性は本質的に観察不能。だが TP（テスト観点）を生成して仕様にぶつけることで **観察可能な欠落** に変換できる。GAP はその変換結果の記録。

これにより、内部概念の形式化が貧弱な領域でも、TP / GAP のループを通じて段階的に外部仕様に近い性質を獲得していく。

## 5. 検出できる領域 / できない領域

| 領域 | 検出手段 |
|---|---|
| 仕様の網羅性（境界値・エラー・権限・状態遷移・異常系） | TP / GAP |
| 仕様↔実装の整合性 | TDD + legixy |
| 性能・並行性・リソース管理 | NFR + ベンチマーク |
| 暗黙知・ドメイン慣行・前提不一致 | AT（受け入れテスト・人間中心） |

最後のカテゴリは原理的に仕様レベル TDD で検出できない。AT はこれ専用の独立チャネル。

## 6. RED → GREEN サイクルの相似形

5 層は同じ「TDD のリズム」を異なる粒度で持つ:

```
前段ループ:      Raw SPEC → 質問票ぶつけ → 未充足検出 → 開発者回答 → 差分承認 → FCR ACCEPTED
仕様レベル:      仕様ドラフト → 観点ぶつけ → GAP 発見 → 仕様修正 → 全観点 GREEN
ICONIX 抽象層:   UC → ドメイン主語抽出 → 通信制約違反検出 → 修正 → RBA/SEQA GREEN
ICONIX 具体層:   RBA/SEQA → クラス図 mapping → レイヤ汚染検出 → 修正 → RBD/SEQD/DD GREEN
コードレベル:    TS → TC[RED] → 最小実装 → TC[GREEN]
```

各層で RED が出ているのに次に進むのは規律違反。ハードルール 2、9、10 がこれを禁止する。

## 7. 段階的導入

既存プロジェクトに後付けする場合、全層を一度に立ち上げない:

1. **Phase 1**: SPEC レイヤーのみ TP/GAP を導入。GAP[SPEC] がクローズしないと UC に進めない、というルールから始める。
2. **Phase 2**: UC レイヤーにも展開。フルフロー化。
3. **Phase 3**: AT を independent typecode として明示分離。リリース前ゲートとして組み込む。

各 Phase の効果指標は「TS 以降で発見される仕様起因バグの件数」。Phase が進むごとに減れば、信頼境界の上流移動が機能している。

詳細は `guides/adoption-phases.md`。

## 8. プロセスを使うときの 3 つの大原則

1. **不明点は人間に問い、推測で埋めない。** 「埋め合わせ」は旧プロセスの破綻主因。
2. **ゲートを飛ばさない。** 飛ばすときは ADR で記録する。記録なきスキップはプロセスの形骸化を加速する。
3. **AI 生成物は必ず上流 ID を引用する。** 後で drift 検出するため、引用元なき下流成果物を作らない。

---

次に読むべきもの:

- 成果物の種類と ID 規則 → `02-typecodes.md`
- **前段ループ（Raw SPEC → Accepted SPEC の正規化）→ `03a-frontend-pass.md`**
- 上流ループ（SPEC/UC ⇄ TP ⇄ GAP）の手順 → `03-spec-level-tdd.md`
- 全層共通のゲート判定 → `08-gates.md`
- 別視点: パイプライン・4 層構造・IR 階層をコンパイラ語彙で記述したレンズ → `09-compiler-lens.md`
