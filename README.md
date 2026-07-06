# tikz-omr

TeX/TikZ で作ったマークシートを読み取り，回答を CSV 化する一連のフリーソフトウェア。
A free-software toolchain to create mark sheets with TeX/TikZ and read them into CSV.

- R package name: `tikzomr`
- License: GPL-3
- Author: Koji E. Kosugi

---

## これは何か / What it is

```
問題を作る → TikZ でマークシートを作る → 読み取り設定が自動的に決まる
          → 試験・スキャン → すぐに回答 CSV
```

Create a mark sheet with TikZ, and its reading definition is determined by the **same
configuration** (single source of truth). Scan the filled sheets and get a response CSV.
No manual placement of read positions, and everything runs locally (student data never
leaves your machine).

### スコープ / Scope

- **含む / included**: マークシート生成（TikZ）＋読み取り（scan → CSV）
- **含まない / excluded**: 採点・IRT 等化・成績化（利用者側 / your own downstream）

---

## 状態 / Status

開発初期（v0.1 準備中）。エンジンは R パッケージ `tikzomr` に一本化する方針。
現在，検証済みの **Python 参照実装**（`python-reference/`）が動作する。R 移植はこれから。

Early development. The engine will ship as the R package `tikzomr`. A validated
**Python reference implementation** currently works and serves as the oracle for the R port.

### 検証 / Validation

- 2026 TikZ 様式: 空欄と実マークが二峰分離（0.00 vs 0.32–0.92），誤検出ゼロ。
- 2025 旧様式（横長）: 幾何は完璧（正答シート 74/75），薄い鉛筆マークは閾値調整で対応。

---

## 使い方（参照実装 / Python reference）

```bash
cd python-reference
python -m venv .venv && ./.venv/bin/pip install opencv-python-headless numpy
cd omr
python batch.py <scan.pdf|dir|image> responses.csv
```

出力 / Output: `responses.csv`（`source, ID1..IDn, M1..Mq`）と `responses_review.csv`（要目視）。

---

## ロードマップ / Roadmap

- **v0.1**: R engine (fiducials, homography, fill) + validate vs Python oracle + example `.tex` + samples
- **v0.2**: `make_marksheet(config)` — generate `marksheet.tex` and reading definition from one config
- **v0.3**: `run_omr_app()` — local Shiny GUI (define layout, preview, read)
- **v0.4**: grading / answer-key reference (reserved-ID scan or CSV), regression tests

---

## 設計 / Design

詳細は [`CLAUDE.md`](CLAUDE.md) を参照。See `CLAUDE.md` for the full design rationale.
