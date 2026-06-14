Document ID: VAL-<AREA>-NNN

# VAL-<AREA>-NNN: <横断的妥当性確認のタイトル>

> VAL は **プロジェクト全体に対する横断的検証**。AT が個別 UC を対象とするのに対し、VAL は複数 SPEC / UC を跨いだ整合性を確認する。

**対象範囲**: 横断的（複数 SPEC / UC）
**実施タイミング**: 大規模マイルストーン / 統合フェーズ / リリース判断
**最終更新**: YYYY-MM-DD

## 1. 検証目的

なぜこの横断検証が必要か。

- 想定する整合性リスク: <例: SPEC-A の変更が SPEC-B の前提を破る>
- ステークホルダーの懸念: <例: パイプライン全体の throughput が SLA を満たすか>

## 2. 対象成果物

| 種別 | ID 列挙 |
|---|---|
| SPEC | SPEC-<AREA>-NNN, ... |
| UC | UC-<AREA>-NNN, ... |
| NFR | NFR-<AREA>-NNN, ... |
| 主要 SRC モジュール | <パス列挙> |

## 3. 検証項目

| # | 検証内容 | 検証手法 | 期待結果 |
|---|---|---|---|
| 1 | <内容> | <End-to-End test / integration / data flow review / review meeting> | <期待> |
| 2 | ... | ... | ... |

## 4. 結果記録

### 検証セッション 1

- 実施日: YYYY-MM-DD
- 参加者: <ロール列挙>
- 検証項目: <番号列挙>
- 結果:
  - 項目 1: PASS / FAIL / NEEDS_INVESTIGATION
  - 項目 2: ...
- 発見事項:

### 検証セッション 2

...

## 5. 不整合発見時の処置

| 発見事項 | 起票先 | 影響範囲 |
|---|---|---|
| <発見 1> | GAP-<AREA>-NNN（新規）| SPEC-<AREA>-MMM, UC-<AREA>-OOO |
| <発見 2> | ADR-<AREA>-MMM（新規）| 全体方針 |

## 6. 関連成果物

- 関連 SPEC: <ID 列挙>
- 関連 ADR: <ID 列挙>
- 関連 AT: <ID 列挙>（個別 UC レベルの検証で関連するもの）
