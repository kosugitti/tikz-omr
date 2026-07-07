# 人間の目視確認用: スキャン1枚に「四隅・各マーク中心・検出した塗り」を重ねた注釈画像を作る。
# エラーや薄いマークの答案を、ファイル/ページ指定で目で確かめるためのプレビュー。

# 入力（magick 画像 / 画像パス / PDF パス）→ 表示用 magick 画像
.load_image <- function(input, page = 1L, dpi = 200) {
  if (inherits(input, "magick-image")) return(input)
  if (is.character(input) && length(input) == 1L) {
    if (grepl("\\.pdf$", input, ignore.case = TRUE)) {
      bmp <- pdftools::pdf_render_page(input, page = page, dpi = dpi)
      return(magick::image_read(bmp))
    }
    return(magick::image_read(input))
  }
  stop("input は magick 画像・画像パス・PDF パスのいずれかにしてください")
}

#' スキャン1枚に検出結果を重ねた注釈画像を返す（目視確認用）
#'
#' 四隅フィデューシャル（青枠），全マーク中心（薄い点），検出した塗り（1 つなら緑，
#' 同一設問で複数塗りなら赤）を重ねる。塗り位置がバブルからずれていないか，薄いマークが
#' 取りこぼされていないかを目で確認できる。`read_marksheet_batch()` の属性 `"sources"` で
#' 番号→ファイル/ページを引けば，要目視の答案だけを狙って確認できる。
#'
#' @param input magick 画像・画像パス・PDF パスのいずれか。
#' @param layout `example_layout()` と同形の `list(marks, fiducials)`。
#' @param page PDF の場合のページ番号。
#' @param dpi PDF 描画解像度。
#' @param dark 暗画素閾値。
#' @param fill_thr 塗りとみなす塗り率の下限（`read_marksheet()` と揃える）。
#' @param win_mm サンプリング窓の半径（mm）。
#' @return 注釈を描いた `magick` 画像。`magick::image_write()` で保存できる。
#' @export
overlay_marksheet <- function(input, layout, page = 1L, dpi = 200,
                              dark = 140, fill_thr = 0.13, win_mm = c(1.1, 0.8)) {
  gm  <- .load_gray(input, page = page, dpi = dpi)
  img <- .load_image(input, page = page, dpi = dpi)

  # 天地補正（read_marksheet と同じ）: 表示画像も 180 度回す
  fid <- detect_fiducials(gm, dark = dark)
  if (which.max(vapply(fid, function(f) f$side, numeric(1))) != 1L) {
    gm <- gm[nrow(gm):1, ncol(gm):1]
    img <- magick::image_rotate(img, 180)
    fid <- detect_fiducials(gm, dark = dark)
  }

  corners <- c("TL", "TR", "BL", "BR")
  fdf <- layout$fiducials
  src <- as.matrix(fdf[match(corners, fdf$corner), c("x_mm", "y_mm")])
  dst <- t(vapply(corners, function(k) c(fid[[k]]$cx, fid[[k]]$cy), numeric(2)))
  H <- homography(src, dst)

  d_px <- sqrt(sum((dst[1, ] - dst[2, ])^2))
  d_mm <- sqrt(sum((src[1, ] - src[2, ])^2))
  pxmm <- d_px / d_mm
  rx <- win_mm[1] * pxmm; ry <- win_mm[2] * pxmm

  marks <- layout$marks
  pts <- t(apply(as.matrix(marks[, c("x_mm", "y_mm")]), 1, function(p) apply_h(H, p)))
  fills <- vapply(seq_len(nrow(marks)),
                  function(i) .fill_ratio(gm, pts[i, 1], pts[i, 2], rx, ry, dark),
                  numeric(1))

  # 描画（image_draw は左上原点・y 下向きで画素座標に一致）
  ann <- magick::image_draw(img)

  # 四隅
  for (k in seq_along(fid)) {
    f <- fid[[k]]; s <- f$side / 2
    graphics::rect(f$cx - s, f$cy - s, f$cx + s, f$cy + s,
                   border = "#1B6FB3", lwd = 3)
  }
  # 全マーク中心（薄い点）: 幾何確認用
  graphics::points(pts[, 1], pts[, 2], pch = 1, cex = 0.7, col = "#9AA6AE", lwd = 1)

  # 設問ごとの検出（緑=1つ / 赤=複数）
  for (fld in unique(marks$field)) {
    idx <- which(marks$field == fld)
    fr <- fills[idx]
    hit <- idx[fr >= fill_thr]
    col <- if (length(hit) > 1L) "#D24B3E" else "#1E9E5A"
    for (h in hit)
      graphics::symbols(pts[h, 1], pts[h, 2], circles = max(rx, ry) * 1.15,
                        inches = FALSE, add = TRUE, fg = col, lwd = 4)
  }
  grDevices::dev.off()
  ann
}
