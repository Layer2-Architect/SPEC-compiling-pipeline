# SPEC Compiling Pipeline (SCP)

**[English](en/README.md) ・ [日本語](ja/README.md)**

> A quality-bias-prevention framework for operating a probabilistic transformer (an LLM)
> as a software compiler from SPEC and Use Cases.
>
> 確率論的変換器（AI）を SPEC・ユースケースからのソフトウェアコンパイラとして運用する、
> **品質偏向防止**を第一目的とする開発フレームワーク。

---

## English

When you use a probabilistic transformer (an LLM) as a compiler, quality assurance becomes a
problem of **bias prevention**, not **maximization**. A traditional compiler (GCC, Clang) is a
deterministic transformer — the same input always yields the same output — so quality is a
maximization problem. An LLM samples from a distribution `P(y|x)`; the single sample used in
practice can come from the bad tail, and training-distribution bias makes repeated samples
accumulate in a particular direction.

SCP counters this not by tuning the AI from the inside (prompting, fine-tuning, RAG) but by
**structural design on the outside of the AI**: multiple independent verification paths,
observation from outside the probability distribution, and after-the-fact accumulation of bias
patterns. It integrates **ICONIX (two-tier) + SDD + TDD + Traceability (legixy) + spec-level TDD
+ a front-pass loop + a modification-event flow + a 9-perspective AI reviewer layer + independent
acceptance testing** as multiple independent verification paths under this single principle.

→ **Read the docs: [`en/README.md`](en/README.md)**

> **Note**: English is a translation; the **Japanese edition ([`ja/`](ja/)) is the source of
> truth**. Translation is in progress — chapters not yet translated link back to the Japanese
> edition. See the status table in [`en/README.md`](en/README.md).

## 日本語

確率論的変換器（LLM）をコンパイラとして使うとき、品質保証は「最大化」ではなく「**偏向防止**」の
問題になります。伝統的コンパイラ（GCC, Clang）は確定論的変換器（同じ入力から常に同じ出力）であり
品質保証を最大化問題として定式化できましたが、LLM は確率分布 `P(y|x)` からのサンプリングを返すため、
実装で使われる単一サンプルが分布の左裾（悪い領域）から出る可能性があり、訓練分布バイアスにより
複数サンプルが特定方向へ偏向蓄積します。

SCP はこれに対し、AI の内部チューニング（プロンプト・fine-tuning・RAG）ではなく **AI の外側の構造
設計**（多重独立検証経路・確率分布外側からの観察・偏向パターンの事後蓄積）で対抗します。**ICONIX
二段化 + SDD + TDD + Traceability(legixy) + 仕様レベル TDD + 前段ループ + 修正イベントフロー +
9 観点 AI レビュア層 + AT 独立検証** を、品質偏向防止という統一原理の下に多重独立検証経路として
統合します。

→ **ドキュメント: [`ja/README.md`](ja/README.md)**

---

## Repository layout / リポジトリ構成

| Path | Contents |
|---|---|
| [`en/`](en/) | English edition — *translation in progress* |
| [`ja/`](ja/) | Japanese edition — **source of truth** |
| [`manual/legixy/`](manual/legixy/) | Manual for the traceability engine `legixy` (Japanese; distributed separately) |
| [`spikes/`](spikes/) | Reproducible verification artifacts (language-neutral) |
| `LICENSE` / `NOTICE` | Apache-2.0 |
| `CHANGELOG.md` | Release history |

## About the names / 名称について

- **SCP** was developed internally as **"DevProc"** and renamed *SPEC Compiling Pipeline* for this
  public release. / SCP は内部では **「DevProc」** として開発され、公開にあたり *SPEC Compiling
  Pipeline* に改称しました。
- **legixy** (<https://github.com/Layer2-Architect/legixy>) is the traceability engine SCP depends on. It was implemented as
  **`traceability-engine`** (v3 / `v0.4.0-alpha4`) during development and is being renamed/rebuilt
  as `legixy`; the currently distributed binary may still be named `traceability-engine` (same
  tool). / legixy は SCP が用いるトレーサビリティエンジン。開発時は **`traceability-engine`**
  （v3 / `v0.4.0-alpha4`）として実装され、`legixy` へ改称・再構築中（現行配布の実バイナリ名は
  `traceability-engine` の場合あり。同一の実体）。

## License

Licensed under the **Apache License 2.0** — see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
