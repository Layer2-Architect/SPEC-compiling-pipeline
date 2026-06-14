# TC（テストコード）テンプレート

> TC は **TS の機械実行可能なテストへの翻訳**。コードファイル先頭に `Document ID: TC-<AREA>-NNN` を必置（`file_pattern = "contains"`）。

言語ごとの雛形を以下に並記する。すべて **TC[RED] を先に書き、失敗を確認してから SRC に進む**（ハードルール）。

## Rust（cargo test）

```rust
//! Document ID: TC-<AREA>-NNN
//!
//! 親 TS: TS-<AREA>-MMM

use proptest::prelude::*;

#[test]
fn test_<feature>_<scenario>_<expected>() {
    // @ts: TS-<AREA>-MMM ケース 1
    let mut s = State::new();
    let result = s.add(Item::sample());
    assert_eq!(result, Ok(ItemId::new(1)));
    assert_eq!(s.count(), 1);
}

#[test]
fn test_<feature>_empty_input_returns_err() {
    // @ts: TS-<AREA>-MMM ケース 2
    let mut s = State::new();
    let result = s.remove(ItemId::new(0));
    assert_eq!(result, Err(StateError::NotFound));
}

proptest! {
    #[test]
    fn prop_count_is_monotonic(items in prop::collection::vec(any::<Item>(), 0..100)) {
        // @ts: TS-<AREA>-MMM ケース 3 (property)
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

## TypeScript（Vitest + fast-check）

```typescript
// Document ID: TC-<AREA>-NNN
// 親 TS: TS-<AREA>-MMM

import { describe, expect, test } from 'vitest';
import * as fc from 'fast-check';
import { State, StateError } from '../src/state';

describe('State', () => {
  test('add to empty state returns first id', () => {
    // @ts: TS-<AREA>-MMM ケース 1
    const s = new State();
    const result = s.add(sampleItem());
    expect(result).toEqual({ ok: true, value: 1 });
    expect(s.count()).toBe(1);
  });

  test('remove from empty returns NotFound', () => {
    // @ts: TS-<AREA>-MMM ケース 2
    const s = new State();
    const result = s.remove(0);
    expect(result).toEqual({ ok: false, error: StateError.NotFound });
  });

  test.prop([fc.array(arbItem(), { minLength: 0, maxLength: 100 })])(
    'count is monotonic',
    (items) => {
      // @ts: TS-<AREA>-MMM ケース 3 (property)
      const s = new State();
      let prev = 0;
      for (const it of items) {
        s.add(it);
        expect(s.count()).toBeGreaterThanOrEqual(prev);
        prev = s.count();
      }
    },
  );
});
```

## Python（pytest + Hypothesis）

```python
# Document ID: TC-<AREA>-NNN
# 親 TS: TS-<AREA>-MMM

import pytest
from hypothesis import given, strategies as st
from myproj.state import State, StateError, sample_item, arb_item


def test_state_add_to_empty_returns_first_id():
    # @ts: TS-<AREA>-MMM ケース 1
    s = State()
    result = s.add(sample_item())
    assert result.ok and result.value == 1
    assert s.count() == 1


def test_state_remove_from_empty_returns_not_found():
    # @ts: TS-<AREA>-MMM ケース 2
    s = State()
    result = s.remove(0)
    assert not result.ok and result.error is StateError.NotFound


@given(items=st.lists(arb_item(), min_size=0, max_size=100))
def test_count_is_monotonic(items):
    # @ts: TS-<AREA>-MMM ケース 3 (property)
    s = State()
    prev = 0
    for it in items:
        s.add(it)
        assert s.count() >= prev
        prev = s.count()
```

## C# / .NET（xUnit + FsCheck）

```csharp
// Document ID: TC-<AREA>-NNN
// 親 TS: TS-<AREA>-MMM

using FsCheck;
using FsCheck.Xunit;
using Xunit;

public class StateTests
{
    [Fact]
    public void Add_ToEmpty_ReturnsFirstId()
    {
        // @ts: TS-<AREA>-MMM ケース 1
        var s = new State();
        var result = s.Add(SampleItem());
        Assert.True(result.IsOk);
        Assert.Equal(1, result.Value);
        Assert.Equal(1, s.Count);
    }

    [Fact]
    public void Remove_FromEmpty_ReturnsNotFound()
    {
        // @ts: TS-<AREA>-MMM ケース 2
        var s = new State();
        var result = s.Remove(0);
        Assert.True(result.IsErr);
        Assert.Equal(StateError.NotFound, result.Error);
    }

    [Property]
    public Property Count_IsMonotonic(Item[] items)
    {
        // @ts: TS-<AREA>-MMM ケース 3 (property)
        var s = new State();
        var prev = 0;
        foreach (var it in items)
        {
            s.Add(it);
            if (s.Count < prev) return false.ToProperty();
            prev = s.Count;
        }
        return true.ToProperty();
    }
}
```

## 共通の規律

- ファイル先頭に `Document ID: TC-<AREA>-NNN` 行
- 各テスト関数の冒頭コメントで `// @ts: TS-<AREA>-MMM ケース N` を引用
- 命名は `test_<feature>_<scenario>_<expected>`（言語慣習に合わせて調整）
- assertion は具体的期待値（`is_ok()` だけでなく `== Ok(expected)`）
- TS の各ケースに 1:1 対応（カバレッジ表で確認）
- TC[RED] が「未実装」起因で失敗することを `cargo test` 等で確認してから SRC へ
