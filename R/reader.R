# tikzomr の読み取り本体。
# 流れ: 画像/PDF → グレー行列 → 四隅検出（天地補正）→ page-mm→スキャン画素の
#       ホモグラフィ → 各マークの塗り率 → フィールドごとにデコード。

# ---- 内部ヘルパ --------------------------------------------------------------

# magick 画像 → グレー行列 gm[x, y]（0-255）
.to_gray_matrix <- function(img) {
  g <- magick::image_convert(img, colorspace = "gray")
  info <- magick::image_info(g)
  raw <- magick::image_data(g, "gray")            # dim = c(1, W, H)
  matrix(as.integer(raw[1, , ]), nrow = info$width, ncol = info$height)
}

# 入力（magick 画像 / 画像パス / PDF パス）→ グレー行列
.load_gray <- function(input, page = 1L, dpi = 200) {
  if (inherits(input, "magick-image")) {
    return(.to_gray_matrix(input))
  }
  if (is.character(input) && length(input) == 1L) {
    if (grepl("\\.pdf$", input, ignore.case = TRUE)) {
      bmp <- pdftools::pdf_render_page(input, page = page, dpi = dpi)
      return(.to_gray_matrix(magick::image_read(bmp)))
    }
    return(.to_gray_matrix(magick::image_read(input)))
  }
  stop("input は magick 画像・画像パス・PDF パスのいずれかにしてください")
}

# 窓内の暗画素率
.fill_ratio <- function(gm, px, py, rx, ry, dark) {
  W <- nrow(gm); H <- ncol(gm)
  x0 <- max(1, round(px - rx)); x1 <- min(W, round(px + rx))
  y0 <- max(1, round(py - ry)); y1 <- min(H, round(py + ry))
  if (x1 < x0 || y1 < y0) return(0)
  mean(gm[x0:x1, y0:y1] < dark)
}

# フィールド名（ID1.., M1..）を種別と番号で並べる
.order_fields <- function(fields) {
  u <- unique(fields)
  kind <- sub("[0-9]+$", "", u)
  num <- as.integer(sub("^[A-Za-z]+", "", u))
  u[order(match(kind, c("ID", "M")), num)]
}

# ---- 公開 API ----------------------------------------------------------------

#' 同梱サンプル（2026 様式）のレイアウト定義を返す
#'
#' `read_marksheet()` に渡す `layout`（marks と fiducials）を，パッケージ同梱の
#' CSV から読み込む。自作様式ではこれと同じ列を持つ data.frame を用意する。
#'
#' @return `list(marks=, fiducials=)`。marks は `field,value,x_mm,y_mm`，
#'   fiducials は `corner,x_mm,y_mm`。
#' @export
example_layout <- function() {
  ex <- function(f) system.file("examples", f, package = "tikzomr")
  list(
    marks     = utils::read.csv(ex("marksheet_example.marks.csv")),
    fiducials = utils::read.csv(ex("marksheet_example.fiducials.csv"))
  )
}

