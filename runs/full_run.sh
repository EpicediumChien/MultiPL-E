#!/usr/bin/env bash
# Full HumanEval-JS run: CodeGen-350M-multi, then InCoder-1B, then evaluation,
# pass@1, and a summary in runs/full/RESULTS.md. Safe to rerun: generation
# resumes from completions that already exist.
set -eo pipefail
export PATH="/usr/bin:/mingw64/bin:$PATH:/c/Users/s8615/.local/bin:/c/Program Files/Docker/Docker/resources/bin"
cd /d/GitHub/MultiPL-E
export PYTHONIOENCODING=utf-8 HF_HUB_DISABLE_SYMLINKS_WARNING=1
OUT=runs/full
RESULTS="$OUT/RESULTS.md"
mkdir -p "$OUT"
STARTED="$(date '+%F %T')"

status() {
  cat > "$RESULTS" <<EOF
# MultiPL-E HumanEval-JS: CodeGen vs. InCoder

**Status:** $1 (updated $(date '+%F %T'), started $STARTED)

Log: \`runs/full/run.log\`. To resume after an interruption, run
\`bash runs/full_run.sh\` from the repo root.
EOF
}

gen() {
  echo "=== $(date '+%F %T') generating $2"
  status "generating $2"
  uv run -q --no-project --python 3.11 \
    --index https://download.pytorch.org/whl/cu124 --index-strategy unsafe-best-match \
    --with "torch==2.6.0+cu124" --with transformers --with "datasets>=3.6" --with numpy --with tqdm --with accelerate \
    python automodel.py --name "$1" --name-override "$2" \
    --root-dataset humaneval --lang js --temperature 0.2 \
    --batch-size 5 --completion-limit 20 --output-dir-prefix "$OUT"
}

trap 'status "FAILED, see runs/full/run.log"' ERR

gen Salesforce/codegen-350M-multi codegen_350M_multi
gen facebook/incoder-1B incoder_1B

echo "=== $(date '+%F %T') evaluating"
status "executing completions in the container"
# MSYS_NO_PATHCONV stops Git Bash from rewriting /run into a Windows path.
MSYS_NO_PATHCONV=1 docker run --rm --network none -v "D:\\GitHub\\MultiPL-E\\runs\\full:/run:rw" \
  multipl-e-eval --dir /run --output-dir /run --recursive

echo "=== $(date '+%F %T') pass@1"
PASSK="$(uv run -q --no-project --with numpy python pass_k.py "$OUT"/humaneval-*)"
echo "$PASSK"

{
  echo "# MultiPL-E HumanEval-JS: CodeGen vs. InCoder"
  echo
  echo "**Status:** complete (started $STARTED, finished $(date '+%F %T'))"
  echo
  echo "| Model | Problems | Completions per problem | pass@1 |"
  echo "|---|---|---|---|"
  echo "$PASSK" | tail -n +2 | while IFS=, read -r name k est n minc maxc; do
    model="${name#humaneval-js-}"; model="${model%-0.2-reworded}"
    printf '| %s | %s | %s | **%.3f** |\n' "$model" "$n" "$minc" "$est"
  done
  echo
  echo "## Settings"
  echo
  echo "- Dataset: MultiPL-E HumanEval translated to JavaScript (\`nuprl/MultiPL-E\`, \`humaneval-js\`)"
  echo "- Models: \`Salesforce/codegen-350M-multi\`, \`facebook/incoder-1B\`, run locally with \`automodel.py\`"
  echo "- Sampling: temperature 0.2, top-p 0.95, max 1024 tokens, 20 completions per problem"
  echo "- Execution: \`multipl-e-eval\` container, no network"
  echo "- Hardware: NVIDIA GeForce RTX 4060 Laptop GPU (8 GB), batch size 5"
  echo
  echo "## Raw \`pass_k.py\` output"
  echo
  echo '```'
  echo "$PASSK"
  echo '```'
} > "$RESULTS"
echo "=== $(date '+%F %T') done, wrote $RESULTS"
