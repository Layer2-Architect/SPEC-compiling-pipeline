# Document ID: FCR-<AREA>-<NNN>

**対象 SPEC**: SPEC-<AREA>-<NNN>
**frontend_status**: ACCEPTED | NEEDS_QUESTIONNAIRE
**反復回数**: <N>
**検証日**: YYYY-MM-DD
**検証者**: AI (qa-runner)
**人間承認**: 承認済（YYYY-MM-DD by <承認者>）| 未承認

---

## 概要

SPEC-<AREA>-<NNN>（反復 <N> 回目時点）に対するフロントエンド検証結果。本 FCR の `frontend_status` が ACCEPTED であれば、当該 SPEC は TP[SPEC] / UC 着手の対象となる（ハードルール 9）。

`scripts/trace-check.sh` は対象 SPEC を持つ FCR のうち **ID 連番が最大** のものを現在の状態とみなす。

---

## 検証項目チェックリスト

| 検証項目 | 結果 | 備考 |
|---|---|---|
| 必須項目充足（必要項目テンプレート全項目） | ✅ / ❌ | <未充足項目があれば列挙> |
| 用語一貫性（同一語が複数意味で使われていない） | ✅ / ❌ | <矛盾箇所があれば列挙> |
| 主体一貫性（同じ主体の責務が矛盾していない） | ✅ / ❌ | <矛盾箇所があれば列挙> |
| 状態遷移充足（遷移元・遷移先・異常系が揃う） | ✅ / ❌ | <欠落があれば列挙> |
| 例外経路充足（失敗・権限不足・外部依存失敗が定義） | ✅ / ❌ | <未定義があれば列挙> |
| 境界整合性（システム内外・外部依存・人間作業の境界が明確） | ✅ / ❌ | <不明箇所があれば列挙> |
| 矛盾不在（要求同士が競合していない） | ✅ / ❌ | <矛盾があれば列挙> |
| UC 生成可能性（SPEC から UC 候補を生成できる粒度） | ✅ / ❌ | <不足があれば列挙> |
| 開発者承認（直近の SPP が承認済） | ✅ / ❌ | SPP-<AREA>-<NNN> 承認日 |

---

## 判定式

```
required_template_complete         = <true|false>
glossary_consistent                = <true|false>
no_blocking_ambiguity              = <true|false>
no_blocking_contradiction          = <true|false>
exception_paths_sufficient         = <true|false>
boundary_sufficient                = <true|false>
usecase_generation_possible        = <true|false>
human_approved                     = <true|false>

if all of above:
    frontend_status = ACCEPTED
else:
    frontend_status = NEEDS_QUESTIONNAIRE
```

---

## 検証結果サマリ

**frontend_status**: <ACCEPTED | NEEDS_QUESTIONNAIRE>

### ACCEPTED の場合

- 本 SPEC は TP[SPEC] / UC 着手の対象に昇格する
- `scripts/trace-check.sh` がハードルール 9 検査を pass する
- 次は `03-spec-level-tdd.md` の手順に従って TP[SPEC] を生成

### NEEDS_QUESTIONNAIRE の場合

- 未充足項目が残っているため、新規 QSET（QSET-<AREA>-<NNN+1>）の発行が必要
- 反復回数 <N> + 1 で前段ループを続行
- 反復が多数回に達した場合、ADR で前段ループの打ち切りを記録する選択肢もある（ハードルール 9 への明示的スキップ扱い）

---

## 検出された未充足項目（NEEDS_QUESTIONNAIRE 時のみ記載）

### 未充足カテゴリ別

| カテゴリ | 件数 | 次 QSET で問う予定の内容 |
|---|---|---|
| 用語不明 | <数> | <概要> |
| 複数解釈 | <数> | <概要> |
| 例外未定義 | <数> | <概要> |
| 境界不明 | <数> | <概要> |
| 矛盾 | <数> | <概要> |
| 非機能不足 | <数> | <概要> |

---

## 注記

- 本 FCR は **形式性のゲートであり、意図性のゲートではない**。SPEC が市場や利用者にとって正しいかは別軸であり、AT（受け入れテスト）と人間判断で検証する。
- 形式性ゲートそのものも AI の検出能力に依存する近似であり、「検出されなかった不足」の存在を排除しない。
