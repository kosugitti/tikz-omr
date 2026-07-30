# 既定レイアウト（2026 様式）の config を返す

[`make_marksheet()`](https://kosugitti.github.io/tikz-omr/reference/make_marksheet.md)
に渡す config。自作様式ではこの list を複製して数値を変える。
主に年度で変わるのは `id$n_digits` と `answer$n_questions` /
`answer$col_split`。

## Usage

``` r
default_config()
```

## Value

レイアウト config（list）。
