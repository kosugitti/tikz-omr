# tikzomr

TeX/TikZ で作ったマークシートを読み取り，回答を CSV 化する R パッケージ。
An R package to create mark sheets with TeX/TikZ and read them into a response table.

- License: GPL-3 ・ Author: Koji E. Kosugi
- リポジトリ / repo: `github.com/kosugitti/tikz-omr`（R パッケージ名 / package name: `tikzomr`）

---

## 特長 / Why

```
問題を作る → TikZ でマークシートを作る（config が読み取り定義も兼ねる）
          → 試験・スキャン → すぐに回答 CSV
```

- **single source of truth**: 1 つの config から，組版する `.tex` と読み取り定義（マーク座標）が
  同時に決まる。読み取り位置を手で置く作業が要らない。
- **ローカル完結 / local only**: 答案画像をクラウドに送らない（プライバシー安全）。
- **四隅アライメント**: 位置決めマーク＋射影変換で，スキャンの傾き・拡縮・平行移動を自動吸収。
- One config yields both the typeset sheet and the reading definition; alignment is by four
  fiducials and a homography; everything runs locally.

対象範囲 / scope: マークシート生成＋読み取り。採点・IRT は対象外（利用者側 / your downstream）。

---

## インストール / Install

```r
# 依存: R パッケージ magick, pdftools（システムに ImageMagick, poppler）
remotes::install_github("kosugitti/tikz-omr")
```

マークシートの組版には LuaLaTeX（`lualatex`）と日本語フォント環境が必要。
Typesetting the sheet requires LuaLaTeX with a Japanese font setup.

---

## 使い方 / Usage

### 1. マークシートを作る / Generate a sheet

```r
library(tikzomr)

cfg <- default_config()                 # 2026 様式（75 問・ID 6 桁）
# 年度で変わる所だけ差し替え / change only what varies per year:
cfg$answer$n_questions <- 60
cfg$answer$col_split   <- list(c(1, 30), c(31, 60))
cfg$id$n_digits        <- 7

art <- make_marksheet(cfg,
  tex_path       = "marksheet.tex",
  marks_path     = "marksheet.marks.csv",     # 読み取り定義（座標）
  fiducials_path = "marksheet.fiducials.csv")
```

`marksheet.tex` を **LuaLaTeX で 2 回**組版する（`remember picture` の位置確定に 2 パス必要）。
Typeset with LuaLaTeX **twice** (fiducial positions need two passes):

```sh
lualatex marksheet.tex && lualatex marksheet.tex
```

### 2. スキャンを読み取る / Read scans

印刷 → 試験 → ADF スキャナで PDF 化（200dpi 推奨）。

```r
layout <- list(
  marks     = read.csv("marksheet.marks.csv"),
  fiducials = read.csv("marksheet.fiducials.csv"))

# 1 枚 / one sheet
res <- read_marksheet("one_scan.jpg", layout)

# 複数ページ PDF を一括 / a whole batch PDF
tbl <- read_marksheet_batch("all_students.pdf", layout)
write.csv(tbl, "responses.csv", row.names = FALSE)
review <- attr(tbl, "review")   # 要目視（複数塗り・ID 不明）/ items to eyeball
```

出力 / output: `source, ID1..IDn, M1..Mq`（AnswerSheet DIY 互換 / compatible）。

固定接頭辞 / fixed prefix: 学部コードなど全員共通の先頭文字は印字のみ・マーク対象外にできる。
`cfg$id$prefix <- "HP"` とすると，紙面に「先頭に HP」と刷られ，読み取り時にフル学籍番号
`id` 列（例 `HP123456`）が復元される（接頭辞なしなら従来どおり）。

### 3. GUI で行う / Use the local GUI

```r
run_omr_app()   # ブラウザで「マークシート工房」が開く（要 shiny, DT）
```

生成（config → `.tex`/PDF/読み取り定義）と読み取り（スキャン → responses.csv/review.csv）を
GUI で行える。すべてこの端末で動き，答案画像は外部に送信されない。
A local Shiny GUI for both generating sheets and reading scans; nothing leaves the machine.

### すぐ試す / Try the bundled example

```r
layout <- example_layout()      # 同梱の 2026 様式
res <- read_marksheet(
  system.file("examples", "sample_scan.jpg", package = "tikzomr"), layout)
# ID = 123456 ; M1=8, M2=2, M3=9, M4=3, M51=5, M60=8
```

---

## 状態 / Status

読み取りエンジン（`read_marksheet` / `read_marksheet_batch`），生成器（`make_marksheet`），
固定接頭辞 ID，ローカル GUI（`run_omr_app`）が動作，回帰テスト通過。検証済み Python 実装は
`python-reference/` にオラクルとして保持（配布物外）。

- v0.2（実装済み）: 固定接頭辞 ID（英字含む・印字のみ）
- v0.3（実装済み）: `run_omr_app()`（ローカル Shiny GUI「マークシート工房」）
- 今後 / next: 英字 ID 列 A-Z を塗る様式（Scantron 型），正答 2 モード，採点参考実装

### 検証 / Validation

- 2026 TikZ 様式: 空欄と実マークが二峰分離（0.00 vs 0.32–0.92），R が Python オラクルと一致
  （ID=123456・6 マーク）。生成器の marks は reader 定義と <0.1mm で一致。
- 2025 旧様式（横長）: 幾何は完璧（正答シート 74/75）。薄い鉛筆マークは閾値調整で対応。

---

## 設計 / Design

詳細は [`CLAUDE.md`](CLAUDE.md) を参照。See `CLAUDE.md` for the full design rationale.
