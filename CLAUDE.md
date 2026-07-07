# tikz-omr — 設計方針（CLAUDE.md）

TeX/TikZ で作ったマークシートを読み取り，回答を CSV 化する一連のフリーソフトウェア。

- リポジトリ: `~/Dropbox/Git/tikz-omr` → `github.com/kosugitti/tikz-omr`
- R パッケージ名: **`tikzomr`**（Rはハイフン不可のためリポジトリ名と分ける）
- ライセンス: GPL-3
- 作者: 小杉考司

---

## 1. 目的とスコープ

### 目的

授業の定期試験・確認テストで使うマークシートを，次の一連の流れで運用する。

```
問題を作る → TikZ でマークシートを作る → 読み取り設定が自動的に決まる
          → 試験実施・スキャン → すぐに回答 CSV ができる
```

手作業の枠置き（従来 AnswerSheet DIY で GUI クリックしていた作業）を廃し，
マークシートを記述した config そのものが読み取り定義を兼ねる（single source of truth）。

### 公開スコープ

- **マークシート生成**: TikZ での組版（テンプレート＋config）
- **読み取り**: スキャン画像 → 回答 CSV

### スコープ外（利用者側の責務。参考実装のみ同梱）

- 問題内容・項目プール
- 採点，IRT 等化，成績化

---

## 2. アーキテクチャ: 全部 R・1 パッケージ

エンジンは **R パッケージ `tikzomr` に一本化**する。OMR エンジンを 2 本（R版/Python版）持つと
保守が二重化し挙動がずれるため作らない。読者（R を学ぶ学生・教員）に最も自然で，
`install_github` 1 行で入り，GUI はローカル起動でクラウドに答案を出さない（プライバシー安全）。

```
R パッケージ tikzomr
  ├─ 関数 API : read_marksheet("scan.pdf", config) -> data.frame / CSV
  │            make_marksheet(config) -> .tex（generator, v0.2）
  └─ ローカル GUI : run_omr_app()  ← inst/app の Shiny をローカル起動（v0.3）

install: remotes::install_github("kosugitti/tikzomr")
```

### なぜ R で完結できるか（必要な画像処理は軽い）

全体ワープは不要で，点を写して局所サンプルするだけ。使うのは 3 つ。

| 工程 | R の手段 |
|---|---|
| PDF → 画像 | `pdftools::pdf_render_page` |
| 画像読み・二値化 | `magick` |
| 四隅マークのブロブ検出 | `imager::label` / `EBImage::bwlabel` |
| ホモグラフィ（4点→3x3行列） | base `solve()`（8元連立） |
| 塗り率 | 窓の `mean()` |

### Python 参照実装の位置づけ

`python-reference/` に，先に作り検証済みの Python + OpenCV 版を残す。
**正しく動くことを実証済みのオラクル**として，R 移植の答え合わせ（同一スキャンで同一結果か）に使う。
公開パッケージには含めない（配布物は R パッケージのみ）。

---

## 3. single source of truth（config → 紙 と 読み取り定義）

```
layout config (list) ──┬─→ make_marksheet() ─→ marksheet.tex ─(lualatex)→ PDF → 印刷
                       └─→ 読み取り定義（枠構造・格子）
                                 │
        ADF スキャン(200dpi) ─→ read_marksheet() ─┬─→ responses.csv
                                                  └─→ review.csv（要目視）
```

generator（`make_marksheet()`）は実装済み。`default_config()` から `.tex` と読み取り定義
（marks/fiducials CSV）を同時に生成し，生成 marks は同梱 example と <0.1mm で一致（検証済み）。
生成した `.tex` を LuaLaTeX で **2 回**組版すると，reader のマークが全楕円中心に乗る。

---

## 4. 確定した設計判断

| 論点 | 決定 |
|---|---|
| 位置合わせ | 四隅フィデューシャル（黒四角，左上のみ大）＋太線枠の自己スケール。傾き・拡縮・平行移動に自動追従 |
| 塗り判定 | 窓内の暗画素率（fill ratio）＋閾値（既定 0.13）。空欄と実マークが二峰分離。鉛筆マークは薄いので既定を低めに（0.20 は清刷り前提の旧既定）。実データ 86 枚で 0.10–0.13 が誤検出ゼロ・一致 99%超，0.08 未満で誤検出が出る |
| 天地判定 | 左上マークが最大 → 正立。違えば 180 度回転 |
| 年度変化 | `n_questions` / `col_split` / `n_options` を config パラメータ化（問題数は 60〜80 と変わる。各問 1 マーク独立） |
| 正答セット | 2 モード: (a) 予約 ID（例 999999）のスキャンを正答として抽出 (b) answer_key を直接指定 |
| 出力形式 | `source,ID1..IDn,M1..Mq`（AnswerSheet DIY 互換） |

### ID（学籍番号）の一般化モデル

学籍番号は大学ごとに桁数・文字種・固定接頭辞が異なる。config で吸収する。

