# マークシート1枚を読み取る

マークシート1枚を読み取る

## Usage

``` r
read_marksheet(
  input,
  layout,
  page = 1L,
  dpi = 200,
  dark = 140,
  fill_thr = 0.13,
  win_mm = c(1.1, 0.8),
  id_prefix = NULL
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

  暗画素閾値（既定 140）。

- fill_thr:

  塗りとみなす塗り率の下限（既定 0.13）。鉛筆マークは薄いので既定を
  低めに取る。実データ（86 枚）では 0.10–0.13 で誤検出ゼロのまま一致 99%
  超， 0.08 を割ると二峰の谷を越えて誤検出が出始める。清刷り前提なら
  0.20 でもよい。

- win_mm:

  サンプリング窓の半径（mm）。`c(横, 縦)`。

- id_prefix:

  学籍番号の固定接頭辞（印字のみ・マーク対象外，例 `"HP"`）。
  `NULL`（既定）なら `layout$id_prefix`
  を使う。空文字なら接頭辞なし。非空なら 先頭にフル学籍番号
  `id`（接頭辞＋マーク桁の連結）列を追加する。既定では
  出力・挙動は従来と一切変わらない。

## Value

1 行の data.frame（列 = ID1.., M1..，接頭辞指定時は先頭に `id`）。 属性
`"review"` に要目視情報（複数塗り・空欄数）を格納。
