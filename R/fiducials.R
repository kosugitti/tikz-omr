#' 四隅の位置決めマークを検出する
#'
#' マークシート四隅の黒い四角（左上のみ大きい）を，隅近傍の暗画素射影から矩形として
#' 切り出す。OpenCV 相当の輪郭検出を使わず `magick` のグレースケール行列のみで動く。
#'
#' @param gm グレースケール行列 `gm[x, y]`（0-255，x=列/幅，y=行/高）。
#' @param dark 暗画素とみなす閾値（既定 140）。
#' @param frac 各隅で探索する象限の割合（既定 0.22）。
#' @param rowthr 暗ブロックとみなす暗画素数の下限（既定 25）。
#' @return `list(TL=, TR=, BL=, BR=)`。各要素は `list(cx, cy, side)`。
#' @export
detect_fiducials <- function(gm, dark = 140, frac = 0.22, rowthr = 25) {
  W <- nrow(gm); H <- ncol(gm)

  first_block <- function(vals, order, thr) {
    inblock <- FALSE; s <- NA; e <- NA
    for (k in order) {
      if (vals[k] > thr) {
        if (!inblock) { s <- k; inblock <- TRUE }
        e <- k
      } else if (inblock) break
    }
    if (is.na(s)) return(NULL)
    range(c(s, e))
  }

  find_one <- function(corner) {
    qx <- round(W * frac); qy <- round(H * frac)
    xs <- if (grepl("L", corner)) seq_len(qx) else (W - qx + 1):W
    ys <- if (grepl("T", corner)) seq_len(qy) else (H - qy + 1):H
    sub <- gm[xs, ys, drop = FALSE]
    dk <- sub < dark
    yorder <- if (grepl("T", corner)) seq_along(ys) else rev(seq_along(ys))
    xorder <- if (grepl("L", corner)) seq_along(xs) else rev(seq_along(xs))

    yb <- first_block(colSums(dk), yorder, rowthr)
    if (is.null(yb)) return(NULL)
    jrange <- yb[1]:yb[2]
    xb <- first_block(rowSums(dk[, jrange, drop = FALSE]), xorder, rowthr)
    if (is.null(xb)) return(NULL)
    irange <- xb[1]:xb[2]
    list(cx = mean(xs[irange]), cy = mean(ys[jrange]),
         side = mean(c(length(irange), length(jrange))))
  }

  corners <- c("TL", "TR", "BL", "BR")
  out <- lapply(corners, find_one)
  names(out) <- corners
  if (any(vapply(out, is.null, logical(1)))) {
    stop("位置決めマークを4隅すべて検出できませんでした")
  }
  out
}
