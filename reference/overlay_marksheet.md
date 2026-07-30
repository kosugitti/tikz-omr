# スキャン1枚に検出結果を重ねた注釈画像を返す（目視確認用）

四隅フィデューシャル（青枠），全マーク中心（薄い点），検出した塗り（1
つなら緑，
同一設問で複数塗りなら赤）を重ねる。塗り位置がバブルからずれていないか，薄いマークが
取りこぼされていないかを目で確認できる。[`read_marksheet_batch()`](https://kosugitti.github.io/tikz-omr/reference/read_marksheet_batch.md)
の属性 `"sources"` で
番号→ファイル/ページを引けば，要目視の答案だけを狙って確認できる。

## Usage

``` r
overlay_marksheet(
  input,
  layout,
  page = 1L,
  dpi = 200,
  dark = 140,
  fill_thr = 0.13,
  win_mm = c(1.1, 0.8)
)
```

## Arguments

- input:

  magick 画像・画像パス・PDF パスのいずれか。

- layout:

  [`example_layout()`](https://kosugitti.github.io/tikz-omr/reference/example_layout.md)
  と同形の `list(marks, fiducials)`。

- page:

  PDF の場合のページ番号。

- dpi:

  PDF 描画解像度。

- dark:

  暗画素閾値。

- fill_thr:

  塗りとみなす塗り率の下限（[`read_marksheet()`](https://kosugitti.github.io/tikz-omr/reference/read_marksheet.md)
  と揃える）。

- win_mm:

  サンプリング窓の半径（mm）。

## Value

注釈を描いた `magick`
画像。[`magick::image_write()`](https://docs.ropensci.org/magick/reference/editing.html)
で保存できる。
