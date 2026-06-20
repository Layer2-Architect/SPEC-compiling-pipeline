# 言語別ガイド: Python

このドキュメントは Python で SCP を運用するときの DD / TC / SRC の規律をまとめる。

## 1. プロジェクト構成

```
.
├── pyproject.toml
├── .legixy.toml
├── CLAUDE.md
├── docs/...
├── scripts/trace-check.sh
├── src/myproj/
│   └── *.py                    # """Document ID: SRC-<AREA>-NNN"""
├── tests/
│   └── *.py                    # """Document ID: TC-<AREA>-NNN"""
└── bench/                      # pytest-benchmark の測定
```

`.legixy.toml`:

```toml
[id.types.TC]
dir = "tests/"
ext = ".py"
file_pattern = "contains"

[id.types.SRC]
dir = "src/"
ext = ".py"
file_pattern = "contains"
```

## 2. pyproject.toml の最小構成

```toml
[project]
name = "myproj"
requires-python = ">=3.12"
dependencies = []

[tool.mypy]
strict = true
warn_unused_ignores = true
disallow_any_explicit = true

[tool.ruff]
line-length = 100
select = ["E", "F", "I", "B", "UP", "RUF"]

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-x --strict-markers"
```

`mypy --strict` は必須。Python は型注釈を入れないと SCP の決定論層規律が成立しない。

## 3. DD の決定論層特有事項

### 型注釈の活用

- 全関数に型注釈を入れる（`mypy --strict` で強制）
- `dataclass(frozen=True)` で immutability
- `Literal` / `NewType` / `TypeAlias` で意味的区別

```python
from typing import NewType, Literal
from dataclasses import dataclass

UserId = NewType("UserId", str)
OrderId = NewType("OrderId", str)


@dataclass(frozen=True, slots=True)
class User:
    id: UserId
    name: str
    role: Literal["admin", "member", "guest"]
```

### Tagged union（Python 3.12+）

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class Idle:
    kind: Literal["idle"] = "idle"

@dataclass(frozen=True)
class Loaded:
    kind: Literal["loaded"]
    data: Data

State = Idle | Loaded
```

`match` で exhaustive 判定:

```python
def render(s: State) -> str:
    match s:
        case Idle():
            return "..."
        case Loaded(data=data):
            return data.title
        case _:
            from typing import assert_never
            assert_never(s)
```

### Result 型

`returns` ライブラリ、または自前で:

```python
from dataclasses import dataclass
from typing import Generic, TypeVar

T = TypeVar("T")
E = TypeVar("E")

@dataclass(frozen=True)
class Ok(Generic[T]):
    value: T

@dataclass(frozen=True)
class Err(Generic[E]):
    error: E

Result = Ok[T] | Err[E]
```

`raise` を境界の外に出さない方針なら、Result 型で表現する。例外を使う方針でも、公開 API では発生しうる例外を明示する（コメントだけでなく型で扱える `returns` 推奨）。

### 非同期境界

- `async def` は `Result` 系または明示的例外を返す
- `asyncio.CancelledError` の伝播を明示
- backpressure は asyncio.Queue / aiostream

## 4. TC の規律（pytest + Hypothesis）

```python
# tests/test_state.py
"""Document ID: TC-<AREA>-001

親 TS: TS-<AREA>-001
"""

import pytest
from hypothesis import given, strategies as st
from myproj.state import State, StateError, sample_item, arb_item


def test_state_add_to_empty_returns_first_id():
    # @ts: TS-<AREA>-001 ケース 1
    s = State()
    result = s.add(sample_item())
    assert isinstance(result, Ok)
    assert result.value == 1
    assert s.count() == 1


@given(items=st.lists(arb_item(), max_size=100))
def test_count_is_monotonic(items):
    # @ts: TS-<AREA>-001 ケース 3 (property)
    s = State()
    prev = 0
    for it in items:
        s.add(it)
        assert s.count() >= prev
        prev = s.count()
```

### Fixture 規律

- DB / 外部 API は `pytest` fixture で interface 化
- `monkeypatch` は最後の手段。型レベル DI を優先
- snapshot test（syrupy）は意味のある assertion の代替にしない

## 5. SRC の規律

### 必須

- ファイル先頭の docstring 内に `Document ID: SRC-<AREA>-NNN`
- 全関数に型注釈
- 公開 API では `Any` 禁止
- mypy --strict pass

### 推奨

- `from __future__ import annotations` で前方参照
- `dataclass(frozen=True, slots=True)` を積極利用
- `pathlib.Path` を使う（生 string パス禁止）
- `enum.Enum` ではなく `Literal` または `StrEnum`（Python 3.11+）

### Errors / Exceptions

```python
class DomainError(Exception):
    """Base class for domain errors."""

class NotFoundError(DomainError):
    def __init__(self, id: str) -> None:
        super().__init__(f"not found: {id}")
        self.id = id

class InvalidError(DomainError):
    def __init__(self, field: str, reason: str) -> None:
        super().__init__(f"invalid {field}: {reason}")
        self.field = field
        self.reason = reason
```

公開 API のドキュメントで raises を明示。

## 6. CI 構成

```yaml
- name: Install
  run: pip install -e ".[dev]"

- name: Type check
  run: mypy src tests

- name: Lint
  run: ruff check src tests

- name: Format
  run: ruff format --check src tests

- name: Test
  run: pytest --cov=src

- name: Trace integrity
  run: bash scripts/trace-check.sh
```

## 7. NFR の測定

| NFR カテゴリ | 推奨ツール |
|---|---|
| 性能（latency / throughput）| pytest-benchmark / pyperf |
| メモリ | memray / tracemalloc |
| プロファイル | py-spy / cProfile + snakeviz |
| 並行性 | （asyncio / threading の特性に応じ）|
| 起動時間 | python -X importtime |

## 8. ありがちな落とし穴

- **`Any` で型を逃す**: 公開 API では禁止。`object` + isinstance か `TypeVar` 制約に
- **mutable default argument**: `def f(x=[])` は罠。`x: list[int] | None = None` に
- **`is` と `==` の混同**: 値比較は `==`、identity は `is`（None 比較のみ）
- **circular import**: 型のみ参照は `if TYPE_CHECKING:` で遅延
- **`__init__.py` の re-export 漏れ**: 公開 API surface を `__init__.py` で明示
- **scope leak**: `with` を使うべきリソース（ファイル・接続）を `with` で扱わない
- **GIL を忘れた並行性**: CPU bound は multiprocessing、I/O bound は asyncio / threading

## 9. ハードルール再掲（Python 視点）

- **テストが通らない実装はマージしない**（pytest pass + mypy --strict pass）
- **境界 API は DD で凍結**（公開関数のシグネチャを変更しない）
- **`Document ID:` 行の必置**（モジュール docstring 内）
- **`Any` 禁止 + mypy --strict**（型レベル invariant を維持）
