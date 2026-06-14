#!/usr/bin/env bash
# SCP v1.0 §12 配送層 multi-area スパイク（再現可能成果物。F1 対応）。
#
# 目的: traceability-engine v0.4.0-alpha4 の multi-area（[id.areas]+[[id.chains]]）が、
#   配送軸（CTR=根 → DLV → TS → TC → SRC）を機能軸と別 area で成立させることを実走で確認する。
#   さらに F2（ChainIntegrity は WARNING かつ exit 0 ＝ check --formal 単独ではゲートにならない）を実証する。
#
# 実行: bash run.sh   （要 traceability-engine が PATH、python3）
# 出力: 標準出力（transcript.md に保存済みの内容を再生成する）。SUT は無改変・捨て駒 fixture を /tmp に作る。
set -u
ENGINE="${ENGINE:-traceability-engine}"
WORK="$(mktemp -d /tmp/scp-ma-spike.XXXXXX)"
echo "workdir: $WORK"
mkdir -p "$WORK"/.trace-engine "$WORK"/docs/traceability \
  "$WORK"/docs/usecases "$WORK"/docs/robustness-abstract \
  "$WORK"/docs/contracts "$WORK"/docs/delivery-design "$WORK"/docs/test-specs \
  "$WORK"/docs/test-code "$WORK"/docs/src-anchor

# --- 3-area config: LGX(機能) + CLI/MCP(配送) ---
cat > "$WORK/.trace-engine.toml" <<'EOF'
[project]
name = "ma-spike"
[graph]
file = "docs/traceability/graph.toml"
[matrix]
format = "markdown"
file = "docs/traceability/matrix.md"
section = "Traceability Matrix"
[id]
pattern = "{type}-{area}-{seq}"
seq_digits = 3
areas = ["LGX", "CLI", "MCP"]
[[id.chains]]
area = "LGX"
order = ["UC","RBA","SEQA","RBD","SEQD","DD","TS","TC","SRC"]
independent = ["SPEC","ADR"]
[[id.chains]]
area = "CLI"
order = ["CTR","DLV","TS","TC","SRC"]
independent = ["ADR"]
[[id.chains]]
area = "MCP"
order = ["CTR","DLV","TS","TC","SRC"]
independent = ["ADR"]
[id.document_id]
pattern = "Document ID:"
[id.types.UC]
dir = "docs/usecases/"
ext = ".md"
file_pattern = "prefix"
[id.types.RBA]
dir = "docs/robustness-abstract/"
ext = ".md"
file_pattern = "prefix"
[id.types.CTR]
dir = "docs/contracts/"
ext = ".md"
file_pattern = "prefix"
[id.types.DLV]
dir = "docs/delivery-design/"
ext = ".md"
file_pattern = "prefix"
[id.types.TS]
dir = "docs/test-specs/"
ext = ".md"
file_pattern = "prefix"
[id.types.TC]
dir = "docs/test-code/"
ext = ".md"
file_pattern = "prefix"
[id.types.SRC]
dir = "docs/src-anchor/"
ext = ".md"
file_pattern = "prefix"
EOF

echo "# Traceability Matrix" > "$WORK/docs/traceability/matrix.md"

