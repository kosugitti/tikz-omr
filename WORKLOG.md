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

### R パッケージ v0.1 ＋ 生成器（同日）

- **R パッケージ骨格**: DESCRIPTION（`tikzomr`）/NAMESPACE/R/man（roxygen rd）/tests。`R CMD INSTALL` 通過。
- **reader 移植**: `R/fiducials.R`（射影法・spike 移植），`R/homography.R`（`solve()`），
  `R/reader.R`（`read_marksheet`/`read_marksheet_batch`/`example_layout`，四隅→page-mm→スキャンの
  ホモグラフィ→塗り率→デコード）。座標基盤 `inst/examples/*.marks.csv`/`*.fiducials.csv`（page-mm）を同梱。
  2026 サンプルで **Python オラクルと完全一致**（ID=123456・6 マーク）。
- **生成器**: `R/generator.R`（`make_marksheet`/`default_config`）。config→`.tex`＋marks/fiducials を
  すべて絶対 page-mm で生成。生成 marks は同梱 example と **<0.1mm 一致**。生成 `.tex` を LuaLaTeX で
  **2 回**組版→200dpi 描画→reader のマークが全楕円中心に乗ることを overlay で確認。
  → config が紙と読み取り定義の単一の源であることが閉じた。
- **テスト**: read 11 本＋generator 10 本＝計 21 本すべて通過。
- **罠**: `remember picture, overlay` は LuaLaTeX 2 パス必須（初回は四隅が 0 個検出＝位置未確定）。

### 未解決・メモ

- R での四隅ブロブ検出の安定性が唯一の未知数（OpenCV ほど枯れていない）。
- 回帰テスト素材: `Labo/Edu：講義資料/専修大学/…データ解析基礎`, `Dkiso1` 系に歴年スキャン多数。
- generator（config→.tex）は v0.2。現状は既存 `marksheet_example.tex` を紙とし，その定数を config に写している。

## 2026-07-07 v0.2 固定接頭辞（英字ID）対応

- **方針決定**: 英字 ID の対応として、A-Z を塗る Scantron 型（26 バブル）ではなく、
  ユーザ選択により「固定接頭辞のみ（印字のみ・マーク対象外）」を実装。学部コード等が
  固定の大学向け（例: `HP` + 数字6桁）。A-Z を塗る様式は設計だけ確保し後回し。
- **generator.R**:
  - `default_config()$id` の `prefix = "【学籍番号】"` を `label`（見出し）と
    `prefix = NULL`（固定接頭辞）に分離。
  - `.build_tex()` は見出しに `id$label` を使い、`id$prefix` 指定時は
    「（先頭に HP が付きます・マーク不要）」を追記印字。バブル配置・幾何は不変。
  - `make_marksheet()` の戻り値に `id_prefix` を追加（そのまま reader の layout に渡せる）。
- **reader.R**: `read_marksheet()` に `id_prefix = NULL` 引数を追加。NULL なら
  `layout$id_prefix` を参照。非空ならフル学籍番号 `id` 列（接頭辞＋マーク桁の連結）を
  先頭に付与。**既定（接頭辞なし）は出力列・挙動とも従来と完全に一致**（回帰安全）。
- **検証**: sample_scan で `id_prefix="HP"` → `id="HP123456"`・ID1..6 不変。layout 自動引継ぎも一致。
  接頭辞付き `.tex` を LuaLaTeX 2 パスで組版→PNG 目視で見出し印字・バブル位置とも正常。
- **テスト**: generator に 2 本・reader に 2 本追加。全テスト通過（generator 17 / read 16 expectation）。
- **残**: A-Z を塗る様式（Scantron 型・縦ストラップ配置）、正答 2 モード、採点参考実装。GitHub 公開。

## 2026-07-07 v0.3 ローカル Shiny GUI「マークシート工房」実装