#' マークシート1枚を読み取る
#'
#' @param input magick 画像・画像パス・PDF パスのいずれか。
#' @param layout `example_layout()` と同形の `list(marks, fiducials)`。
#' @param page PDF の場合のページ番号。
#' @param dpi PDF 描画解像度。
#' @param dark 暗画素閾値（既定 140）。
#' @param fill_thr 塗りとみなす塗り率の下限（既定 0.13）。鉛筆マークは薄いので既定を
#'   低めに取る。実データ（86 枚）では 0.10–0.13 で誤検出ゼロのまま一致 99% 超，
#'   0.08 を割ると二峰の谷を越えて誤検出が出始める。清刷り前提なら 0.20 でもよい。
#' @param win_mm サンプリング窓の半径（mm）。`c(横, 縦)`。
#' @param id_prefix 学籍番号の固定接頭辞（印字のみ・マーク対象外，例 `"HP"`）。
#'   `NULL`（既定）なら `layout$id_prefix` を使う。空文字なら接頭辞なし。非空なら
#'   先頭にフル学籍番号 `id`（接頭辞＋マーク桁の連結）列を追加する。既定では
#'   出力・挙動は従来と一切変わらない。
#' @return 1 行の data.frame（列 = ID1.., M1..，接頭辞指定時は先頭に `id`）。
#'   属性 `"review"` に要目視情報（複数塗り・空欄数）を格納。
#' @export
read_marksheet <- function(input, layout, page = 1L, dpi = 200,
                           dark = 140, fill_thr = 0.13, win_mm = c(1.1, 0.8),
                           id_prefix = NULL) {
  gm <- .load_gray(input, page = page, dpi = dpi)

  # 天地補正: 左上マークが最大でなければ 180 度回転
  fid <- detect_fiducials(gm, dark = dark)
  if (which.max(vapply(fid, function(f) f$side, numeric(1))) != 1L) {
    gm <- gm[nrow(gm):1, ncol(gm):1]
    fid <- detect_fiducials(gm, dark = dark)
  }

  corners <- c("TL", "TR", "BL", "BR")
  fdf <- layout$fiducials
  src <- as.matrix(fdf[match(corners, fdf$corner), c("x_mm", "y_mm")])
  dst <- t(vapply(corners, function(k) c(fid[[k]]$cx, fid[[k]]$cy), numeric(2)))
  H <- homography(src, dst)

  # mm あたり画素（TL-TR の実距離から）
  d_px <- sqrt(sum((dst[1, ] - dst[2, ])^2))
  d_mm <- sqrt(sum((src[1, ] - src[2, ])^2))
  pxmm <- d_px / d_mm
  rx <- win_mm[1] * pxmm; ry <- win_mm[2] * pxmm

  marks <- layout$marks
  pts <- t(apply(as.matrix(marks[, c("x_mm", "y_mm")]), 1, function(p) apply_h(H, p)))
  fills <- vapply(seq_len(nrow(marks)),
                  function(i) .fill_ratio(gm, pts[i, 1], pts[i, 2], rx, ry, dark),
                  numeric(1))

  fields <- .order_fields(marks$field)
  vals <- setNames(rep(NA_character_, length(fields)), fields)
  multi <- character(0)
  for (fld in fields) {
    idx <- which(marks$field == fld)
    fr <- fills[idx]
    j <- which.max(fr)
    if (fr[j] >= fill_thr) vals[fld] <- as.character(marks$value[idx][j])
    if (sum(fr >= fill_thr) > 1L) multi <- c(multi, fld)
  }

  out <- as.data.frame(as.list(vals), stringsAsFactors = FALSE, check.names = FALSE)

  # 固定接頭辞: 引数優先，なければ layout 由来。非空ならフル学籍番号 id 列を先頭に足す
  if (is.null(id_prefix)) id_prefix <- layout$id_prefix
  if (!is.null(id_prefix) && nzchar(id_prefix)) {
    id_cols <- names(vals)[grepl("^ID", names(vals))]
    digits <- vals[id_cols]; digits[is.na(digits)] <- ""
    full_id <- paste0(id_prefix, paste0(digits, collapse = ""))
    out <- cbind(id = full_id, out, stringsAsFactors = FALSE)
  }

  n_blank <- sum(is.na(vals[grepl("^M", names(vals))]))
  attr(out, "review") <- list(
    multi = multi,
    id_incomplete = any(is.na(vals[grepl("^ID", names(vals))])),
    blanks = n_blank
  )
  attr(out, "fills") <- fills   # 全マークの塗り率（二峰分布の可視化・診断用）
  out
}

# 対応する画像拡張子（PDF は別扱い）
.img_ext <- "\\.(jpe?g|png|tiff?|bmp|gif)$"

