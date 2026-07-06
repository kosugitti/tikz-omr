#' 4点対応から射影変換（ホモグラフィ）行列を解く
#'
#' DLT を線形（8 未知数）に解く。スキャンごとの傾き・拡縮・平行移動を吸収するため，
#' page 座標（mm）→ スキャン画素の対応を四隅で立てて使う。
#'
#' @param src 4x2 行列（変換元の座標）。
#' @param dst 4x2 行列（変換先の座標）。
#' @return 3x3 のホモグラフィ行列。
#' @export
homography <- function(src, dst) {
  stopifnot(nrow(src) == 4, nrow(dst) == 4)
  A <- matrix(0, 8, 8); b <- numeric(8)
  for (i in 1:4) {
    X <- src[i, 1]; Y <- src[i, 2]; u <- dst[i, 1]; v <- dst[i, 2]
    A[2 * i - 1, ] <- c(X, Y, 1, 0, 0, 0, -u * X, -u * Y); b[2 * i - 1] <- u
    A[2 * i,     ] <- c(0, 0, 0, X, Y, 1, -v * X, -v * Y); b[2 * i]     <- v
  }
  matrix(c(solve(A, b), 1), 3, 3, byrow = TRUE)
}

#' ホモグラフィ行列で1点を写す
#' @param H 3x3 行列。
#' @param p 長さ2の座標。
#' @return 写像後の長さ2座標。
#' @keywords internal
apply_h <- function(H, p) {
  w <- H %*% c(p[1], p[2], 1)
  c(w[1] / w[3], w[2] / w[3])
}
