#!/usr/bin/env bash
# init-tree.sh — SCP フレームワーク用ディレクトリツリー初期化
#
# 新規プロジェクトに SCP を導入する際に実行するスクリプト。
# プロジェクトルートで `bash bootstrap/init-tree.sh` として呼ぶ。
#
# 既に存在するディレクトリは触らない（既存ファイルを上書きしない）。

set -euo pipefail

cd "$(dirname "$0")/../../.." || exit 1

echo "SCP ディレクトリツリーを初期化します..."

DIRS=(
  "docs/specs"
  "docs/frontend-pass/questionnaires"
  "docs/frontend-pass/check-results"
  "docs/spec-patches"
  "docs/usecases"
  "docs/test-perspectives"
  "docs/gap-analysis"
  "docs/robustness-abstract"
  "docs/sequence-abstract"
  "docs/robustness-detail"
  "docs/sequence-detail"
  "docs/detailed-design"
  "docs/test-specs"
  "docs/acceptance-tests"
  "docs/nfr"
  "docs/adr"
  "docs/validation"
  "docs/responsibility-preservation"
  "docs/traceability"
  "docs/perspectives"
  "docs/decisions"
  "docs/testbed-logs"
  "scripts"
  "tests"
  "src"
  ".claude/commands"
  ".claude/agents"
  ".scp/reviewer-output"
)

for d in "${DIRS[@]}"; do
  if [[ -d "$d" ]]; then
    echo "  既存: $d"
  else
    mkdir -p "$d"
    echo "  作成: $d"
  fi
done

# graph.toml テンプレートをコピー（存在しない場合のみ）
if [[ ! -f "docs/traceability/graph.toml" ]]; then
  if [[ -f "docs/SCP/bootstrap/graph.toml.template" ]]; then
    cp "docs/SCP/bootstrap/graph.toml.template" "docs/traceability/graph.toml"
    echo "  作成: docs/traceability/graph.toml（テンプレートからコピー）"
  fi
fi

# trace-check.sh をコピー（存在しない場合のみ）
if [[ ! -f "scripts/trace-check.sh" ]]; then
  if [[ -f "docs/SCP/bootstrap/trace-check.sh" ]]; then
    cp "docs/SCP/bootstrap/trace-check.sh" "scripts/trace-check.sh"
    chmod +x "scripts/trace-check.sh"
    echo "  作成: scripts/trace-check.sh（テンプレートからコピー）"
  fi
fi

# ローカル運用スクリプト群（AI レビュア層用、08-gates.md §17 参照）
for s in extract-verdict.sh check-latest-verdict.sh guard-quality-baseline.sh check-pending-verdict.sh count-fix-cycle.sh; do
  if [[ ! -f "scripts/$s" ]]; then
    if [[ -f "docs/SCP/bootstrap/scripts/$s" ]]; then
      cp "docs/SCP/bootstrap/scripts/$s" "scripts/$s"
      chmod +x "scripts/$s"
      echo "  作成: scripts/$s（ローカル運用用、テンプレートからコピー）"
    fi
  fi
done

# perspectives 雛形をコピー（存在しない場合のみ）
for p in core-perspectives.md ux-perspectives.md; do
  if [[ ! -f "docs/perspectives/$p" ]]; then
    if [[ -f "docs/SCP/perspectives/$p" ]]; then
      cp "docs/SCP/perspectives/$p" "docs/perspectives/$p"
      echo "  作成: docs/perspectives/$p（テンプレートからコピー）"
    fi
  fi
done

# .trace-engine.toml をコピー（存在しない場合のみ）
if [[ ! -f ".trace-engine.toml" ]]; then
  if [[ -f "docs/SCP/bootstrap/trace-engine.toml.template" ]]; then
    cp "docs/SCP/bootstrap/trace-engine.toml.template" ".trace-engine.toml"
    echo "  作成: .trace-engine.toml（テンプレートからコピー）"
    echo "    >>> 重要: <YOUR-AREA> と <your-project> を自プロジェクト用に置換してください"
  fi
