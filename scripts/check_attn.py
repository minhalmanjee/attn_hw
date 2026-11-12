from pathlib import Path
import numpy as np

DATA = Path(__file__).resolve().parents[1] / "data"
FRAC = 16


def load_matrix(path):
    return np.loadtxt(path, dtype=np.int32)


def qmul_mat(A, B):
    return ((A.astype(np.int32) @ B.astype(np.int32)) >> 4).astype(np.int32)


def exp_lut(x):
    table = {16: 43, 8: 26, 0: 16, -8: 10, -16: 6, -32: 3}
    return table.get(int(x), 16)


def softmax_row(scores):
    m = int(scores.max())
    e = np.array([exp_lut(int(s) - m) for s in scores], dtype=np.int32)
    return ((e << 4) // int(e.sum())).astype(np.int32)


def attention(X, WQ, WK, WV):
    Q = qmul_mat(X, WQ)
    K = qmul_mat(X, WK)
    V = qmul_mat(X, WV)

    # (Q K^T) / sqrt(4)  ->  >>4 then >>1
    scores = (Q.astype(np.int32) @ K.T.astype(np.int32)) >> 4
    scores = scores >> 1

    attn = np.vstack([softmax_row(scores[i]) for i in range(scores.shape[0])])
    out = (attn.astype(np.int32) @ V.astype(np.int32)) >> 4
    return Q, K, V, scores, attn, out


def main():
    X  = load_matrix(DATA / "X.txt")
    WQ = load_matrix(DATA / "WQ.txt")
    WK = load_matrix(DATA / "WK.txt")
    WV = load_matrix(DATA / "WV.txt")

    Q, K, V, scores, attn, golden = attention(X, WQ, WK, WV)

    print("Q:\n", Q)
    print("K:\n", K)
    print("V:\n", V)
    print("scores (scaled):\n", scores)
    print("attn weights:\n", attn)
    print("golden output:\n", golden)
    print("as real (/16):\n", golden / FRAC)

    out_path = DATA / "output.txt"
    if out_path.exists():
        hw = load_matrix(out_path)
        print("\noutput:\n", hw)
        if np.array_equal(hw, golden):
            print("PASS")
        else:
            print("FAIL")
            print("diff:\n", hw - golden)
            raise SystemExit(1)
    else:
        print("\n(no output.txt found)")


if __name__ == "__main__":
    main()
