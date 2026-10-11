# MultiPL-E HumanEval: local results vs. the paper

Comparison of local runs with Figure 6 of *MultiPL-E: A Scalable and
Extensible Approach to Benchmarking Neural Code Generation* (Cassano et al.),
where the C# pass@1 for InCoder and CodeGen reads as roughly 0.1.

## Results

### C# (`humaneval-cs`, 158 problems, 20 completions each) — `runs/cs_run.sh`

| Model | Size vs. paper | pass@1 | Problems solved at least once | Did not compile |
|---|---|---|---|---|
| CodeGen-350M-multi | 46x smaller than CodeGen-16B | 0.005 | 2 / 158 | 85% |
| InCoder-1B | 6.7x smaller than InCoder-6.7B | 0.034 | 12 / 158 | 46% |
| InCoder-6.7B (4-bit) | same model as the paper | **0.066** | 25 / 158 | 41% |

95% confidence interval for InCoder-6.7B: 0.033–0.099.

### JavaScript (`humaneval-js`, 161 problems, 20 completions each) — `runs/full_run.sh`

| Model | pass@1 |
|---|---|
| CodeGen-350M-multi | 0.056 |
| InCoder-1B | 0.072 |

Settings for all runs: temperature 0.2, top-p 0.95, 1024 max tokens (prompt
plus completion), `automodel.py` on an RTX 4060 Laptop GPU (8 GB), evaluated
in the `multipl-e-eval` container. Full tables: `runs/cs/RESULTS.md`,
`runs/full/RESULTS.md`.

## Why the numbers do not match the paper

1. **Smaller models.** The paper used InCoder-6.7B and CodeGen-16.1B-multi.
   CodeGen-16B needs about 32 GB of GPU memory (about 9 GB even in 4-bit), so
   it cannot run on an 8 GB GPU and was not tested. The 350M and 1B models are
   7–46x smaller and are not expected to reach the paper's numbers. This is the
   main reason the JS and small-model C# scores are low.

2. **CodeGen was not trained on C#.** CodeGen-multi was fine-tuned on C, C++,
   Go, Java, JavaScript and Python. CodeGen-350M mostly writes Java inside the
   C# function: about 1,100 of its compile errors are Java-only calls such as
   `str.length()`, `list.size()`, `.add()` and `charAt`. The paper also notes
   that CodeGen does best on its fine-tuning languages.

3. **4-bit quantization.** InCoder-6.7B was quantized to 4 bits (NF4) to fit
   in 8 GB; the paper ran it at full precision. Quantization usually costs some
   accuracy.

4. **Newer dataset.** The repository pins a 2023+ revision of
   `nuprl/MultiPL-E`. The C# prompts and tests have been revised since the
   paper, so its numbers do not carry over exactly.

5. **Fewer samples.** The paper used 200 completions per problem; these runs
   used 20, which makes the estimate noisier. The paper's value of about 0.1 is
   also read off a bar chart. InCoder-6.7B's interval (0.033–0.099) nearly
   reaches it.

6. **Truncated completions.** The 1024-token limit includes the prompt, and
   many failures are unfinished functions (`CS1002` "; expected", JS
   "Unexpected end of input"). This affects all models equally, so it lowers
   every score but does not explain the gap with the paper.

## Failure breakdown (C#, 3,160 completions per model)

| Model | Passed | Compile error | Runtime exception / wrong answer | Timeout |
|---|---|---|---|---|
| CodeGen-350M-multi | 15 | 2671 | 444 | 30 |
| InCoder-1B | 107 | 1445 | 1515 | 93 |
| InCoder-6.7B (4-bit) | 209 | 1305 | 1570 | 76 |

## Getting closer to the paper

- Run InCoder-6.7B at full precision and CodeGen-16B-multi on a GPU with 40 GB
  or more, which removes reasons 1 and 3.
- Use more completions per problem to narrow the confidence interval.