fi

# CLAUDE.md をコピー（存在しない場合のみ）
if [[ ! -f "CLAUDE.md" ]]; then
  if [[ -f "docs/SCP/bootstrap/CLAUDE.md.template" ]]; then
    cp "docs/SCP/bootstrap/CLAUDE.md.template" "CLAUDE.md"
    echo "  作成: CLAUDE.md（Author モード、テンプレートからコピー）"
    echo "    >>> 重要: <AREA> 等のプレースホルダを自プロジェクト用に置換してください"
  fi
fi

# .claude/settings.json をコピー（存在しない場合のみ）
if [[ ! -f ".claude/settings.json" ]]; then
  if [[ -f "docs/SCP/bootstrap/.claude/settings.json.template" ]]; then
    cp "docs/SCP/bootstrap/.claude/settings.json.template" ".claude/settings.json"
    echo "  作成: .claude/settings.json（hooks 定義、テンプレートからコピー）"
  fi
fi

# .claude/commands/advance.md をコピー（存在しない場合のみ）
if [[ ! -f ".claude/commands/advance.md" ]]; then
  if [[ -f "docs/SCP/bootstrap/.claude/commands/advance.md.template" ]]; then
    cp "docs/SCP/bootstrap/.claude/commands/advance.md.template" ".claude/commands/advance.md"
    echo "  作成: .claude/commands/advance.md（/advance slash command）"
  fi
fi

# V3 修正イベント slash commands（10-modification-events.md 参照）
for cmd in defect-fix spec-change spec-add; do
  if [[ ! -f ".claude/commands/${cmd}.md" ]]; then
    if [[ -f "docs/SCP/bootstrap/.claude/commands/${cmd}.md.template" ]]; then
      cp "docs/SCP/bootstrap/.claude/commands/${cmd}.md.template" ".claude/commands/${cmd}.md"
      echo "  作成: .claude/commands/${cmd}.md（V3 修正イベント）"
    fi
  fi
done

# .claude/agents/reviewer.md をコピー（存在しない場合のみ）
if [[ ! -f ".claude/agents/reviewer.md" ]]; then
  if [[ -f "docs/SCP/bootstrap/.claude/agents/reviewer.md.template" ]]; then
    cp "docs/SCP/bootstrap/.claude/agents/reviewer.md.template" ".claude/agents/reviewer.md"
    echo "  作成: .claude/agents/reviewer.md（Reviewer subagent 定義）"
  fi
fi

# .git/hooks/pre-commit をコピー（存在しない場合のみ、.git が存在する場合のみ）
if [[ -d ".git" && ! -f ".git/hooks/pre-commit" ]]; then
  if [[ -f "docs/SCP/bootstrap/.git-hooks/pre-commit.template" ]]; then
    cp "docs/SCP/bootstrap/.git-hooks/pre-commit.template" ".git/hooks/pre-commit"
    chmod +x ".git/hooks/pre-commit"
    echo "  作成: .git/hooks/pre-commit（trace-check.sh の自動起動）"
  fi
fi

# .gitignore に .scp/ を追加（既に存在しなければ）
if [[ -f ".gitignore" ]]; then
  if ! grep -q "^\.scp/" ".gitignore"; then
    echo ".scp/" >> ".gitignore"
    echo "  追加: .gitignore に .scp/ を追加"
  fi
else
  echo ".scp/" > ".gitignore"
  echo "  作成: .gitignore（.scp/ を ignore）"
fi

echo ""
echo "完了。次のステップ:"
echo "  1. .trace-engine.toml の <YOUR-AREA> を自プロジェクトの area コードに置換"
echo "  2. CLAUDE.md の <AREA> 等を置換"
echo "  3. docs/perspectives/*.md に領域固有観点を追記"
echo "  4. SPEC-<AREA>-001 を作成（templates/SPEC-template.md を参考に）"
echo "  5. bash scripts/trace-check.sh で検証"
echo "  6. ローカル運用が動くか確認: /advance spec-to-uc を試す（Claude Code 内）"
