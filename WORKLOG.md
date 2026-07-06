# WORKLOG — tikz-omr

## 2026-07-06 プロジェクト起ち上げ・Python 参照実装の完成と検証

### 経緯

「TikZ で作ったマークシートを自動で読み取る」構想から出発。既存の AnswerSheet DIY
（macOS 専用・2018 で更新停止・GUI で読み取り枠を手置き）を脱し，config を single source
of truth とする自作ツールを設計。データ解析基礎（`01_教育/2026_データ解析基礎/`）の
実運用が題材。

### やったこと

- **要件整理・設計確定**（CLAUDE.md）
  - スコープ = マークシート生成（TikZ）＋読み取り（scan→CSV）。採点/IRT は対象外。
  - エンジンは **全部 R・1 パッケージ `tikzomr`**（関数 API ＋ 同梱ローカル Shiny）に一本化決定。
    R版/Python版の 2 本持ちは保守二重化のため不採用。Python は参照実装（オラクル）として保持。
  - 配布 = `install_github`，GUI ローカル起動でクラウドに答案を出さない（プライバシー安全）。
  - README 日英併記，ライセンス GPL-3。
  - ID 一般化 = 可変桁数の数字＋任意の固定接頭辞（印字のみ）。英字列 A-Z は設計だけ確保し実装は後回し。

- **Python 参照実装（検証済み・`python-reference/omr/`）**
  - `config.py` レイアウト定義＋ID/解答ブロックの格子計算（`n_questions`/`col_split`/`n_id_digits` 可変）
  - `fiducials.py` 四隅マーク検出（塗り四角ブロブ，下限 4mm で年度差吸収）・左上最大で天地判定
  - `reader.py` 太線枠を検出→自己スケール→config 格子でセル中心算出→窓の暗画素率で塗り判定
  - `batch.py` 複数ページ PDF/フォルダ → `responses.csv`（`source,ID1..IDn,M1..Mq`）＋ `review.csv`

- **検証**
  - 2026 TikZ サンプル（`examples/sample_scan.jpg`）: ID=123456，M1=8/M2=2/M3=9/M4=3/M51=5/M60=8 を正しく復元。
    全 810 セルの塗り率が二峰分離（空欄 796=0.00 / 実マーク 12=0.32–0.92），閾値 0.20 で誤検出ゼロ。
    セル中心の重ね描き（`examples/overlay_*.png`）で全楕円中心に乗ることを目視確認。
  - 2025 前期（旧 Keynote 横長，`Labo/…/2025_データ解析基礎/Test_season1/`）: sheetdef の座標を
    テンプレートに使い 83 ページを AnswerSheet DIY 出力 CSV と突合。**座標系 bottom-left の罠**を発見・解決
    （`y'=H-y` で反転）。正答シート（ID=999999）で ID 完全一致・解答 74/75，赤ドットが全楕円中心に乗る。
    学生の薄い鉛筆マーク（塗り率 0.15–0.19）は閾値 0.20 で取りこぼし＝旧様式ワーストケース。公開対象外のため深追いせず。

- **リポジトリ整備**
  - `~/Dropbox/Git/tikz-omr` 作成。CLAUDE.md（設計確定版），README（日英），LICENSE（GPL-3），
    .gitignore，`python-reference/`（参照実装＋requirements），`templates/marksheet_example.tex`，
    `examples/`（PDF・スキャン・responses・overlay）。

### 次回への引き継ぎ（v0.1 の中身）

1. **R spike（最優先・唯一の技術的懸念）**: `magick`＋`imager`/`EBImage` で四隅マークの
   ブロブ検出，base `solve()` で 4 点ホモグラフィ。2026 サンプルで Python オラクルと同一結果か検証。
   OK なら本実装へ，不安なら Python 維持を再検討。
2. R パッケージ骨格（DESCRIPTION/NAMESPACE/R/, roxygen2, testthat）。`read_marksheet()` から。
3. `templates`/`examples` を `inst/` 配下へ移す。
4. GitHub 公開（`gh repo create kosugitti/tikz-omr`）は spike とパッケージ骨格が最小限動いてから。

### R spike 成功（同日）— R 一本の道が確定

`magick` のみで，Python オラクルと一致（`01_教育/2026_データ解析基礎/omr/spike_r.R`）。

- 四隅検出: **隅近傍の暗画素射影で矩形を切る**方式（OpenCV 輪郭検出不要）。TL/TR/BL/BR とも Python と誤差 ≤1px。
- 塗り率: 塗りセル 0.901（PY 0.921），空セル 0.000（PY 0.000）。
- ホモグラフィ: base `solve()` で 4 点 DLT，round-trip 誤差ゼロ。
- 依存は `magick` だけ（`imager`/`EBImage` すら不要）。`pdftools` は PDF 描画用に別途。

含意: R 版 reader は **四隅ホモグラフィ＋config 座標**（枠検出非依存の汎用筋）で書ける。
generator が page 座標を吐く方針と噛み合う。次は R パッケージ骨格と reader 移植。

### 未解決・メモ

- R での四隅ブロブ検出の安定性が唯一の未知数（OpenCV ほど枯れていない）。
- 回帰テスト素材: `Labo/Edu：講義資料/専修大学/…データ解析基礎`, `Dkiso1` 系に歴年スキャン多数。
- generator（config→.tex）は v0.2。現状は既存 `marksheet_example.tex` を紙とし，その定数を config に写している。
