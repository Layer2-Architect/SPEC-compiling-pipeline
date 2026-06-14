# 05 — テストと実装（TS / TC / SRC）

このドキュメントは TS, TC, SRC の作業時に参照する。

> 本章は**機能軸**（UC→…→SRC）の TS/TC/SRC を扱う。成果物が**配送サーフェス**（CLI/API/MCP の境界＝実バイナリ／
> エンドポイント）の場合は、別 area の**配送軸**（CTR→DLV→TS→TC→SRC）上にも TS/TC[DLV]/SRC を持つ。
> 手順・ゲート（実バイナリ E2E、契約↔TC mapping、WARN-escalate）は `12-delivery-layer.md` を参照。

## 1. 前提条件

- DD が確定し、`legixy check --formal` が pass している
- 上流の TP[SPEC] / TP[UC] の全観点が GREEN
- 境界 API の契約が DD で凍結されている（ハードルール 7）

## 2. TS（テスト仕様）の生成

### 基本原則

**TS は上流 TP の翻訳である。** ゼロから観点を考えない。考えるべき観点は SPEC / UC レベルで既に確定している。TS は各 TP 観点を、DD で定義された型・関数シグネチャに即した具体的な入力・期待出力・前提条件に展開する。

### TS が含めるもの

- 各 TP 観点の具体化（入力・期待出力・前提条件）
- DD で定義された型・関数シグネチャに即した記述
- テスト分類（unit / integration / property-based / contract test）
- 同値分割と境界値の明示

### TS 構造（テンプレ: `templates/TS-template.md`）

```markdown
Document ID: TS-<AREA>-001

# TS-<AREA>-001: <タイトル>

**親 DD**: DD-<AREA>-NNN
**継承 TP**: TP-<AREA>-001, TP-<AREA>-006

## ケース 1: <観点を 1 行で>

**観点出典**: TP-<AREA>-001 「空状態の操作」
**前提**: <前提条件>
**入力**: <型に沿った具体値>
**期待**: <Ok / Err / 戻り値の具体値>
**境界条件**: <この観点が捉える境界>

## ケース 2: ...
```

### TS 生成時の規律

- TP の観点 1 つにつき TS のケースを最低 1 つ作る
- 観点が境界値カテゴリなら、上限 / 下限 / 0 / 負 / 最大 / 最大+1 を別ケースに分ける
- 同値分割は型に閉じ込める（`Result<T, E>` の `Ok` 系と `Err` 系を別ケース）
- property-based testing が適切な領域は **property** として書く（個別ケース列挙でなく不変条件として）

## 3. TC（テストコード）

### 書き順

**必ず TC[RED] を先に書く。** 実装より先にテストを書き、失敗することを確認してから、TC[GREEN] になる最小実装を書く。

```bash
# 例: Rust
cargo test --no-run     # コンパイルが通る（型レベルでは正しい）
cargo test              # テストが失敗する（実装がまだ無い）
```

```bash
# 例: TypeScript
npx tsc --noEmit         # 型チェックは通る
npx vitest run           # テストが失敗する
```

### TC 生成時の規律

- TS の各テストケースに 1:1 対応する TC を生成
- TC ファイル先頭には `Document ID: TC-<AREA>-NNN` を必置（`file_pattern = "contains"`）
- TC 関数の冒頭コメントで TS を引用（例: `// @ts: TS-<AREA>-001 ケース 1`）
- 命名は `test_<feature>_<scenario>_<expected>` 形式（言語の慣習に合わせて調整可）
- assertion は具体的な期待値を持つ
  - NG: `assert!(result.is_ok())`
  - OK: `assert_eq!(result, Ok(expected_value))`

### Property-based testing

決定論的領域では proptest / quickcheck / fast-check / hypothesis 等の積極利用を推奨。境界値を網羅的に攻めるため、TP の観点を property 化できるなら優先する。

```rust
// Rust: proptest 例
proptest! {
    #[test]
    fn count_is_monotonic(items in any::<Vec<Item>>()) {
        let mut s = State::new();
        let mut prev = 0;
        for it in items {
            s.add(it);
            assert!(s.count() >= prev);
            prev = s.count();
        }
    }
}
```

```typescript
// TypeScript: fast-check 例
test.prop([fc.array(fc.anything())])('count is monotonic', (items) => {
  const s = new State();
  let prev = 0;
  for (const it of items) {
    s.add(it);
    expect(s.count()).toBeGreaterThanOrEqual(prev);
    prev = s.count();
  }
});
```

