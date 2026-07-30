# マークシート工房（ローカル Shiny GUI）を起動する

マークシートの生成（config → `.tex` / PDF / 読み取り定義）と読み取り
（スキャン → responses.csv / review.csv）をブラウザ上の GUI で行う。
すべてこの端末上で動き、答案画像は外部に送信されない。

## Usage

``` r
run_omr_app(...)
```

## Arguments

- ...:

  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html)
  に渡す引数（`port`, `launch.browser`, `host` など）。

## Value

起動した Shiny
アプリ（[`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html)
の戻り値）。副作用としてアプリを起動する。

## Details

生成タブで PDF を書き出すには
`lualatex`（LuaLaTeX）がパスに必要。無い場合は `.tex` と読み取り定義 CSV
のみ書き出せる（PDF ボタンは無効表示）。

## Examples

``` r
if (FALSE) { # \dontrun{
run_omr_app()
} # }
```