# --- graph.toml: LGX(UC→RBA) + CLI/MCP(CTR→DLV→TS→TC→SRC) ---
cat > "$WORK/docs/traceability/graph.toml" <<'EOF'
[[nodes]]
id = "UC-LGX-001"
type = "UC"
path = "docs/usecases/UC-LGX-001.md"
[[nodes]]
id = "RBA-LGX-001"
type = "RBA"
path = "docs/robustness-abstract/RBA-LGX-001.md"
[[nodes]]
id = "CTR-CLI-001"
type = "CTR"
path = "docs/contracts/CTR-CLI-001.md"
[[nodes]]
id = "DLV-CLI-001"
type = "DLV"
path = "docs/delivery-design/DLV-CLI-001.md"
[[nodes]]
id = "TS-CLI-001"
type = "TS"
path = "docs/test-specs/TS-CLI-001.md"
[[nodes]]
id = "TC-CLI-001"
type = "TC"
path = "docs/test-code/TC-CLI-001.md"
[[nodes]]
id = "SRC-CLI-001"
type = "SRC"
path = "docs/src-anchor/SRC-CLI-001.md"
[[nodes]]
id = "CTR-MCP-001"
type = "CTR"
path = "docs/contracts/CTR-MCP-001.md"
[[nodes]]
id = "DLV-MCP-001"
type = "DLV"
path = "docs/delivery-design/DLV-MCP-001.md"
[[nodes]]
id = "TS-MCP-001"
type = "TS"
path = "docs/test-specs/TS-MCP-001.md"
[[nodes]]
id = "TC-MCP-001"
type = "TC"
path = "docs/test-code/TC-MCP-001.md"
[[nodes]]
id = "SRC-MCP-001"
type = "SRC"
path = "docs/src-anchor/SRC-MCP-001.md"
[[edges]]
from = "UC-LGX-001"
to = "RBA-LGX-001"
kind = "chain"
[[edges]]
from = "CTR-CLI-001"
to = "DLV-CLI-001"
kind = "chain"
[[edges]]
from = "DLV-CLI-001"
to = "TS-CLI-001"
kind = "chain"
[[edges]]
from = "TS-CLI-001"
to = "TC-CLI-001"
kind = "chain"
[[edges]]
from = "TC-CLI-001"
to = "SRC-CLI-001"
kind = "chain"
[[edges]]
from = "CTR-MCP-001"
to = "DLV-MCP-001"
kind = "chain"
[[edges]]
from = "DLV-MCP-001"
to = "TS-MCP-001"
kind = "chain"
[[edges]]
from = "TS-MCP-001"
to = "TC-MCP-001"
kind = "chain"
[[edges]]
from = "TC-MCP-001"
to = "SRC-MCP-001"
kind = "chain"
EOF

mk() { mkdir -p "$(dirname "$WORK/$2")"; printf 'Document ID: %s\n# %s (spike)\n' "$1" "$1" > "$WORK/$2"; }
mk UC-LGX-001  docs/usecases/UC-LGX-001.md
mk RBA-LGX-001 docs/robustness-abstract/RBA-LGX-001.md
for a in CLI MCP; do
  mk CTR-$a-001 docs/contracts/CTR-$a-001.md
  mk DLV-$a-001 docs/delivery-design/DLV-$a-001.md
  mk TS-$a-001  docs/test-specs/TS-$a-001.md
  mk TC-$a-001  docs/test-code/TC-$a-001.md
  mk SRC-$a-001 docs/src-anchor/SRC-$a-001.md
done

# V3 marker（autodetect が V01 と誤認しないよう engine.db に user_version=3）
python3 - "$WORK/.trace-engine/engine.db" <<'PY'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1]); c.execute("PRAGMA user_version=3"); c.commit(); c.close()
PY

run() { echo; echo "$ $ENGINE --project-root \$WORK $*"; "$ENGINE" --project-root "$WORK" "$@" 2>&1; echo "exit=$?"; }

echo "==================== $ENGINE --version ===================="
"$ENGINE" --version 2>&1 | head -1

echo; echo "==================== [陽性] check --formal（連結時、3-area） ===================="
run check --formal

echo; echo "==================== impact CTR-CLI-001（契約→binary 全走査） ===================="
run impact CTR-CLI-001

echo; echo "==================== investigate SRC-CLI-001（binary→契約 逆引き） ===================="
run investigate SRC-CLI-001

echo; echo "==================== [陰性/F2] 配送エッジ DLV-CLI→TS-CLI を削除 ===================="
# DLV-CLI-001 → TS-CLI-001 の chain edge を除去（他は不変）
python3 - "$WORK/docs/traceability/graph.toml" <<'PY'
import sys,re
p=sys.argv[1]; t=open(p).read()
t=t.replace('[[edges]]\nfrom = "DLV-CLI-001"\nto = "TS-CLI-001"\nkind = "chain"\n','')
open(p,'w').write(t)
PY
echo "（DLV-CLI-001→TS-CLI-001 を削除。TS/TC/SRC-CLI が上流未連結になるはず）"
run check --formal
echo
echo ">>> F2 の要点: 上の check --formal は ChainIntegrity WARNING を出すが exit=0。"
echo ">>> すなわち check --formal 単独ではゲートにならない。ラッパが WARNING を grep して RED 化する必要がある。"

echo; echo "workdir 保持: $WORK （確認後 rm -rf 可）"
