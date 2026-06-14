Document ID: TS-<AREA>-NNN

# TS-<AREA>-NNN: <タイトル>

> TS は **上流 TP の翻訳**。ゼロから観点を考えない（→ `03-spec-level-tdd.md` §1）。

**親 DD**: DD-<AREA>-MMM
**継承 TP**: TP-<AREA>-NNN, TP-<AREA>-MMM, ...

## 1. 対象範囲

このテスト仕様がカバーする DD の関数 / 型:

- DD-<AREA>-MMM §<番号> の `<関数名>`

## 2. ケース一覧

### ケース 1: <観点を 1 行で>

- **観点出典**: TP-<AREA>-NNN §2.1 観点 1（境界値: 空入力）
- **分類**: Unit / Integration / Property
- **前提**:
  - <前提条件 1>
  - <前提条件 2>
- **入力**:
  ```
  <型に沿った具体値>
  ```
- **期待**:
  ```
  <Ok / Err / 戻り値の具体値>
  ```
- **境界条件**: <この観点が捉える境界の説明>

### ケース 2: <観点を 1 行で>

- **観点出典**: TP-<AREA>-NNN §2.1 観点 2
- **分類**: Unit
- **前提**: ...
- **入力**: ...
- **期待**: ...

### ケース 3: <Property test>

- **観点出典**: TP-<AREA>-NNN §2.4 観点（並行性: count の単調性）
- **分類**: Property-based
- **生成器**: `Vec<Item>` （任意の長さ・要素）
- **不変条件**: 任意の操作列 `ops` について、`count` は単調非減少
- **反例ハンドリング**: 反例が出たら shrink して最小例を記録

## 3. 観点カバレッジ表

| TP § | 観点 | カバーする TS ケース |
|---|---|---|
| TP-<AREA>-NNN §2.1 観点 1 | 境界値（空入力）| ケース 1 |
| TP-<AREA>-NNN §2.1 観点 2 | 境界値（最大）| ケース 2 |
| TP-<AREA>-NNN §2.4 観点 | 並行性 | ケース 3（property）|
| ... | ... | ... |

すべての継承 TP 観点が、このテーブルで TS ケースに mapping されていることを確認（人間ゲート判断）。

## 4. テスト技法選択

- 同値分割: <どの入力空間に適用したか>
- 境界値分析: <どの境界に適用したか>
- Property-based: <どの不変条件を property 化したか>
- 状態遷移: <どの状態機械を網羅したか>

## 5. テスト基盤

- 言語: <Rust / TypeScript / Python / C#>
- フレームワーク: <cargo test / vitest / pytest / xUnit>
- Property-based: <proptest / fast-check / hypothesis / FsCheck>
- モック: <なし / どこで使うか>

## 6. 関連 TC

| TS ケース | 対応 TC | 場所 |
|---|---|---|
| ケース 1 | TC-<AREA>-NNN | tests/<file>.<ext> |
| ケース 2 | TC-<AREA>-MMM | tests/<file>.<ext> |
