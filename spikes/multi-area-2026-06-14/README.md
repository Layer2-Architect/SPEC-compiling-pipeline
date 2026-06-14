# multi-area スパイク（2026-06-14）— SCP v1.0 §12 配送層

`12-delivery-layer.md` §10 の主張を裏付ける**再現可能成果物**（F1 対応＝「主張は適合出力で裏付ける」原則の自己適用）。

> **注**: 本スパイクの `run.sh` / `transcript.txt` は実行・記録時点の実バイナリ名 `traceability-engine`（v0.4.0-alpha4）をそのまま保持する（再現の忠実性のため）。本ツールは `legixy` に改称・再構築中であり、ドキュメント本文では `legixy` と表記する。両者は同一の実体。

## 何を確認するか

1. traceability-engine v0.4.0-alpha4 の **multi-area**（`[id.areas]` + `[[id.chains]]`）が、配送軸
   （`CTR`=根 → `DLV` → `TS` → `TC` → `SRC`）を機能軸（LGX）と**別 area**で成立させる。
2. **CTR（pos 0）は親要求免除**。連結時 `check --formal` クリーン。
3. `impact CTR-CLI-001` → 契約から binary まで全走査 / `investigate SRC-CLI-001` → binary から契約まで逆引き
   （別 area の機能軸 LGX に非漏洩）。
4. **F2（最重要）**: `ChainIntegrity` は `Severity::Warning` かつエンジン exit は ERROR 数のみで決まるため、
   配送エッジを切っても **WARNING は出るが exit=0**。すなわち `check --formal` 単独では**ゲートにならない**
   （legixy の「0 ERROR で素通り」の連結レベルでの再来）。→ ラッパ（`scripts/trace-check.sh`）が
   ChainIntegrity WARNING を grep して RED に escalate する必要がある（`12-delivery-layer.md` §7）。

## 実行

```bash
bash run.sh           # 要 traceability-engine（PATH）, python3
```
SUT は無改変。捨て駒 fixture（3-area: LGX + CLI + MCP、12 ノード）を `/tmp` に生成して実走する。

## 結果（`transcript.txt` 抜粋、2026-06-14）

| 検証 | 結果 |
|---|---|
| 陽性 check --formal（連結時） | `0 OK, 0 INFO, 0 WARNING, 0 ERROR` / exit=0 |
| impact CTR-CLI-001 | visited=5（CTR→DLV→TS→TC→SRC） |
| investigate SRC-CLI-001 | visited=5（SRC→…→CTR） |
| **陰性/F2**（DLV-CLI→TS-CLI 削除） | **6 WARNING（ChainIntegrity）/ exit=0** ← WARN は検出するがゲートにならない |

独立再現: 本スパイクの主張は 2 名（章著者・レビュア）が別個に実 v3 バイナリで再現済み。
