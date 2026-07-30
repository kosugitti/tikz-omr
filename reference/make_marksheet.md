# config からマークシート(.tex)と読み取り定義を生成する

同じ config から，組版用 `.tex` と，読み取り用の
`marks`（field,value,x_mm,y_mm）・
`fiducials`（corner,x_mm,y_mm）を生成する。両者は座標が一致する。

## Usage

``` r
make_marksheet(
  config = default_config(),
  tex_path = NULL,
  marks_path = NULL,
  fiducials_path = NULL
)
```

## Arguments

- config:

  [`default_config()`](https://kosugitti.github.io/tikz-omr/reference/default_config.md)
  と同形の list。

- tex_path:

  書き出す `.tex` のパス（NULL なら書き出さない）。

- marks_path:

  書き出す marks CSV のパス（NULL なら書き出さない）。

- fiducials_path:

  書き出す fiducials CSV のパス（NULL なら書き出さない）。

## Value

`list(tex=, marks=, fiducials=, id_prefix=)`。marks/fiducials/id_prefix
は そのまま
[`read_marksheet()`](https://kosugitti.github.io/tikz-omr/reference/read_marksheet.md)
の `layout` に渡せる（接頭辞が自動で引き継がれる）。
