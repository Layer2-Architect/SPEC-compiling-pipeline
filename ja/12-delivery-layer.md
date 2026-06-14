# 12 — 配送層（Delivery / 契約サーフェス）と契約適合

このドキュメントは、システムの機能を**凍結境界契約**越しに外部公開する統合層（CLI バイナリ・公開 API・RPC・MCP サーバ・ファイル形式など）を、トレーサビリティチェーンに正式定置するための章である。SCP v1.0 で追加された（背景: legixy 外部テストが検出した「契約サーフェスのチェーン孤児」問題、`defect-root-cause` 参照）。

## 1. なぜ配送層が必要か（機能軸の盲点）

従来のチェーンは **機能軸**のみを追跡していた:

```
機能軸:  SPEC → UC → RBA → SEQA → RBD → SEQD → DD → TS → TC → SRC
         （= 何をするか。UC = 機能ユースケース → ライブラリロジック）
```

しかし、UC は**機能の単位**であり、**配送（その機能を外部にどう公開するか）は UC と直交する横断的関心**である。例えば CLI バイナリは複数 UC の機能を 1 つの引数規約（凍結境界契約）越しに公開する統合点であって、UC そのものではない。

結果として、機能軸だけのチェーンでは次が起きる（実例: legixy）:

- 19 サブコマンドを束ねる CLI バイナリ（`main.rs`）が **graph ノードを 1 つも持たない＝チェーン孤児**になる。
- 凍結境界契約（例 `LGX-COMPAT-001`）が**参照文書のまま下流（TC）を持たない**。
- 「契約には書いてあるが、それを RED にするテストが無い」状態が生まれ、**実装が契約を満たさなくても誰も気づかない**（全機能チェーン GREEN + `check --formal` 0 ERROR でも契約不適合が残る = 品質過信、`00-philosophy.md` §1 の鏡像）。

> 教訓: **機能 GREEN ≠ 契約適合。** 多重独立検証経路（`00-philosophy.md` §2.3）に「配送＝契約適合」の経路が欠けていた。本章はその経路を構造として埋める。

## 2. 二軸モデル

機能軸に加えて**配送軸**を導入する。配送軸は機能軸の `SRC` を **dispatch で消費**し、凍結境界契約に**準拠**する:

```
機能軸:  SPEC → UC → … → SRC
                          ▲ dispatch で消費
配送軸:  CTR(境界契約) → DLV → TS → TC → SRC(binary/surface)
```

- 配送は機能 UC の横断的配送なので、**ICONIX（RBA/SEQA/RBD/SEQD）は通さない**短縮チェーンとする（ドメインロバストネス/シーケンス分析は不要。契約 → 引数 → dispatch のマッピングのみ）。
- 配送軸の `SRC` は**バイナリ／サーフェスの source（例 `main.rs`/dispatch）を anchor する**。これにより孤児コードが `check`/`impact`/`investigate` の対象に編入され、孤児問題がエンジン層で構造的に解消する。

## 3. 成果物タイプ

| Typecode | 名称 | 役割 | chain 位置 | 場所（既定） |
|---|---|---|---|---|
| `CTR` | 境界契約（Contract） | CLI/API の凍結契約。配送の権威。**人間承認・凍結（HR7）** | **配送チェーンの根（order[0]）** | `docs/contracts/` |
| `DLV` | 配送設計（Delivery） | 契約の各サブコマンド/フラグ/終了コード/グローバル仕様/設定探索 → ライブラリ `SRC` への dispatch 設計。機能 DD §8 に散在する dispatch 記述の**集約点** | CTR の子 | `docs/delivery-design/` |
| `TS` | テスト仕様（再利用） | 契約適合のテスト仕様（契約チェックリスト → ケース化） | DLV の子 | `docs/test-specs/` |
| `TC` | テストコード（再利用） | 契約適合の**実装テスト = 実バイナリ E2E** | TS の子 | （プロジェクト規約）|
| `SRC` | 実装（再利用） | **バイナリ／サーフェス source の anchor**（孤児解消の要） | TC の子 | （プロジェクト規約）|

