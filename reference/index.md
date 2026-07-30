# Package index

## マークシートを作る / Generate

config から .tex・PDF・読み取り定義を同時に作る

- [`make_marksheet()`](https://kosugitti.github.io/tikz-omr/reference/make_marksheet.md)
  : config からマークシート(.tex)と読み取り定義を生成する
- [`default_config()`](https://kosugitti.github.io/tikz-omr/reference/default_config.md)
  : 既定レイアウト（2026 様式）の config を返す

## スキャンを読み取る / Read

スキャン画像を回答テーブルへ。目視確認のオーバーレイも

- [`read_marksheet()`](https://kosugitti.github.io/tikz-omr/reference/read_marksheet.md)
  : マークシート1枚を読み取る
- [`read_marksheet_batch()`](https://kosugitti.github.io/tikz-omr/reference/read_marksheet_batch.md)
  : PDF・フォルダ・ファイル群を一括読み取りして応答表を返す
- [`overlay_marksheet()`](https://kosugitti.github.io/tikz-omr/reference/overlay_marksheet.md)
  : スキャン1枚に検出結果を重ねた注釈画像を返す（目視確認用）

## 同梱例・GUI / Example & GUI

- [`example_layout()`](https://kosugitti.github.io/tikz-omr/reference/example_layout.md)
  : 同梱サンプル（2026 様式）のレイアウト定義を返す
- [`run_omr_app()`](https://kosugitti.github.io/tikz-omr/reference/run_omr_app.md)
  : マークシート工房（ローカル Shiny GUI）を起動する

## 低水準の幾何 / Low-level geometry

四隅検出と射影変換。通常は直接使わない

- [`detect_fiducials()`](https://kosugitti.github.io/tikz-omr/reference/detect_fiducials.md)
  : 四隅の位置決めマークを検出する
- [`homography()`](https://kosugitti.github.io/tikz-omr/reference/homography.md)
  : 4点対応から射影変換（ホモグラフィ）行列を解く
- [`apply_h()`](https://kosugitti.github.io/tikz-omr/reference/apply_h.md)
  : ホモグラフィ行列で1点を写す
