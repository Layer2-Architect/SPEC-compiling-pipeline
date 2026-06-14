Document ID: NFR-<AREA>-NNN

# NFR-<AREA>-NNN: <タイトル>

**対象**: 全 UC（横断的） または UC-<AREA>-MMM, UC-<AREA>-OOO
**カテゴリ**: 性能 / 並行性 / リソース / セキュリティ / 可用性 / ライフサイクル
**最終更新**: YYYY-MM-DD

## 1. 要件

- <定量的閾値 1>（例: P50 < 10 ms、P95 < 50 ms、N=10,000 まで）
- <定量的閾値 2>
- <定量的閾値 3>

数値は環境固定（CPU、OS、ビルド profile、入力サイズ）で記述する。

## 2. 測定方法

- ベンチマークツール: <criterion / BenchmarkDotNet / pytest-benchmark / vitest bench>
- 測定コード: `<相対パス>`
- 測定環境:
  - ハードウェア: <CPU、メモリ、ストレージ>
  - OS: <種別、バージョン>
  - ビルド profile: <release / debug / その他>
  - 入力データ: <サイズ、特性>
- 試行回数: <warm-up 回数 / 測定回数>

## 3. 計測対象メトリクス

| メトリクス | 閾値 | 単位 |
|---|---|---|
| P50 latency | <値> | ms |
| P95 latency | <値> | ms |
| P99 latency | <値> | ms |
| Throughput | <値> | ops/sec |
| Memory peak | <値> | MB |
| ... | ... | ... |

## 4. 閾値超過時の処置

1. profile を取得（perf / dotTrace / py-spy / flamegraph 等）
2. ホットパスを特定
3. 改善 issue を起票
4. 設計変更が必要なら ADR を起票
5. 設計変更でも閾値到達できない場合、SPEC レベルで要件見直し（SPEC 改訂）

## 5. 履歴

| 日付 | 測定値 | 結果 | コミット | 備考 |
|---|---|---|---|---|
| YYYY-MM-DD | P95=42 ms | PASS | abc1234 | 初回測定 |
| YYYY-MM-DD | P95=68 ms | FAIL | def5678 | 改善 issue #N 起票 |
| YYYY-MM-DD | P95=39 ms | PASS | ghi9012 | issue #N 解決 |

## 6. セキュリティ NFR の場合の追加項目

カテゴリが「セキュリティ」の場合、以下も記述:

- 脅威モデル: <STRIDE / DREAD 等で識別された脅威>
- 対策: <技術的対策・運用的対策>
- 検証手段: <ペネトレーションテスト / SAST / DAST / fuzz>
- 監査ログ要件: <なし / 取るべきイベント一覧>

## 7. 可用性 NFR の場合の追加項目

- SLO: <99.9% など>
- 復旧目標時間（RTO）: <値>
- 復旧目標地点（RPO）: <値>
- データ損失耐性: <なし / 何分まで許容>
- 監視メトリクス・アラート閾値

## 8. 関連成果物

- 関連 SPEC: SPEC-<AREA>-MMM
- 関連 UC: UC-<AREA>-OOO
- 関連 ADR: ADR-<AREA>-NNN（設計判断の根拠）
- 関連 SRC: <測定対象モジュールのパス>

---

## ID Changelog

数値要件の意味を変えた場合のみ追記。

| Date | ID | Change | Note |
|------|----|--------|------|
| YYYY-MM-DD | NFR-<AREA>-NNN | redefined | <旧定義 → 新定義> |
