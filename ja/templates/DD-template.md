Document ID: DD-<AREA>-NNN

# DD-<AREA>-NNN: <タイトル>

**親 SEQ**: SEQ-<AREA>-MMM
**対象言語**: <Rust / TypeScript / Python / C# / 他>
**境界 API 凍結**: yes / no（yes の場合、本ドキュメントの確定後は変更不可。次バージョン SPEC で改訂）

> 言語別の詳細は `guides/language-stacks/<lang>.md` を参照。

## 1. 対象範囲

この DD が決定する範囲:

- module / package: <パス>
- 公開 API surface: <列挙 or 別ドキュメント参照>
- 関連 SEQ: SEQ-<AREA>-MMM

## 2. 型定義

### 2.1 主要データ型

```
<言語に応じた型定義>
struct / data class / type alias
- フィールド名: 型, 不変条件
- ...
```

### 2.2 列挙 / Sum 型

```
enum <Name> {
    Variant1(...),
    Variant2,
    ...
}
```

各 variant の意味と、不可能な状態を型で禁止していることを明示。

### 2.3 エラー型

```
enum <Name>Error {
    InvalidInput { field: String, reason: String },
    NotFound,
    Conflict { conflicting_id: Id },
    External { source: ... },
    ...
}
```

エラー型の階層・伝播方針・ユーザ通知への変換を記述。

## 3. 公開 API surface

| 関数 / メソッド | シグネチャ | 不変条件 | 冪等性 | 同期/非同期 |
|---|---|---|---|---|
| <name> | <fn name(arg: T) -> Result<U, E>> | <条件> | yes/no | 同期 |
| ... | ... | ... | ... | ... |

API surface はここで凍結する（ハードルール 7）。**API の追加** は許容、**削除・改名・型変更** は SPEC 改訂扱い。

## 4. module / package 構成

```
<root>/
├── <module1>/
│   ├── <file>.<ext>
│   └── ...
├── <module2>/
└── ...
```

各 module の責任範囲と依存方向（DAG であること）を記述。

## 5. ライフタイム / 所有権 / 借用 方針

（言語に応じて）

- Rust: ライフタイムの明示が必要な箇所、`'static` バウンドの理由、`Arc` / `Rc` / `Box` の使い分け
- TypeScript / Python: `Readonly<T>` / `frozen dataclass` の境界、共有参照の扱い
- C#: `IDisposable`, `using`, `record` vs `class` の使い分け

## 6. エラー伝播戦略

- 内部エラー → 公開エラー型への変換ルール
- 部分成功時の扱い（ロールバック / 部分コミット）
- panic / unhandled exception の禁止 + どこで catch するか

## 7. 並行性 / 非同期境界

- async / sync の境界
- スレッド契約（呼び出してよいスレッド・いけないスレッド）
- Cancellation 伝播
- バックプレッシャ・キューイング

## 8. テスト分類

| 分類 | 内容 | 対応 TP |
|---|---|---|
| Unit | <内容> | TP-<AREA>-NNN |
| Integration | <内容> | TP-<AREA>-MMM |
| Property-based | <内容> | TP-<AREA>-OOO |

## 9. ADR への参照

architectural な判断は ADR として独立記録:

- ADR-<AREA>-NNN: <判断タイトル>
- ADR-<AREA>-MMM: <判断タイトル>

## 10. 関連 NFR

- NFR-<AREA>-NNN: <性能要件>
- NFR-<AREA>-MMM: <並行性要件>

## 11. 凍結履歴

| Date | Version | Note |
|---|---|---|
| YYYY-MM-DD | 1.0 | 初版凍結 |
