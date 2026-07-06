# Python 参照実装 / reference implementation

検証済みの OMR エンジン（OpenCV）。R パッケージ移植のオラクルとして保持する。
配布物には含めない（公開パッケージは R の `tikzomr` のみ）。

Validated OMR engine used as the oracle for the R port. Not part of the distributed package.

## modules
- `omr/config.py`    レイアウト定義＋格子計算
- `omr/fiducials.py` 四隅マーク検出・天地判定
- `omr/reader.py`    1 枚読み取り
- `omr/batch.py`     複数ページ → CSV