```r
id = list(
  n_digits = 6, symbols = c(1:9, 0),  # マークする数字桁（現行の主様式）
  label  = "【学籍番号】",             # ブロック見出し（旧 prefix）
  prefix = "HP",                       # 固定接頭辞（印字のみ・マーク対象外，任意）
  ...                                  # x0/colw/y0/rowh 等の座標
)
```

- **v0.1 対応**: 可変桁数の数字 ID。
- **v0.2 対応（実装済み）**: 固定接頭辞（英字を含む・印字のみ・マーク対象外）。
  `id$label`（見出し）と `id$prefix`（固定接頭辞）を分離。generator は見出し行に
  「（先頭に HP が付きます・マーク不要）」と印字し，バブル配置・幾何は不変。
  `make_marksheet()` は接頭辞を戻り値 `id_prefix` に載せ，そのまま `read_marksheet()` の
  `layout` に渡せる。reader は接頭辞があるとき先頭にフル学籍番号 `id` 列（接頭辞＋マーク桁）を
  追加，接頭辞なしの既定では出力・挙動とも従来と一切変わらない。
- **将来拡張（設計だけ確保）**: 英字列 A-Z（26 バブル）を **塗る** 様式。Scantron 型の
  縦ストラップ配置が要るため実装は後回し（紙面・UI が重い）。

### 既知の罠（記録）

- AnswerSheet DIY の sheetdef 座標は **bottom-left 原点**。画像(top-left)系へ `y' = H - y` で反転しないとセルがずれる（2025 突合で発覚・解決）。
- 検出枠はストローク外周 bbox。中心線は外周から stroke/2 内側で補正。
- 位置決めマークのサイズは年度で違う（2026: 9–12.8mm / 2025 旧様式: 5.5mm）。検出下限を 4mm に緩めて両対応。
- 生成 `.tex` は `remember picture, overlay` を使うため **LuaLaTeX を 2 回**通す必要がある（初回は `current page` 位置が未確定で四隅がずれる）。README・生成物の運用に明記。

---

## 5. リポジトリ構成（目標）

```
tikz-omr/
  DESCRIPTION, NAMESPACE           R パッケージメタ
  R/                               エンジン（read_marksheet, config, fiducials, homography, decode）
  man/                             roxygen 生成ドキュメント
  inst/app/                        ローカル Shiny GUI（v0.3）
  inst/templates/                  TikZ マークシート雛形（.tex）
  inst/examples/                   サンプル（PDF, スキャン, responses.csv, overlay）
  tests/testthat/                  回帰テスト（Python オラクルとの一致含む）
  python-reference/                検証済み Python 実装（オラクル。配布物外）
    omr/{config,fiducials,reader,batch}.py
  README.md                        日英併記
  CLAUDE.md / WORKLOG.md
  LICENSE                          GPL-3
```

現在は `python-reference/` 相当（`omr/*.py`）とサンプルのみ配置済み。R パッケージ骨格はこれから。

---

## 6. データ形式

- **config**: R の list（§4 の id ＋ answer ＋ option_labels）。座標は TikZ ローカル単位（1=0.98mm），reader は枠実測で自己スケール。
- **responses.csv**: `source, ID1..IDn, M1..Mq`。空欄は空文字。source は `"<file> [i/N]"`。
- **review.csv**: `source, id, problem, blanks`（「ID不明桁あり」「複数塗り:M12,M40」等）。

---

## 7. 検証状況

- **2026 TikZ 様式（公開対象）**: 完璧。空欄 796 セル=0.00 / 実マーク 12 セル=0.32–0.92 と二峰分離，誤検出ゼロ。ID・解答とも正しく復元（Python 実装で確認）。
- **2025 前期（TikZ 以前の旧 Keynote 横長）**: 幾何は完璧（正答シート ID 完全一致・解答 74/75，セル中心が全楕円中心に乗る）。学生の薄マーク（塗り率 0.15–0.19）は閾値 0.20 で取りこぼす＝旧様式のワーストケース。公開対象外のため深追いしない。
- **2025 後期（本 TikZ 様式・HP 接頭辞つき・実授業答案 86 枚，2026-01-22 実施）**: 生成元 tex の定数から
  page-mm レイアウトを再構成（grid 原点＝(左余白+1.5, 上余白+5.0)＝ltjs のヘッダ分の較正のみ）。
  読取失敗ゼロ・誤検出ゼロ。しきい値 0.20→96.8%，0.13→98.9%，0.10→99.5%（いずれも誤検出0），
  0.08 で誤検出が出始める。不一致は全て薄マークの取りこぼしで要目視に回る＝安全側。
  → 既定 fill_thr を 0.13 に引き下げる根拠。**個人情報のため答案・GT はテスト資産に同梱しない**（検証記録のみ）。
- 検証素材: `Labo/Edu：講義資料/専修大学/…データ解析基礎`, `Dkiso1` 系に歴年スキャン多数 → 回帰テストに利用。