- **UI モックアップ先行**: 実装前に想定 UI を HTML モックアップ（Artifact）で提示し方向を確認。
  四隅フィデューシャル／楕円バブル／塗り率二峰／読取赤ドットを素材にした計器風の意匠、
  ①作成／②読取の2タブ構成、ライト/ダーク両対応。ユーザ承認（日本語名「マークシート工房」採用）。
- **reader.R**: 塗り率分布の可視化用に `read_marksheet()` へ `attr(out,"fills")`（全マークの塗り率）、
  `read_marksheet_batch()` へ全ページ分の `attr "fills"` を追加。いずれも属性追加のみで非破壊。
- **inst/app/app.R**: Shiny 本体。
  - 生成タブ: config フォーム（タイトル/問題数/ID桁数/段組み/固定接頭辞）→ 実 `make_marksheet()`
    幾何のライブプレビュー（base plot で楕円＋四隅）→ `.tex`/読取定義CSV/PDF ダウンロード。
    PDF は `lualatex` 検出時のみ有効（tempdir で2パス組版）。
  - 読取タブ: スキャン（PDF/画像・複数可）アップロード → layout 選択（①の config or example_layout）
    → fill_thr スライダー/dpi/dark → 実行 → サマリータイル（枚数/正常/要目視/失敗）・responses（DT）・
    review（DT）・塗り率二峰ヒストグラム（しきい値を赤破線）→ responses.csv/review.csv ダウンロード。
  - 意匠 CSS はモックアップ準拠（トークンでライト/ダーク、bootstrap nav 上書き）。
- **R/app.R**: `run_omr_app(...)`。shiny/DT の requireNamespace ガード → `system.file("app")` を
  `shiny::runApp()`。NAMESPACE に export 追記、DESCRIPTION Suggests に shiny/DT 追加。
- **実起動検証**: Newton で magick/pdftools をソースビルド導入。chromote ヘッドレスで実起動撮影＝
  ①作成タブのライブプレビュー、②読取タブで sample_scan.jpg を実アップロード→実行→
  **id=HP123456・ID1..6=123456・M1..4=8,2,9,3、塗り率二峰ヒストグラム表示**まで確認。
  「読み取り実行」ボタンのアイコン肥大（`.btn-omr svg` サイズ漏れ）を修正。
- **テスト**: 既存 25 本超すべて通過（fills 属性追加の影響なし）。roxygen で run_omr_app.Rd 生成。
- **残**: 英字 A-Z を塗る様式（Scantron 型）、正答 2 モード、採点参考実装、GitHub 公開、docs サイト。

## 2026-07-07 過去実データ検証 → 既定しきい値引き下げ・入力3モード・目視プレビュー

- **実データ検証（2025年度後期・実授業答案86枚, 2026-01-22実施, 本TikZ様式・HP接頭辞）**:
  生成元 marksheet_2025_kouki.tex の定数から page-mm レイアウトを再構成。grid原点は
  (左余白15+1.5, 上余白12+5.0)＝ltjsのヘッダ分だけ較正すれば正答シート66/66完全一致。
  86枚を当時の読取CSVと突合: 読取失敗0・誤検出0。しきい値スイープ=0.20:96.8% / 0.13:98.9% /
  0.10:99.5%（誤検出0）/ 0.08:99.7%(誤検出4で谷越え)。不一致は全て薄マークの取りこぼし=安全側。
  ※答案・GTは個人情報のためテスト同梱せず、検証記録のみCLAUDE.md §7へ。
- **既定 fill_thr 0.20→0.13**（reader.R）。鉛筆マーク向け。アプリのスライダー初期値も0.13、注記追加。
- **入力3モード**: `read_marksheet_batch()` を一般化（`.expand_sources()`）。PDF1枚 / フォルダ /
  ファイルパスvector のいずれも可。属性 `"sources"`(source,path,page) を追加=番号→ファイル対応。
  アプリはアップロード（元名で temp 複製しフォルダ扱い）＋フォルダパス欄（優先）に対応。