```python
# Python: hypothesis 例
@given(st.lists(item_strategy()))
def test_count_is_monotonic(items):
    s = State()
    prev = 0
    for it in items:
        s.add(it)
        assert s.count() >= prev
        prev = s.count()
```

言語別の詳細は `guides/language-stacks/` 参照。

## 4. SRC（実装）

### 書き順

TC[RED] が確認できたら、**TC[GREEN] になる最小実装** を書く。

- 過剰実装しない
- 「次のテストで使うかも」を理由に余計な機能を加えない
- リファクタリングは GREEN を確認してから

### 共通の規律（言語非依存）

- 公開関数 / メソッドは全て `Result<T, E>` 相当（成功 / 失敗を型レベルで区別する）または不可侵な型を返す
- panic / unhandled exception を本番コードに残さない
- 型レベル invariant で表現できることはコメントでなく型で表現する
- TODO / FIXME を残すなら関連 GAP / NFR の ID を併記
- ファイル先頭に `Document ID: SRC-<AREA>-NNN` を必置（`file_pattern = "contains"`）

### 言語別の詳細

| 言語 | ガイド |
|---|---|
| Rust | `guides/language-stacks/rust.md` |
| TypeScript | `guides/language-stacks/typescript.md` |
| Python | `guides/language-stacks/python.md` |
| C# / .NET | `guides/language-stacks/csharp.md` |

## 5. AI による生成と人間レビューの分担

### AI が生成しても良いもの

- TS の初稿（TP からの翻訳）
- TC の初稿（TS からの変換）
- SRC の本体（TC を通す最小実装）

### 人間が必ず確認するもの

- TS の観点漏れ（TP の観点が全て TS に展開されているか）
- TC のコメントによる TS 引用が正確か
- SRC の architectural decision（型設計、module 境界、エラー型の選択、API surface）
- FFI 境界のシグネチャと marshalling
- 並行性・性能特性（NFR と照合）
- `unsafe` ブロックの安全性
- compiler warning / lint のゼロ化

### 人間が読むのは diagonal review

行単位で網羅 review する必要は無いが、**diagonal に読む** 作業は省略不可。具体的には:

- module 構成と公開 API surface の確認（5〜10 分）
- FFI 境界のコード（行単位 review）
- benchmark / profile 結果の確認
- compiler warning / lint のゼロ化

## 6. リファクタリング

GREEN 確認後にリファクタリングする。リファクタリングの規律:

- 既存 TC を 1 つも壊さない
- 公開 API surface を変えない（変えるなら DD 改訂）
- リファクタリング後も `bash scripts/trace-check.sh` が pass

リファクタリングで型レベル invariant を強化できた場合（`Option<T>` を `NonEmpty<T>` にする等）、関連 TC が冗長になっていないか確認。冗長 TC は型システムが代替するので削除可。

## 7. SRC コミット後の検証

```bash
# 全テスト実行（言語に応じたコマンド）
cargo test                    # Rust
npx vitest run                # TypeScript / Vitest
pytest                        # Python
dotnet test                   # C#

# trace 整合性チェック
bash scripts/trace-check.sh   # 第 1 層 + SPEC レベル TDD ゲート
legixy check     # 第 2 層 semantic（ONNX モデル配置時のみ）
```

これが pass しない場合、チェーンのどこかで参照が壊れている。修正してから次の TC / SRC サイクルに進む。

## 8. NFR / AT との関係

NFR（性能・並行性・リソース・セキュリティ）は SRC の正しさとは別軸。SRC が GREEN でも NFR 違反は別問題。NFR 違反時の扱いは `07-at-and-nfr.md` 参照。

AT（受け入れテスト）は SRC が完成してから人間中心で実施する独立検証。AT で発見された問題は **新しい GAP[UC] / GAP[SPEC]** として記録し、観点ナレッジベースに昇格させる。

## 9. ハードルール再掲

- **テストが通らない実装はマージしない**（ハードルール 8）
- **仕様書とテストコードは実装着手後に変更しない**（ハードルール 6）
  - 実装がテストに合わせる、ではなく **テストを実装に合わせてはならない**
- **境界 API の契約は DD 段階で凍結**（ハードルール 7）
  - 凍結後の変更は次バージョンの SPEC 改訂として扱う