---

## 8. ロードマップ

- **v0.1（完了）**: R エンジン（`read_marksheet`/`read_marksheet_batch`），2026 サンプルで
  Python オラクルと一致，パッケージ骨格，回帰テスト（read 11 本），日英 README，R CMD INSTALL 通過。
  R spike（四隅検出＋ホモグラフィ）成功済み＝唯一の懸念は解消。
- **v0.2（進行中）**: `make_marksheet()` — config → `.tex` ＋ 読み取り定義。
  固定接頭辞（英字含む・印字のみ）対応済み＝`id$label`/`id$prefix` 分離，reader が
  フル学籍番号 `id` 列を復元（既定は従来どおり）。生成/読取テスト計 25 本超。
  残: 英字 ID 列 A-Z を **塗る** 様式（Scantron 型），正答 2 モード（予約 ID スキャン / CSV），採点参考実装。
- **v0.3（実装済み）**: `run_omr_app()` — ローカル Shiny GUI「マークシート工房」。
  `inst/app/app.R` に本体（生成タブ＝config→プレビュー/.tex/PDF/読取定義，読取タブ＝スキャン
  →responses.csv/review.csv＋サマリータイル＋塗り率二峰ヒストグラム），`R/app.R` の
  `run_omr_app()` が `system.file("app")` を `shiny::runApp()`。依存 shiny/DT は Suggests＋
  requireNamespace ガード。PDF は lualatex 検出時のみ。意匠は四隅マーク／楕円バブル／
  塗り率二峰／読取赤ドットを素材にした計器風・ライト/ダーク両対応。sample_scan で
  id=HP123456 まで実起動検証済み（chromote ヘッドレス撮影）。塗り率分布用に reader へ
  `attr "fills"` を追加（非破壊）。
  - 入力3モード: `read_marksheet_batch()` を PDF・フォルダ・ファイル群のいずれも受けるよう一般化
    （`.expand_sources()`。属性 `"sources"` に番号→ファイル/ページ対応）。アプリはアップロード
    （元名で temp 複製）とフォルダパス欄の両対応。
  - プレビュー: `overlay_marksheet()` が四隅・全マーク中心・検出塗り（緑/複数=赤）を重ねた
    magick 画像を返す。アプリは番号指定＋要目視ジャンプで表示（`imageOutput`）。エラー枚は
    その旨表示。既定 fill_thr=0.13（スライダーで可変）。
    注意: `image_resize` は image_draw 出力を壊すのでフル解像度で書き出しブラウザ縮小。
- docs/ 公開サイト，小杉サイトからの「TeX/TikZ でマークシートを作り読み取る一連のフリーソフトウェア」リンク

---

## 9. 開発規約

- R パッケージ流儀（roxygen2, testthat, DESCRIPTION）。既存 exametrika 系と同様。
- 依存: `pdftools`, `magick`, `imager` または `EBImage`（spike で選定）。
- 読み取り基準解像度 200dpi。スキャンは ADF・A4。
- コメント・ドキュメントは日本語。公開 README は日英併記。
- 作業履歴は `WORKLOG.md`，状態要約はホーム `~/.claude/CLAUDE.md` の索引に 1 行。

## 索引ステータス退避 (2026-07-07)

ホームCLAUDE.md索引の肥大化解消のため，圧縮前のステータス全文をここへ退避。以後の最新状況はWORKLOG.mdと本ファイル上部を参照。

TikZで作ったマークシートをスキャン→CSV化するフリーソフト。旧AnswerSheet DIY(macOS専用・更新停止)を脱し，config を single source of truth に。スコープ=生成(TikZ)＋読取，採点/IRTは対象外。**エンジンは全部R・1パッケージ tikzomr に一本化決定**(関数API＋同梱ローカルShiny，install_github配布，クラウドに答案を出さない)。Python参照実装(python-reference/omr)は検証済オラクルとして保持。検証: 2026 TikZサンプルで完璧(ID=123456・塗り率二峰分離0.00/0.32-0.92・誤検出0)，2025旧様式でも幾何実証(座標bottom-left罠を解決・正答シート74/75)。ID一般化=可変桁数＋固定接頭辞印字(英字A-Zは設計のみ)。ライセンスGPL-3・README日英。**R spike成功(magickのみで四隅検出射影法＋ホモグラフィsolve()がPythonと一致・唯一の懸念解消)→v0.1 Rパッケージ完成**: read_marksheet/read_marksheet_batch/make_marksheet(config→.tex＋読取定義,絶対page-mm,生成marksは同梱と<0.1mm一致)/example_layout。R CMD INSTALL通過・回帰テスト21本全通過。生成.texはLuaLaTeX2パス必須(remember picture)。次=GitHub公開(gh repo create kosugitti/tikz-omr)→v0.2英字ID/正答2モード→v0.3 run_omr_app(ローカルShiny)。詳細→Git/tikz-omr/{CLAUDE,WORKLOG}.md