`TS`/`TC`/`SRC` は機能軸と**同じ typecode を再利用**する。曖昧性は **area code** で解消する（§4）。

## 4. multi-area によるエンジン表現（D-3 の唯一解）

legixy v0.4.0-alpha4 の **複数チェーンは「area 単位」で実装されている**（`te-core/src/config/model.rs` `resolve_chain_order`、`te-check/src/chain_integrity.rs`）。重要な制約:

- **1 area = 1 本の線形チェーンのみ。** `chain_integrity` は子ノードの親 ID を**同一 area-seq から** `build_id_from_pattern` で算出する（`TS-CLI-001` の上流は同 area 同 seq の `DLV-CLI-001`）。
- ゆえに **同一 area に 2 本のチェーンは持てない。** 配送軸で `TS/TC/SRC` を機能軸と同 area で再利用することは**不可能**（`TS-LGX-001` は機能チェーン上で一意に `DD-LGX-001` の子と推論され、`DLV` を親にする術がない）。

→ **配送サーフェスは独自の area code を持つ**。これがエンジンネイティブな唯一の道である:

```
CTR-CLI-001 → DLV-CLI-001 → TS-CLI-001 → TC-CLI-001 → SRC-CLI-001   （area = CLI）
```

typecode は再利用、**area がサーフェスを表す**（G-D: area はサーフェス名 = `CLI`/`MCP` 等。typecode `DLV` と area が衝突する `DLV-DLV-001` を避ける）。

### `.trace-engine.toml`（multi-area 構成例）

```toml
[id]
pattern = "{type}-{area}-{seq}"
seq_digits = 3
areas = ["LGX", "CLI"]          # 機能軸 = LGX / 配送軸 = CLI（将来 MCP 追加可）

[[id.chains]]                    # 機能軸（現行を移植・不変）
area = "LGX"
order = ["UC","RBA","SEQA","RBD","SEQD","DD","TS","TC","SRC"]
independent = ["SPEC","TP","GAP","ADR","AT","NFR","VAL","QSET","SPP","FCR","RPC"]

[[id.chains]]                    # 配送軸（CLI 契約サーフェス）
area = "CLI"
order = ["CTR","DLV","TS","TC","SRC"]   # CTR を根に → 契約 → binary 全走査可能
independent = ["ADR"]

[id.types.CTR]
dir = "docs/contracts/"
ext = ".md"
file_pattern = "prefix"

[id.types.DLV]
dir = "docs/delivery-design/"
ext = ".md"
file_pattern = "prefix"
# TS/TC/SRC の [id.types] は既存を流用（area で曖昧性解消）
```

## 5. CTR をチェーン根に置く理由（D-1 の精緻化）

`CTR` は **`independent` ではなく配送チェーンの根（order[0]）** に置く。

- **independent にすると孤児問題が再発する**: `impact CTR-CLI-001` で配下を辿れず、`investigate SRC-CLI-001` で契約に到達できない（機能軸の `SPEC → UC` が impact/investigate で繋がらないのと同じ盲点を継承する。実測済み）。
- **根に置くと完全に塞がる**: `impact CTR-CLI-001` が契約 → binary まで全走査、`investigate SRC-CLI-001` が契約まで逆引きする。
- **統治と chain 位置は直交**: 「凍結・HR7・人間専管」は統治ルールであり chain 位置とは無関係（`UC` も根かつ人間著作）。チェーン根（pos==0）は親不要で免除される（`chain_integrity.rs`）ので根に置いて整合性違反は出ない。
- **例外**: 1 契約が複数 DLV に分岐する **many-to-one** 形では `independent` + 明示エッジが正直。1 契約 → 1 サーフェスなら根が厳密に優位。

## 6. 契約適合テスト TC[DLV]

配送軸のゲートの実効性は**エンジンの構造検査からは来ない**（構造検査は「孤児を作らせない／TC 欠落を WARN する」までが役割）。**振る舞い適合は TC[DLV] の実行が担う**。TC[DLV] は次の 2 条件を満たすこと:

