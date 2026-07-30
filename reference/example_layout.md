# 同梱サンプル（2026 様式）のレイアウト定義を返す

[`read_marksheet()`](https://kosugitti.github.io/tikz-omr/reference/read_marksheet.md)
に渡す `layout`（marks と fiducials）を，パッケージ同梱の CSV
から読み込む。自作様式ではこれと同じ列を持つ data.frame を用意する。

## Usage

``` r
example_layout()
```

## Value

`list(marks=, fiducials=)`。marks は `field,value,x_mm,y_mm`， fiducials
は `corner,x_mm,y_mm`。
