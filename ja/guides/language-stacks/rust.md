# 言語別ガイド: Rust

このドキュメントは Rust で SCP を運用するときの DD / TC / SRC の規律をまとめる。

## 1. プロジェクト構成

```
.
├── Cargo.toml
├── .legixy.toml
├── CLAUDE.md
├── docs/
│   ├── SCP/                # フレームワーク本体
│   ├── specs/, usecases/, ...  # 各成果物
│   └── traceability/graph.toml
├── scripts/
│   └── trace-check.sh
├── src/
│   └── lib.rs                  # // Document ID: SRC-<AREA>-001
├── tests/
│   └── ...                     # // Document ID: TC-<AREA>-001
└── benches/                    # NFR の測定コード
```

`.legixy.toml` の TC / SRC 設定:

```toml
[id.types.TC]
dir = "tests/"
ext = ".rs"
file_pattern = "contains"

[id.types.SRC]
dir = "src/"
ext = ".rs"
file_pattern = "contains"
```

## 2. DD の決定論層特有事項

### 型レベル invariant

- 不正な状態を型で禁止する。`Option<NonZeroU32>` / `NonEmpty<T>` / `Validated<T>` 等
- enum で状態の網羅性を確保（match の exhaustive チェックを利用）
- newtype パターンで意味的に異なる ID を区別（`UserId` vs `OrderId` を `u64` で混同しない）

### エラー型階層

- `thiserror` でエラー型を定義
- 公開エラーは `enum` で variant を明示（`Box<dyn Error>` で済まさない）
- ライブラリ間の `From` 変換を明示（`?` でうっかり混入しない）

```rust
#[derive(Debug, thiserror::Error)]
pub enum DomainError {
    #[error("not found: {0}")]
    NotFound(String),
    #[error("invalid: {field}: {reason}")]
    Invalid { field: String, reason: String },
    #[error("conflict")]
    Conflict,
}
```

### ライフタイム / 所有権

- 公開 API はライフタイム明示が必要なら `<'a>` を書く（`'static` で逃げない）
- `Arc` / `Rc` / `Box` の使い分けを DD で記述
- borrowed slice (`&[T]`, `&str`) を優先、`Vec<T>` / `String` は所有権を移すケースに限る

### FFI 境界

- `extern "C"` シグネチャは DD で凍結
- `repr(C)` 構造体のフィールド順序・パディングを明示
- 全 FFI 関数を `catch_unwind` でラップ（panic を across-FFI させない）
- opaque handle パターンを推奨（C 側に Rust の構造体を渡さない）

## 3. TC の規律

### 基本テスト

```rust
//! Document ID: TC-<AREA>-001
//!
//! 親 TS: TS-<AREA>-001

use myproj::*;

#[test]
fn test_state_add_to_empty_returns_first_id() {
    // @ts: TS-<AREA>-001 ケース 1
    let mut s = State::new();
    let result = s.add(Item::sample());
    assert_eq!(result, Ok(ItemId::new(1)));
    assert_eq!(s.count(), 1);
}
```

### Property-based testing（proptest）

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn prop_count_is_monotonic(items in prop::collection::vec(arb_item(), 0..100)) {
        // @ts: TS-<AREA>-001 ケース 3 (property)
        let mut s = State::new();
        let mut prev = 0;
        for it in items {
            let _ = s.add(it);
            prop_assert!(s.count() >= prev);
            prev = s.count();
        }
    }
}
```

### 並行性テスト（loom）

```rust
#[cfg(loom)]
mod loom_tests {
    use loom::sync::Arc;
    use loom::thread;
    use super::*;

    #[test]
    fn no_data_race() {
        // @ts: TS-<AREA>-002 並行性ケース
        loom::model(|| {
            let s = Arc::new(...);
            let s1 = s.clone();
            let h = thread::spawn(move || s1.add(...));
            s.add(...);
            h.join().unwrap();
        });
    }
}
```

### ベンチマーク（criterion、NFR 用）

```rust
// benches/state_ops.rs
use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn bench_add(c: &mut Criterion) {
    c.bench_function("State::add", |b| {
        let mut s = State::new();
        b.iter(|| s.add(black_box(Item::sample())));
    });
}

criterion_group!(benches, bench_add);
criterion_main!(benches);
```

## 4. SRC の規律

### 必須

- ファイル先頭に `//! Document ID: SRC-<AREA>-NNN`
- 公開関数は `Result<T, E>` を返す（panic / unwrap 禁止）
- `unwrap()` / `expect()` は本番コードに残さない（テスト・ビルドスクリプトを除く）
- `unsafe` ブロックは必ず安全性条件をコメントで明示

### 推奨

- `#[must_use]` を効果のある関数に付ける
- `#[deny(unsafe_op_in_unsafe_fn)]` を有効化
- `clippy::pedantic` を CI で有効化、warning ゼロを維持
- `cargo doc` で公開 API のドキュメントを生成

### `unsafe` の局所化

```rust
/// SAFETY: caller must ensure that `ptr` is non-null and points to a
/// `repr(C)` struct of type `Foo` initialized within Rust's borrow rules.
pub unsafe fn from_raw(ptr: *const Foo) -> &'static Foo {
    // SAFETY: see function docs
    &*ptr
}
```

## 5. CI 構成

```yaml
# .github/workflows/rust.yml
- name: Build
  run: cargo build --all-targets

- name: Test
  run: cargo test --all-targets

- name: Lint (clippy)
  run: cargo clippy --all-targets -- -D warnings

- name: Format
  run: cargo fmt --check

- name: Trace integrity
  run: bash scripts/trace-check.sh
```

## 6. NFR の測定

| NFR カテゴリ | 推奨ツール |
|---|---|
| 性能（latency / throughput）| criterion |
| メモリ | dhat-rs / heaptrack |
| 並行性 | loom（model checking）|
| FFI 性能 | criterion + black_box でマーシャリング込み計測 |
| プロファイル | cargo flamegraph / perf |

## 7. ありがちな落とし穴

- **`anyhow::Error` を公開 API に出す**: ライブラリの公開境界では `thiserror` で具体型に
- **`async fn` の中で `.await` し忘れ**: clippy の `must_use` で検出
- **`Arc<Mutex<T>>` の濫用**: 多くの場合 `parking_lot::Mutex` か `RwLock` が適切。並行性 DD で選択を明示
- **`Drop` 実装で panic させる**: `Drop::drop` 内では panic 禁止。例外的に必要なら `std::process::abort()` を選ぶ
- **trait object の濫用**: 静的ディスパッチで済むなら generic、明確な使い分けを DD に書く

## 8. ハードルール再掲（Rust 視点）

- **テストが通らない実装はマージしない**（cargo test pass）
- **境界 API は DD で凍結**（`extern "C"` シグネチャ・`repr(C)` レイアウトを変更しない）
- **`Document ID:` 行の必置**（src/, tests/, benches/ の各ファイル先頭）