1. **実バイナリ E2E（P-1）**: 契約のサブコマンド名・位置引数・フラグ・既定値・**終了コード**・グローバルオプション・設定探索を、**実際にビルドしたバイナリ／サーフェスを起動して**検証する（ユニットテストではなく E2E。契約の本質はランタイム挙動）。
2. **契約項目 ↔ TC ケースの全数 mapping（P-3）**: 契約チェックリストの各項目 ID に対応する TC ケースが ≥1 件存在することを**機械照合**する（自己申告でなく検証）。未対応項目があれば RED。

> **RC-4 の一段上での再発防止**: 「契約に在るが RED テストが無い」を構造的に潰すのが P-3。TC[DLV] を TC[RED]→SRC[GREEN] の規律で運用し、契約の各項目を先に RED で書いてから SRC[DLV]（バイナリ実装）が GREEN にする。

## 7. 契約適合ゲート

`08-gates.md` のゲート群に **契約適合ゲート**を追加する。`check` の G1 と同列のリリースゲートとする。

実行順序は**ユニット TC とは別ステージ**であることに注意（G-B）:

```
[1] cargo build（または各言語のビルド）        ─ 実バイナリ／サーフェスを生成
[2] TC[DLV] 実行（実バイナリ E2E）             ─ 契約の振る舞い適合を検証
[3] 契約項目 ↔ TC mapping 照合                 ─ 未カバー契約項目が無いことを検証
[4] check --formal の構造検査を WARN-escalate  ─ 孤児／chain 未連結／DAG（下記 F2 必須）
```

- 役割分担を**方法論として明記**する: **エンジン（構造検出）と TC[DLV]（振る舞い適合）は別経路**。両方が揃って初めて配送が verified state になる。

### 🔴 F2（最重要実装注記）: 構造「検出」≠「ゲート」— WARN escalate が必須

`legixy` の `chain_integrity` は孤児・未連結を **`Severity::Warning`** で報告し、エンジンの
**終了コードは ERROR 数のみ**で決まる。したがって **`check --formal` は配送サーフェスが孤児／未連結でも
WARNING を出すだけで exit=0**（実証: `../spikes/multi-area-2026-06-14/`。配送エッジ除去で 6 WARNING・exit=0）。

> これは legixy の原因「0 ERROR で素通り」の**連結レベルでの再来**である。`check --formal` 単独は
> 配送層のゲートにならない（検出はするが強制しない）。

**対策（必須）**: ゲートラッパ（`scripts/trace-check.sh` 等）が `check --formal` 出力の **`ChainIntegrity`
WARNING を grep し、1 件でもあれば RED（非ゼロ終了）に escalate** すること（エンジンが exit を上げないため、
ラッパ側で強制する）。この escalate を欠くと、配送層を足しても孤児・未連結が素通りし、本章の目的（孤児を
チェーン編入して**強制**検証する）が達成されない。`08-gates.md` の契約適合ゲート行にも本注記を反映する。

## 8. 複数サーフェス（area-per-surface、G-A）

1 プロジェクトが複数の配送サーフェスを持つことは一般的（legixy は **CLI バイナリ + MCP サーバ（ts-mcp）** の 2 サーフェス）。**area-per-surface** で自然に表現する:

```toml
areas = ["LGX", "CLI", "MCP"]
# [[id.chains]] area="CLI": CTR-CLI → … → SRC-CLI (main.rs)
# [[id.chains]] area="MCP": CTR-MCP → … → SRC-MCP (ts-mcp/src/index.ts)
```

**各サーフェスは独自 area・独自 CTR を根・独自 SRC anchor を持つのが原則。** CTR ノードは ID 上 1 area に
束縛される（`CTR-CLI-001` は area=CLI）。複数サーフェスが 1 つの CTR を共有すると、第 2 サーフェスからの
参照は **cross-area = custom エッジ**になり、§5 で得た「根からの chain 走査（impact/investigate で契約↔binary
連結）」の利益を失う。共通の上位契約がある場合でも、各サーフェスの根 CTR を別個に立て、共通部分は参照
（custom エッジ or 本文引用）に留める。

