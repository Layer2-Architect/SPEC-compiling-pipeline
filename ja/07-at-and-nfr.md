# 07 — AT（受け入れテスト）と NFR（非機能要件）

このドキュメントは AT, NFR の作業時に参照する。

## 1. なぜ独立成果物なのか

仕様レベル TDD が原理的に検出 **できない** 領域が 2 つある:

1. **暗黙知・ドメイン慣行・前提不一致** → AT
2. **性能・並行性・リソース・セキュリティ** → NFR

これらは下流成果物（TS / TC）の網羅では捕捉できない。仕様の「正しさ」とは別軸の検証チャネル。

## 2. AT（受け入れテスト）

### AT が検出するもの

- ユーザーが実物に触れて初めて気づく違和感
- ドメイン専門家が暗黙に前提していたが文書化されていなかった慣行
- ステークホルダー間で前提が一致していなかった事項
- 操作の「自然さ」「分かりやすさ」（UX 品質）

### AT が検出 *しない* もの

- 機能的正しさ（→ TC[GREEN]）／**完成品の契約適合（→ PAI、`13-product-acceptance-inspection.md`）**
- 性能（→ NFR）
- セキュリティ脆弱性（→ NFR セキュリティカテゴリ + 専門レビュー）

> ⚠️ **注意（v1.0 で補強）**: 「機能的正しさ・契約適合は TC で担保済み」という前提は、TC（TC[DLV] を含む）が
> **作者と同一分布**で書かれる以上、作者の盲点を継承して必ずしも成立しない（実証: 全チェーン GREEN でも契約違反
> 54 件が残存。`defect-root-cause` 参照）。**完成品の契約・機能適合は、作者と独立な黒箱検査 PAI
> （`13-product-acceptance-inspection.md`）が分布外側から検証する**。AT（UX）と PAI（契約/機能）は別チャネルで、
> いずれも省略不可能・相互に代替しない。

### AT の書き方（テンプレ: `templates/AT-template.md`）

```markdown
Document ID: AT-<AREA>-001

# AT-<AREA>-001: <タイトル>

**対象 UC**: UC-<AREA>-NNN
**検証方法**: 想定ユーザーによる実機操作観察 / インタビュー / ユーザビリティテスト
**判定基準**:
- <観察可能な基準 1>
- <観察可能な基準 2>
- <観察可能な基準 3>

**結果記録欄**:
- 観察日:
- 観察対象ユーザー特性:
- 所要時間:
- つまずきポイント:
- フィードバックサマリ:
- 発見された新観点（perspectives.md 昇格候補）:
```

### AT の実施タイミング

- マイルストーン到達時（v0.1, v0.2 等）
- リリース前
- UI / UX に大きな変更があった後

機能テストのように毎コミット実行するものではない。**人間中心の作業** として明示的にスケジュールする。

### AT 失敗時の扱い（最重要）

AT で問題が発見された場合、**それを SPEC または UC への GAP として記録する**。

```
AT 失敗 → 仕様の不完全性の発見 → GAP[UC] または GAP[SPEC] 生成 → 修正
                                          ↓
                                  perspectives.md に新観点追記
                                          ↓
                                  次回以降の TP 生成で検出可能化
```

これにより AT で発見された暗黙知が、次回以降は仕様レベルで検出可能な観点に変換されていく。AT は単発の検証ではなく、**観点ナレッジベースを育てるフィードバック源** でもある。

### perspectives.md 昇格

AT で発見された新観点は `docs/perspectives/core-perspectives.md` または `docs/perspectives/ux-perspectives.md` の末尾「AT から戻ってきた観点」セクションに記録し、本文の対応カテゴリにも追記する。

```markdown
| 日付 | AT-ID | 観点 | 統合先 |
|---|---|---|---|
| YYYY-MM-DD | AT-<AREA>-001 | <発見された観点> | <上記カテゴリのどれに加えたか> |
```

## 3. NFR（非機能要件）

### NFR の主要カテゴリ

- **性能**: latency, throughput, memory footprint
- **並行性**: race condition, deadlock 不在の保証
- **リソース**: ファイルハンドル、メモリ、CPU 使用率の上限
- **セキュリティ**: 認証、認可、入力検証、機密データ取り扱い
- **可用性**: 起動時間、回復時間、データ損失耐性
- **ライフサイクル**: 起動・shutdown・プロジェクト切替の所要時間と保証

### NFR の構造（テンプレ: `templates/NFR-template.md`）

