Document ID: RPC-<AREA>-NNN

# RPC-<AREA>-NNN: <対象 UC / ICONIX chain の責務保存率検査>

> RPC は **抽象責務集合(RBA + SEQA、UC 錨着)→ 具体責務集合(RBD + SEQD)** の保存性検査。
> 詳細仕様は `11-responsibility-preservation-check.md`。VERDICT は §9 のエスカレーション規律に従う。

**対象 UC**: UC-<AREA>-NNN
**対象 RBA**: RBA-<AREA>-NNN
**対象 SEQA**: SEQA-<AREA>-NNN
**対象 RBD**: RBD-<AREA>-NNN
**対象 SEQD**: SEQD-<AREA>-NNN
**検査深度**: フル / 軽量(§14.2 リスク階層化)
**検査日**: YYYY-MM-DD
**Reviewer**: <AI Reviewer>

## 1. Abstract Responsibilities(UC ステップを一次アンカーとする)

| AR-ID | Source | Role | Subject | Responsibility | UC step |
|---|---|---|---|---|---|
| AR-001 | RBA | Boundary |  |  | UC-<AREA>-NNN Step _ |
| AR-002 | RBA | Control |  |  | UC-<AREA>-NNN Step _ |
| AR-003 | SEQA | Entity |  |  | UC-<AREA>-NNN Step _ |

> UC ステップに紐づかない AR が現れた場合、それは「構造翻訳が情報を加えた」兆候。§9 分解 (b) の候補。

## 2. Concrete Responsibilities

| CR-ID | Source | Class / Object | Operation | Responsibility | Message |
|---|---|---|---|---|---|
| CR-001 | RBD |  |  |  |  |
| CR-002 | SEQD |  |  |  |  |

## 3. Responsibility Mapping

| AR-ID | CR-ID(s) | Relation | Justification | Verdict |
|---|---|---|---|---|
| AR-001 | CR-001 | preserved |  | GREEN |
| AR-002 | CR-002, CR-003 | split |  | GREEN / RED |

関係値: `preserved / split / merged / shifted / lost / invented / mutated / ambiguous`

## 4. Role Fitness Check(§5.2)

### Boundary

- Finding:
- Severity:
- 原因の所在(具体側 / UC 側):
- Required action:

### Control

- Finding:
- Severity:
- 原因の所在(具体側 / UC 側):
- Required action:

### Entity

- Finding:
- Severity:
- 原因の所在(具体側 / UC 側):
- Required action:

## 5. Sequential Execution Check(§5.3)

### Basic Flow

| UC step | SEQA message | SEQD message | Responsibility valid? | Notes |
|---|---|---|---|---|
| Step 1 |  |  | Yes / No |  |

### Alternative Flows

| UC step | SEQA message | SEQD message | Responsibility valid? | Notes |
|---|---|---|---|---|

### Exception Flows

| UC step | SEQA message | SEQD message | Responsibility valid? | Notes |
|---|---|---|---|---|

## 6. Mismatches

### Lost Responsibilities

- None / list

### Invented Responsibilities

- None / list

### Shifted Responsibilities

- None / list

### Mutated Responsibilities

- None / list

### Ambiguous Mappings(人間にはエスカレートしない。UC ステップ対応根拠を提示して再生成)

- None / list

## 7. Metrics(監視指標 — 合否は §7 の絶対条件で判定する)

| Metric | Value |
|---|---:|
| Total abstract responsibilities |  |
| Preserved |  |
| Justified split |  |
| Justified merge |  |
| Lost |  |
| Shifted |  |
| Mutated |  |
| Ambiguous |  |
| Preservation rate(監視用) |  |
| Invented concrete responsibilities |  |
| Total concrete responsibilities |  |
| Invention rate(監視用) |  |

## 8. 絶対条件ゲート(§7)

- [ ] lost = 0
- [ ] mutated = 0
- [ ] shifted = 0
- [ ] ambiguous = 0(解消済)
- [ ] 未正当化 invented = 0
- [ ] 未正当化 split / merge = 0
- [ ] B/C/E 責務違反なし
- [ ] UC 基本/代替/例外フローが具体側で実行可能

## 9. Required Changes

- [ ] <修正項目 1>(原因の所在: 具体側 → AI 自律修正 / UC 側 → SPEC/UC 遡及)
- [ ] <修正項目 2>

## 10. Verdict(§9 規律)

- 保存失敗なし → APPROVE
- 具体側逸脱(UC は正しい) → REQUEST_CHANGES(AI が RBD/SEQD 再生成)
- ambiguous 残存 → REQUEST_CHANGES(AI が UC 対応根拠提示)
- 保存失敗が UC 自体の不備を露呈 → NEEDS_HUMAN(本文に遡及理由を必須記述)

<!-- VERDICT:APPROVE -->
<!-- VERDICT:REQUEST_CHANGES -->
<!-- VERDICT:NEEDS_HUMAN -->
