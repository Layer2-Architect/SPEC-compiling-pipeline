Document ID: DLV-<SURFACE>-NNN

# DLV-<SURFACE>-NNN: <配送サーフェスの dispatch 設計>

> DLV は配送軸（`12-delivery-layer.md`）の設計層（CTR の子、TS の親）。境界契約（CTR）の各公開単位を
> 機能軸のライブラリ SRC への dispatch にマップする設計。機能 DD の §8（CLI/統合の dispatch 記述）に
> 散在していたものの**集約点**。`<SURFACE>` は area code（例 `CLI` / `MCP`）。

**親 CTR**: CTR-<SURFACE>-NNN
**area**: <SURFACE>
**サーフェス source（SRC[DLV] が anchor する実体）**: 例 `crates/<cli>/src/main.rs` / `ts-mcp/src/index.ts`

## 1. dispatch マッピング（契約公開単位 → 機能 SRC）

| 公開単位 | 引数変換（パース/正規化） | 呼出す機能 API（SRC-<AREA>-NNN） | 出力整形 | 終了コード |
|---|---|---|---|---|
| | | | | |

## 2. グローバル処理

- グローバルオプションの解釈（例 `--project-root` / `--json` / `--models-dir`）:
- 設定読込（設定ファイル探索 → Config 反映。`12-delivery-layer.md` §6/§7）:
- 引数パーサ規約（使用法誤り = 規定の終了コード）:

## 3. エラー / 終了コード戦略

| 事象 | 終了コード | メッセージ規約 |
|---|---|---|
| 使用法誤り（パーサ層） | | |
| 実行時失敗 | | |
| 検証結果由来 | | |

## 4. 配送固有の不変条件

| ID | 不変条件 | 根拠（CTR 項目） |
|---|---|---|

## 5. テスト方針（TS[DLV] / TC[DLV] への橋渡し）

- TC[DLV] は**実バイナリ／サーフェスを起動する E2E**（ユニットでなく）。`12-delivery-layer.md` §6。
- 契約適合チェックリスト（CTR §4）の各項目 → TC[DLV] ケースを全数対応させる（P-3 mapping）。

## 6. 非対象（機能軸 SRC へ委譲）

- ドメインロジックそのものは機能軸（UC→…→SRC）の責務。DLV は配送（公開・変換・dispatch）のみ。
