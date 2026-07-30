# 四隅の位置決めマークを検出する

マークシート四隅の黒い四角（左上のみ大きい）を，隅近傍の暗画素射影から矩形として
切り出す。OpenCV 相当の輪郭検出を使わず `magick`
のグレースケール行列のみで動く。

## Usage

``` r
detect_fiducials(gm, dark = 140, frac = 0.22, rowthr = 25)
```

## Arguments

- gm:

  グレースケール行列 `gm[x, y]`（0-255，x=列/幅，y=行/高）。

- dark:

  暗画素とみなす閾値（既定 140）。

- frac:

  各隅で探索する象限の割合（既定 0.22）。

- rowthr:

  暗ブロックとみなす暗画素数の下限（既定 25）。

## Value

`list(TL=, TR=, BL=, BR=)`。各要素は `list(cx, cy, side)`。