- **目視プレビュー**: `overlay_marksheet()`(R/preview.R) を新設。四隅=青枠・全マーク中心=薄点・
  検出塗り=緑（複数塗り=赤）を magick 画像に重ねて返す。アプリ②に「プレビュー（目視確認）」
  カードを追加＝番号入力＋要目視ジャンプ(selectInput)→imageOutput表示、キャプションにID/問題。
  罠: `image_resize` が image_draw 出力を壊す→フル解像度で書き出しブラウザ側縮小で解決。
- **検証**: chromote でフォルダ読取（sheet_A/B）→サマリー2/2→プレビュー緑丸重ね まで実起動確認。
  既存テスト25本超すべて通過（既定0.13でも sample_scan の復元は不変）。NAMESPACE に
  overlay_marksheet を export。README/CLAUDE.md 更新。
- **残**: 英字A-Zを塗る様式、正答2モード、採点参考実装、GitHub公開、docsサイト。

## 2026-07-08 公開整備（R CMD check ハードニング）

- DESCRIPTION: Version 0.1.0→0.3.0、Title を「Create and Read TikZ-Generated Mark Sheets」に、
  URL/BugReports(GitHub) 追加、Imports に graphics/grDevices/stats を追加（overlay/setNames 用）。
- NAMESPACE: importFrom(stats, setNames) 追加。
- .Rbuildignore: ^LICENSE$ 追加（GPL-3 は標準ライセンスなのでビルド対象外・リポジトリには残す）。
- R CMD check 結果: 0 errors / 0 notes / 1 warning。残る warning は「R コード内の非ASCII」で、
  実体は日本語コメント＋少数の日本語文字列リテラル（stop メッセージ・default_config の日本語
  デフォルト・.build_tex のノードラベル）。規約「日本語コメント」と正当な日本語デフォルトのため
  不可避。GitHub install/実行には影響なし（CRAN 移植性の指摘・今回CRAN対象外）。受け入れる。

## 2026-07-10 公開・生成PDFの行ラベルはみ出し修正

- **GitHub公開完了**: origin main へ push 済（v0.2接頭辞→v0.3 GUI→閾値/入力/プレビュー→check整備の4コミット）。
  リポジトリ PUBLIC・日英説明つき。`remotes::install_github("kosugitti/tikz-omr")` で tikzomr 0.3.0 が
  正式導入できることを実機確認（全9関数 export）。タグ v0.3.0 作成・push 済。
- **不具合修正（生成PDF）**: `M10`〜`M75`・`N桁目` の3文字行ラベルが解答/ID枠の左境界を左にはみ出していた
  （2文字の M1-M9 は収まっていた）。左右の解答枠は間隔約2.9mmで余白拡張は枠衝突するため、枠は動かさず
  ラベル右端をバブル寄りに 2mm ずらして実効余白を 6→8mm に（generator.R の ID/解答 行ラベル 2箇所）。
  フォントは \scriptsize 維持。バブル座標・枠・読取定義は不変（marks一致テスト影響なし）。300dpiで
  左右両列＋ID欄が枠内に収まることを目視確認。commit/push 済。
- **環境メモ**: Newton で magick が古い ImageMagick dylib(.11)を要求してロード失敗→brew が .10 に動いていた。
  `install.packages("magick", type="source")` で現行 brew に合わせ再ビルドして解消（→memory feedback_magick_source_reinstall）。
- **次回の再開ポイント**: 推奨は「正答2モード＋採点参考実装」。正答=予約ID(999999)スキャン抽出 or answer_key CSV直接、
  素点集計・項目統計は参考実装(ビネット)としてコア外に。検証に使った2025後期データが answer_key/999999/item_stats
  を含む実運用パイプラインなので設計の下敷きにできる（データは個人情報につき同梱しない）。他=英字A-Z塗り様式、
  GitHub Release(日英告知)・pkgdown docs。