# 入力（PDF パス / フォルダ / ファイルパスの vector）を読み取り単位に展開する。
# 各単位 = list(path=, page=, source=)。PDF は 1 ページ 1 単位（source="base [i/N]"），
# 画像は 1 ファイル 1 単位（source=basename）。
.expand_sources <- function(input) {
  # 単一パスがフォルダなら中身を列挙
  if (length(input) == 1L && dir.exists(input)) {
    fs <- list.files(input, pattern = paste0("(", .img_ext, "|\\.pdf$)"),
                     ignore.case = TRUE, full.names = TRUE)
    input <- sort(fs)
  }
  if (length(input) == 0L) stop("読み取り対象のファイルが見つかりません。", call. = FALSE)
  jobs <- list()
  for (p in input) {
    if (grepl("\\.pdf$", p, ignore.case = TRUE)) {
      np <- pdftools::pdf_info(p)$pages
      bn <- basename(p)
      for (i in seq_len(np))
        jobs[[length(jobs) + 1]] <- list(path = p, page = i,
          source = sprintf("%s [%d/%d]", bn, i, np))
    } else {
      jobs[[length(jobs) + 1]] <- list(path = p, page = 1L, source = basename(p))
    }
  }
  jobs
}

#' PDF・フォルダ・ファイル群を一括読み取りして応答表を返す
#'
#' 入力は次のいずれでもよい。
#' \itemize{
#'   \item まとめ PDF 1 枚（1 ページ 1 枚）。`source` は `"file.pdf [i/N]"`。
#'   \item フォルダのパス。中の画像（jpg/png/tiff…）と PDF をすべて読む。
#'   \item ファイルパスの文字列ベクトル（画像・PDF 混在可）。
#' }
#'
#' @param input PDF パス，フォルダのパス，またはファイルパスの vector。
#' @param layout `example_layout()` と同形。
#' @param dpi PDF 描画解像度。
#' @param ... `read_marksheet()` に渡す引数（`fill_thr`, `dark`, `id_prefix` 等）。
#' @return data.frame（`source, ID1.., M1..`）。属性 `"review"` に要目視の data.frame，
#'   `"fills"` に全マークの塗り率，`"sources"` に読み取り単位の一覧
#'   （`source, path, page`。プレビュー時に番号→ファイルの対応に使う）。
#' @export
read_marksheet_batch <- function(input, layout, dpi = 200, ...) {
  jobs <- .expand_sources(input)
  n <- length(jobs)
  rows <- vector("list", n)
  reviews <- list(); fills_all <- numeric(0)
  for (i in seq_len(n)) {
    j <- jobs[[i]]
    r <- tryCatch(read_marksheet(j$path, layout, page = j$page, dpi = dpi, ...),
                  error = function(e) NULL)
    if (is.null(r)) {
      reviews[[length(reviews) + 1]] <- data.frame(
        source = j$source, problem = "読取失敗", blanks = NA_integer_,
        stringsAsFactors = FALSE)
      rows[[i]] <- data.frame(source = j$source, stringsAsFactors = FALSE)
      next
    }
    rv <- attr(r, "review")
    fills_all <- c(fills_all, attr(r, "fills"))
    rows[[i]] <- cbind(source = j$source, r, stringsAsFactors = FALSE)
    probs <- character(0)
    if (isTRUE(rv$id_incomplete)) probs <- c(probs, "ID不明桁あり")
    if (length(rv$multi)) probs <- c(probs, paste0("複数塗り:", paste(rv$multi, collapse = ",")))
    if (length(probs)) {
      reviews[[length(reviews) + 1]] <- data.frame(
        source = j$source, problem = paste(probs, collapse = " / "),
        blanks = rv$blanks, stringsAsFactors = FALSE)
    }
  }
  all_cols <- unique(unlist(lapply(rows, names)))
  rows <- lapply(rows, function(d) {
    for (m in setdiff(all_cols, names(d))) d[[m]] <- NA
    d[all_cols]
  })
  out <- do.call(rbind, rows)
  attr(out, "review") <- if (length(reviews)) do.call(rbind, reviews) else NULL
  attr(out, "fills") <- fills_all
  attr(out, "sources") <- data.frame(
    source = vapply(jobs, `[[`, character(1), "source"),
    path   = vapply(jobs, `[[`, character(1), "path"),
    page   = vapply(jobs, `[[`, numeric(1),  "page"),
    stringsAsFactors = FALSE)
  out
}
