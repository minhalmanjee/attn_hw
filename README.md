# Hardware Implementation of Scaled Dot-Product Attention

```
Attention(Q, K, V) = softmax( (Q K^T) / sqrt(d_k) ) V
Q = X WQ,  K = X WK,  V = X WV
```

N=2 tokens, D=4, 8-bit Q4.4 fixed-point (`16 = 1.0`).

## Run

```bash
make          # iverilog sim → data/output.txt + VCD
make check    # to check python output

Needs `iverilog` / `vvp`. `make check` also needs `python3` + `numpy`.

## Design notes

- Sequential FSM: Q → K → V → scores → scale → softmax → out
- Q4.4: multiply then `>> 4` to stay in format
- Scale: `/sqrt(4)` is just `>> 1`
- Softmax: subtract max, exp LUT, integer divide

## Files

| Path | What |
|------|------|
| `src/attn_top.v` | FSM + buffers |
| `src/matmul.v` | `C = A * B` |
| `src/softmax.v` | approx softmax |
| `tb/attn_tb.v` | `$fscanf` inputs, VCD, `output.txt` |
| `data/*.txt` | inputs (decimal Q4.4) |
| `scripts/check_attn.py` | final check |

Input format: space-separated decimals, one row per line.