### polyglot サーフェス（例: MCP = TypeScript）の注記

`SRC`/`TC` typecode の `ext`/`dir`（例 `.rs` / `src/`）は **OrphanFile 走査専用**であり、**chain 検証
（FileExistence/ChainIntegrity）は graph の explicit `path` で行う**。したがって `SRC-MCP-001 → ts-mcp/src/index.ts`
のような別言語 anchor も explicit path で検証は通る（誤検出しない）。ただし `.rs` 型の SRC の OrphanFile 走査は
`.ts` ファイルを**覆わない**（未登録 `.ts` の取りこぼしは検出しない）。polyglot では各言語サーフェスの
OrphanFile 網羅を別途担保するか、TC[DLV] の実行カバレッジで補完する。

## 9. single-area → multi-area 移行（G-C）

既存プロジェクトの `.trace-engine.toml` は単一 `[id.chain]`（area 固定）の場合がある。配送層導入時に multi-area へ移行する:

- `[id] area = "LGX"` + `[id.chain]` → `[id] areas = ["LGX", ...]` + `[[id.chains]]`（area タグ付き）。
- **既存 ID は不変**: multi-area の area 正規表現は `[A-Z]+` で、既存 area code（例 `LGX`）を包含する（`build_id_regex`）。
- 移行後に `check --formal` で**回帰ゼロ**を確認すること（既存機能チェーンの整合性が崩れていないこと）。

## 10. 検証済みであること（スパイク記録）

multi-area のコードパスは**実走で確認済み**。**再現可能成果物を `../spikes/multi-area-2026-06-14/`
（`run.sh` + `transcript.txt` + `README.md`、3-area: LGX + CLI + MCP、12 ノード）に retain している**
（F1＝「主張は適合出力で裏付ける」原則の自己適用。著者・レビュアが別個に再現）。

- multi-area config パース + `check --formal` = 0 ERROR / 0 WARNING（連結時クリーン）。
- `CTR`（pos 0）の親要求免除を確認。
- `CTR → DLV → TS → TC → SRC` の配送チェーンが連結時に通過。
- `impact CTR-CLI-001` → 契約から binary まで visited=5。`investigate SRC-CLI-001` → binary から契約まで逆引き
  （別 area の機能軸 LGX に非漏洩）。
- 陰性対照（配送エッジ欠落）→ `ChainIntegrity` WARNING を **検出するが exit=0**。**＝検出であってゲートではない**
  （§7 の F2。ゲート化にはラッパの WARN escalate が必須）。

> **原則「未実走パスを信じるな」**: multi-area のような未走査の機能を採用する前に、捨て駒 fixture でスパイクを回して実走確認し、**成果物（fixture + transcript）をリポジトリに retain** すること（本章の前提自体がこの原則の適用で得られた。F1）。

## 11. legixy への適用（参考）

SCP 変更後の legixy 適用手順（別フェーズ）:

1. `LGX-COMPAT-001` を `CTR-CLI-001`（および MCP 分）として `docs/contracts/` へ昇格・graph 登録。
2. `DLV-CLI-001`（dispatch 設計、機能 DD §8 を集約）作成。
3. `TS-CLI-001`/`TC-CLI-001` = 契約 §7 チェックリストの実バイナリ E2E（既存の外部テストハーネスを in-repo 化）。
4. `SRC-CLI-001` を `crates/legixy-cli/src/main.rs` に anchor（孤児解消）。MCP 分は `SRC-MCP-001` を `ts-mcp/src/index.ts` に。
5. `.trace-engine.toml` を multi-area へ移行（§9）。
6. `scripts/trace-check.sh` に契約適合ゲート（§7 の 4 ステージ）を追加。

## 12. 未検証・今後

- 1 契約 → 複数 DLV（many-to-one）の運用（§5 例外）は未検証。必要時に独立エッジ方式を検証する。
- 配送軸の `[[id.chains]] independent` に何を許すか（`ADR` 以外）はプロジェクト規約で確定する。
- 契約項目 ↔ TC mapping 照合の実装（grep ベース or ID 規約）は各プロジェクトのハーネスで具体化する。
