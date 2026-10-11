#!/usr/bin/env bash
# HumanEval-C# run to compare with Figure 6 of the MultiPL-E paper:
# CodeGen-350M-multi, InCoder-1B, then InCoder-6.7B (4-bit), then evaluation,
# pass@1, and a summary in runs/cs/RESULTS.md. Safe to rerun: generation
# resumes from completions that already exist. Pass "small" to skip
# InCoder-6.7B.
set -eo pipefail
export PATH="/usr/bin:/mingw64/bin:$PATH:/c/Users/s8615/.local/bin:/c/Program Files/Docker/Docker/resources/bin"
cd /d/GitHub/MultiPL-E
export PYTHONIOENCODING=utf-8 HF_HUB_DISABLE_SYMLINKS_WARNING=1
OUT=runs/cs
RESULTS="$OUT/RESULTS.md"
mkdir -p "$OUT"
STARTED="$(date '+%F %T')"

status() {
  cat > "$RESULTS" <<EOF
# MultiPL-E HumanEval-C#: CodeGen vs. InCoder

**Status:** $1 (updated $(date '+%F %T'), started $STARTED)

Log: \`runs/cs/run.log\`. To resume after an interruption, run
\`bash runs/cs_run.sh\` from the repo root.
EOF
}

gen() {
  echo "=== $(date '+%F %T') generating $2"
  status "generating $2"
  uv run -q --no-project --python 3.11 \
    --index https://download.pytorch.org/whl/cu124 --index-strategy unsafe-best-match \
    --with "torch==2.6.0+cu124" --with transformers --with "datasets>=3.6" --with numpy --with tqdm --with accelerate --with bitsandbytes \
    python automodel.py --name "$1" --name-override "$2" \
    --root-dataset humaneval --lang cs --temperature 0.2 \
    --batch-size "$3" --completion-limit 20 --output-dir-prefix "$OUT" "${@:4}"
}

trap 'status "FAILED, see runs/cs/run.log"' ERR

gen Salesforce/codegen-350M-multi codegen_350M_multi 5
gen facebook/incoder-1B incoder_1B 5
if [ "$1" != small ]; then
  gen facebook/incoder-6B incoder_6B_4bit 2 --load-in-4bit
fi

echo "=== $(date '+%F %T') evaluating"
status "executing completions in the container"
# MSYS_NO_PATHCONV stops Git Bash from rewriting /run into a Windows path.
MSYS_NO_PATHCONV=1 docker run --rm --network none -v "D:\\GitHub\\MultiPL-E\\runs\\cs:/run:rw" \
  multipl-e-eval --dir /run --output-dir /run --recursive

echo "=== $(date '+%F %T') pass@1"
PASSK="$(uv run -q --no-project --with numpy python pass_k.py "$OUT"/humaneval-*)"
echo "$PASSK"

{
  echo "# MultiPL-E HumanEval-C#: CodeGen vs. InCoder"
  echo
  echo "**Status:** complete (started $STARTED, finished $(date '+%F %T'))"
  echo
  echo "| Model | Problems | Completions per problem | pass@1 |"
  echo "|---|---|---|---|"
  echo "$PASSK" | tail -n +2 | while IFS=, read -r name k est n minc maxc; do
    model="${name#humaneval-cs-}"; model="${model%-0.2-reworded}"
    printf '| %s | %s | %s | **%.3f** |\n' "$model" "$n" "$minc" "$est"
  done
  echo
  echo "## Settings"
  echo
  echo "- Dataset: MultiPL-E HumanEval translated to C# (\`nuprl/MultiPL-E\`, \`humaneval-cs\`)"
  echo "- Models: \`Salesforce/codegen-350M-multi\`, \`facebook/incoder-1B\`, \`facebook/incoder-6B\` (6.7B, NF4 4-bit via bitsandbytes), run locally with \`automodel.py\`"
  echo "- Paper (Figure 6) used InCoder-6.7B at full precision and CodeGen-16B-multi, 200 completions per problem; CodeGen-16B does not fit this GPU"
  echo "- Sampling: temperature 0.2, top-p 0.95, max 1024 tokens, 20 completions per problem"
  echo "- Execution: \`multipl-e-eval\` container, no network"
  echo "- Hardware: NVIDIA GeForce RTX 4060 Laptop GPU (8 GB); batch size 5 for the small models, 2 for InCoder-6.7B (5 overflows GPU memory)"
  echo
  echo "## Raw \`pass_k.py\` output"
  echo
  echo '```'
  echo "$PASSK"
  echo '```'
} > "$RESULTS"
echo "=== $(date '+%F %T') done, wrote $RESULTS"
