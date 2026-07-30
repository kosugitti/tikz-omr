# PDF・フォルダ・ファイル群を一括読み取りして応答表を返す

入力は次のいずれでもよい。

- まとめ PDF 1 枚（1 ページ 1 枚）。`source` は `"file.pdf [i/N]"`。

- フォルダのパス。中の画像（jpg/png/tiff…）と PDF をすべて読む。

- ファイルパスの文字列ベクトル（画像・PDF 混在可）。

## Usage

``` r
read_marksheet_batch(input, layout, dpi = 200, ...)
```

## Arguments

- input:

  PDF パス，フォルダのパス，またはファイルパスの vector。

- layout:

  [`example_layout()`](https://kosugitti.github.io/tikz-omr/reference/example_layout.md)
  と同形。

- dpi:

  PDF 描画解像度。

- ...:

  [`read_marksheet()`](https://kosugitti.github.io/tikz-omr/reference/read_marksheet.md)
  に渡す引数（`fill_thr`, `dark`, `id_prefix` 等）。

## Value

data.frame（`source, ID1.., M1..`）。属性 `"review"` に要目視の
data.frame， `"fills"` に全マークの塗り率，`"sources"`
に読み取り単位の一覧
（`source, path, page`。プレビュー時に番号→ファイルの対応に使う）。
