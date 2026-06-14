# 言語別ガイド: TypeScript

このドキュメントは TypeScript で SCP を運用するときの DD / TC / SRC の規律をまとめる。

## 1. プロジェクト構成

```
.
├── package.json
├── tsconfig.json
├── .trace-engine.toml
├── CLAUDE.md
├── docs/...
├── scripts/trace-check.sh
├── src/
│   └── *.ts                    // Document ID: SRC-<AREA>-NNN
├── tests/
│   └── *.test.ts               // Document ID: TC-<AREA>-NNN
└── bench/                      // NFR 測定（vitest bench / tinybench）
```

`.trace-engine.toml`:

```toml
[id.types.TC]
dir = "tests/"
ext = ".ts"
file_pattern = "contains"

[id.types.SRC]
dir = "src/"
ext = ".ts"
file_pattern = "contains"
```

## 2. tsconfig.json の最小構成

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "exactOptionalPropertyTypes": true,
    "verbatimModuleSyntax": true,
    "isolatedModules": true,
    "moduleResolution": "Bundler"
  }
}
```

`strict: true` + `noUncheckedIndexedAccess` は必須。型レベル invariant の保証が大きく変わる。

## 3. DD の決定論層特有事項

### 型レベル invariant

- branded types で意味的に異なる ID を区別:
  ```typescript
  type UserId = string & { readonly __brand: 'UserId' };
  type OrderId = string & { readonly __brand: 'OrderId' };
  ```
- discriminated union で状態の網羅性を確保:
  ```typescript
  type State =
    | { kind: 'idle' }
    | { kind: 'loading' }
    | { kind: 'loaded'; data: Data }
    | { kind: 'error'; error: AppError };
  ```
- exhaustive switch で `never` チェック:
  ```typescript
  function render(s: State): string {
    switch (s.kind) {
      case 'idle': return '...';
      case 'loading': return '...';
      case 'loaded': return s.data.title;
      case 'error': return s.error.message;
      default: { const _exhaustive: never = s; return _exhaustive; }
    }
  }
  ```

### Result 型の採用

`throw` を境界の外に漏らさない。Result 型で成功 / 失敗を表現:

```typescript
export type Result<T, E> =
  | { ok: true; value: T }
  | { ok: false; error: E };

export const ok = <T>(value: T): Result<T, never> => ({ ok: true, value });
export const err = <E>(error: E): Result<never, E> => ({ ok: false, error });
```

または `neverthrow` 等のライブラリ。

### エラー型階層

```typescript
export type DomainError =
  | { kind: 'NotFound'; id: string }
  | { kind: 'Invalid'; field: string; reason: string }
  | { kind: 'Conflict'; conflicting: string };
```

`Error` クラスを継承する場合は `cause` を活用してチェーン保持。

### 非同期境界

- `async function` は `Promise<Result<T, E>>` を返す（`throw` させない）
- `AbortSignal` でキャンセル伝播を明示
- backpressure を扱うなら AsyncIterable / streams を選択

## 4. TC の規律（Vitest + fast-check）

```typescript
// tests/state.test.ts
// Document ID: TC-<AREA>-001
// 親 TS: TS-<AREA>-001

import { describe, expect, test } from 'vitest';
import * as fc from 'fast-check';
import { State, StateError } from '../src/state.js';

describe('State', () => {
  test('add to empty returns first id', () => {
    // @ts: TS-<AREA>-001 ケース 1
    const s = new State();
    const result = s.add(sampleItem());
    expect(result).toEqual({ ok: true, value: 1 });
    expect(s.count()).toBe(1);
  });

  test.prop([fc.array(arbItem(), { maxLength: 100 })])(
    'count is monotonic',
    (items) => {
      // @ts: TS-<AREA>-001 ケース 3 (property)
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

### モック方針

- 内部モジュールはモック禁止（型と Result で表現する）
- 外部依存（fetch / DB）は interface 化して dependency injection
- vi.mock は最後の手段。`vi.spyOn` も避ける

## 5. SRC の規律

### 必須

- ファイル先頭に `// Document ID: SRC-<AREA>-NNN`
- 公開関数は `Result<T, E>` 相当を返す（throw を境界に漏らさない）
- `any` 禁止（`unknown` を使い、型ガードで絞る）
- `as` キャスト禁止（型ガードまたは zod 等で実行時検証）

### 推奨

- `Readonly<T>`, `ReadonlyArray<T>` を積極利用
- `interface` より `type` を優先（union / intersection の柔軟性）
- 副作用は明示的（純関数中心）
- ESM only（CommonJS 互換は package.json で明示）

### lint / format

- `eslint` + `@typescript-eslint/recommended-type-checked`
- `prettier` で format 統一
- `no-floating-promises` 必須（async の取りこぼし防止）

## 6. CI 構成

```yaml
- name: Install
  run: npm ci

- name: Type check
  run: npx tsc --noEmit

- name: Lint
  run: npx eslint .

- name: Test
  run: npx vitest run --coverage

- name: Format
  run: npx prettier --check .

- name: Trace integrity
  run: bash scripts/trace-check.sh
```

## 7. NFR の測定

| NFR カテゴリ | 推奨ツール |
|---|---|
| 性能（latency / throughput）| vitest bench / tinybench |
| メモリ | clinic.js / heapdump |
| 並行性 | （Node 単一スレッド前提 / Worker thread 別途）|
| ロード時間（バンドル）| esbuild --metafile / source-map-explorer |
| プロファイル | --inspect → Chrome DevTools / 0x |

## 8. ありがちな落とし穴

- **`any` で型を逃す**: `unknown` + 型ガードに置換
- **`as` キャストで境界を破る**: zod / valibot で実行時検証
- **`Promise` をハンドルし忘れる**: `no-floating-promises` を eslint で強制
- **`null` と `undefined` の混在**: `exactOptionalPropertyTypes` で区別を強制
- **mutable object の共有**: `Readonly<T>` を積極利用、structural sharing
- **enum の罠**: TypeScript の `enum` は予期せぬ挙動。`as const` オブジェクトを推奨
- **`==` の使用**: 必ず `===`（eslint で強制）

## 9. ハードルール再掲（TypeScript 視点）

- **テストが通らない実装はマージしない**（vitest run pass + tsc --noEmit pass）
- **境界 API は DD で凍結**（公開 export の型シグネチャを変更しない）
- **`Document ID:` 行の必置**
- **`any` / `as` 禁止**（強制的に型レベル invariant を維持）
