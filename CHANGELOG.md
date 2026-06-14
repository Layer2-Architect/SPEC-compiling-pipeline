# Changelog

本プロジェクトのバージョニングは [Semantic Versioning](https://semver.org/lang/ja/) に準拠する。

## [1.0.0] — 2026-06-14

**SPEC Compiling Pipeline (SCP) v1.0.0 — 初版公開リリース。**

確率論的変換器（AI）を SPEC / UC からのソフトウェアコンパイラとして運用する開発フレームワーク。
品質の「最大化」ではなく品質の「偏向防止」を第一目的とし、多重独立検証経路として以下を統合する:

- **ICONIX 二段化**（抽象 RBA/SEQA・具体 RBD/SEQD・DD）レイヤと三者整合性検証
- **SDD / TDD** と **仕様レベル TDD**（SPEC ⇄ TP ⇄ GAP）
- **前段ループ**（Raw SPEC ⇄ QSET ⇄ SPP ⇄ FCR）
- **修正イベントフロー**（`defect-fix` / `spec-change` / `spec-add`）
- **9 観点 AI レビュア層** と **AT 独立検証**
- **legixy**（トレーサビリティエンジン）による有向グラフ・トレーサビリティ
- **配送層**（CTR / DLV / TC[DLV]）による凍結境界契約への適合検証（実バイナリ E2E + WARN-escalate ゲート）

> SCP は実プロダクト開発の中で複数世代の反復（旧称 DevProc）を経て育てられ、
> 本リリースで初めて汎用フレームワークとして再構成・公開された。

[1.0.0]: https://github.com/<owner>/spec-compiling-pipeline/releases/tag/v1.0.0
