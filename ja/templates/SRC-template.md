# SRC（実装コード）テンプレート

> SRC は **TC[RED] を通す最小実装**。コードファイル先頭に `Document ID: SRC-<AREA>-NNN` を必置（`file_pattern = "contains"`）。

言語ごとの雛形を以下に並記する。詳細は `guides/language-stacks/<lang>.md`。

## Rust

```rust
//! Document ID: SRC-<AREA>-NNN
//!
//! 親 TC: TC-<AREA>-MMM
//! 親 DD: DD-<AREA>-OOO

use thiserror::Error;

#[derive(Debug, PartialEq, Error)]
pub enum StateError {
    #[error("not found")]
    NotFound,
    #[error("invalid input: {0}")]
    Invalid(String),
}

pub type Result<T> = std::result::Result<T, StateError>;

pub struct State {
    items: Vec<Item>,
}

impl State {
    pub fn new() -> Self {
        Self { items: Vec::new() }
    }

    pub fn add(&mut self, item: Item) -> Result<ItemId> {
        // 最小実装: TC[GREEN] になるだけ
        let id = ItemId::new(self.items.len() as u64 + 1);
        self.items.push(item);
        Ok(id)
    }

    pub fn count(&self) -> usize {
        self.items.len()
    }
}
```

## TypeScript

```typescript
// Document ID: SRC-<AREA>-NNN
// 親 TC: TC-<AREA>-MMM
// 親 DD: DD-<AREA>-OOO

export type Result<T, E> =
  | { ok: true; value: T }
  | { ok: false; error: E };

export enum StateError {
  NotFound = 'NOT_FOUND',
  Invalid = 'INVALID',
}

export class State {
  private items: Item[] = [];

  add(item: Item): Result<number, StateError> {
    const id = this.items.length + 1;
    this.items.push(item);
    return { ok: true, value: id };
  }

  count(): number {
    return this.items.length;
  }
}
```

## Python

```python
"""Document ID: SRC-<AREA>-NNN

親 TC: TC-<AREA>-MMM
親 DD: DD-<AREA>-OOO
"""
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from typing import Generic, TypeVar

T = TypeVar("T")
E = TypeVar("E")


class StateError(Enum):
    NOT_FOUND = "not_found"
    INVALID = "invalid"


@dataclass(frozen=True)
class Result(Generic[T, E]):
    ok: bool
    value: T | None = None
    error: E | None = None


@dataclass
class State:
    items: list[Item] = field(default_factory=list)

    def add(self, item: Item) -> Result[int, StateError]:
        new_id = len(self.items) + 1
        self.items.append(item)
        return Result(ok=True, value=new_id)

    def count(self) -> int:
        return len(self.items)
```

## C# / .NET

```csharp
// Document ID: SRC-<AREA>-NNN
// 親 TC: TC-<AREA>-MMM
// 親 DD: DD-<AREA>-OOO

namespace MyProj;

public enum StateError { NotFound, Invalid }

public readonly record struct Result<T, E>(bool IsOk, T? Value, E? Error)
{
    public bool IsErr => !IsOk;
    public static Result<T, E> Ok(T v) => new(true, v, default);
    public static Result<T, E> Err(E e) => new(false, default, e);
}

public class State
{
    private readonly List<Item> _items = new();

    public Result<int, StateError> Add(Item item)
    {
        var id = _items.Count + 1;
        _items.Add(item);
        return Result<int, StateError>.Ok(id);
    }

    public int Count => _items.Count;
}
```

## 共通の規律

- ファイル先頭に `Document ID: SRC-<AREA>-NNN` 行
- 公開関数は `Result<T, E>` 相当を返す（成功 / 失敗を型で区別）
- panic / unhandled exception を本番コードに残さない（テスト・ビルドスクリプトを除く）
- 過剰実装しない（「次のテストで使うかも」を理由に機能を加えない）
- リファクタリングは GREEN を確認してから
- `unsafe` / native interop / `unchecked` は局所化し、安全性条件をコメントで明示
- TODO / FIXME を残すなら関連 GAP / NFR の ID を併記