```markdown
Document ID: NFR-<AREA>-001

# NFR-<AREA>-001: <タイトル>

**対象**: 全 UC（横断的） または UC-<AREA>-NNN, ...
**カテゴリ**: 性能 / 並行性 / リソース / セキュリティ / 可用性 / ライフサイクル

## 要件
- <定量的閾値 1>（例: P95 < 50 ms、N=10,000 まで）
- <定量的閾値 2>

## 測定方法
- ベンチマークツール: <criterion / BenchmarkDotNet / pytest-benchmark / vitest bench>
- 測定コード: <パス>
- 測定環境: <ハードウェア・OS・ビルド profile>

## 閾値超過時の処置
- profile を取得し、ホットパスを特定
- 改善 issue を起票
- 設計変更が必要なら ADR を起票

## 履歴
| 日付 | 測定値 | 結果 | コミット |
|---|---|---|---|
| YYYY-MM-DD | P95=42 ms | PASS | abc1234 |
```

### NFR の検証手段

NFR は TS / TC では検証しきれない。以下を併用:

- **ベンチマーク** (criterion, BenchmarkDotNet, pytest-benchmark, vitest bench 等)
- **プロパティテスト** (proptest / fast-check / hypothesis による不変条件確認)
- **Model checking** (Loom for Rust concurrency, Spin for protocol)
- **Profile** (perf, dotTrace, py-spy, flamegraph, Instruments)
- **Static analysis** (clippy, Roslyn analyzers, mypy strict, eslint, semgrep)
- **負荷試験** (k6, JMeter, Locust)
- **セキュリティスキャン** (trivy, semgrep, dependency audit)

### NFR 違反時の扱い

NFR 違反は **SPEC / UC の問題ではなく SRC レベルでの修正対象** （GAP は生成されない）。代わりに:

1. 該当 SRC の改善 issue を起票
2. 必要なら DD レベルで設計を見直す
3. 設計判断の根拠を ADR として記録
4. 緊急ケースで NFR を緩めるなら、緩和理由を ADR で記録（緩和は累積させない）

## 4. AT / NFR と他層の関係

```
SPEC ── TP ── GAP ── UC ── RB ── SEQ ── DD ── TS ── TC ── SRC
                                                          ↓
                                                         AT  ← 暗黙知ループバック
                                                          ↓ 発見された観点
                                                  perspectives.md ← TP 生成時に参照

NFR は SRC を横断的に検証（時系列に独立）
```

AT は SRC 完成後の独立工程だが、その **結果は perspectives.md にフィードバックされ、次の TP 生成を強化する**。これにより仕様レベル TDD で検出できる範囲が漸進的に拡大する。

## 5. NFR と AT を独立 typecode にする理由

これらを TC や TS の中に押し込むと:

- 性能要件が機能要件と混在し、優先順位がつけにくい
- AT 由来の暗黙知が機能テストの修正と区別されず、観点ベースに昇格しにくい
- 違反時の責任分担（SPEC 修正 vs SRC 修正）が曖昧になる

独立 typecode として明示分離することで、ゲート時の判断と、変更履歴の追跡が容易になる。

## 6. リリースゲートでの AT 通過

リリース前に必ず以下を確認:

- 全 AT が pass、または失敗した AT が GAP[UC] / GAP[SPEC] として記録されている
- 全 NFR が pass、または違反が改善 issue + 緩和 ADR として記録されている
- AT 由来の新観点が perspectives.md に昇格済み
- `bash scripts/trace-check.sh` pass

「リリース予定があるから」を理由に AT 失敗を放置しない。AT 失敗が GAP 化されないままリリースすると、**観点ナレッジベースが育たず**、同種の問題が次バージョンでも再発する。

## 7. AI と人間の分担

| 作業 | AI 主体 | 人間主体 |
|---|---|---|
| AT のシナリオ起票（テンプレ埋め）| ◯ | 内容確定 |
| AT の実施（被験者観察）| × | **必須** |
| AT 失敗の GAP 化 | ◯（候補提示）| 確定 |
| 新観点の perspectives.md 昇格 | ◯（提案）| 確定 |
| NFR の閾値設定 | × | **必須**（領域知識）|
| ベンチマーク実装 | ◯ | レビュー |
| NFR 違反時の改善案 | ◯ | 採用判断・ADR 化 |

AT は本質的に人間中心。AI は周辺作業（記録・候補提示）を支援するが、観察と判定は人間が行う。
