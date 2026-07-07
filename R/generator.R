# config → marksheet.tex ＋ 読み取り定義（marks / fiducials）を生成する。
# すべて絶対 page-mm（用紙左上原点，x 右・y 下）で描くので，描いた楕円の座標が
# そのまま読み取り定義になる（single source of truth）。

#' 既定レイアウト（2026 様式）の config を返す
#'
#' `make_marksheet()` に渡す config。自作様式ではこの list を複製して数値を変える。
#' 主に年度で変わるのは `id$n_digits` と `answer$n_questions` / `answer$col_split`。
#'
#' @return レイアウト config（list）。
#' @export
default_config <- function() {
  list(
    page = list(width = 210, height = 297),
    fiducials = list(inset = 10, big = 12.8, small = 9),
    title = c("心理学データ解析基礎",
              "マークシート"),
    id = list(n_digits = 6, symbols = c(1:9, 0),
              x0 = 30.705, colw = 7.336, y0 = 68.75, rowh = 5.176,
              header_dy = 5,
              label = "【学籍番号】",  # ブロック見出し
              prefix = NULL),          # 固定接頭辞（印字のみ・マーク対象外，例 "HP"）
    answer = list(n_questions = 75, col_split = list(c(1, 38), c(39, 75)),
                  symbols = c(1:9, 0), col_x0 = c(39.956, 124.258),
                  optw = 6.856, y0 = 114.78, rowh = 4.212, header_dy = 5)
  )
}

# config から marks / fiducials の data.frame を計算
.compute_geometry <- function(cfg) {
  p <- cfg$page; f <- cfg$fiducials
  fiducials <- data.frame(
    corner = c("TL", "TR", "BL", "BR"),
    x_mm = c(f$inset + f$big / 2, p$width - f$inset - f$small / 2,
             f$inset + f$small / 2, p$width - f$inset - f$small / 2),
    y_mm = c(f$inset + f$big / 2, f$inset + f$small / 2,
             p$height - f$inset - f$small / 2, p$height - f$inset - f$small / 2),
    stringsAsFactors = FALSE)

  rows <- list()
  id <- cfg$id
  for (d in seq_len(id$n_digits)) {
    for (j in seq_along(id$symbols)) {
      rows[[length(rows) + 1]] <- data.frame(
        field = paste0("ID", d), value = id$symbols[j],
        x_mm = id$x0 + (j - 1) * id$colw, y_mm = id$y0 + (d - 1) * id$rowh)
    }
  }
  an <- cfg$answer
  for (ci in seq_along(an$col_split)) {
    qs <- an$col_split[[ci]]; x0 <- an$col_x0[ci]
    for (i in seq_len(qs[2] - qs[1] + 1)) {
      q <- qs[1] + i - 1
      for (j in seq_along(an$symbols)) {
        rows[[length(rows) + 1]] <- data.frame(
          field = paste0("M", q), value = an$symbols[j],
          x_mm = x0 + (j - 1) * an$optw, y_mm = an$y0 + (i - 1) * an$rowh)
      }
    }
  }
  marks <- do.call(rbind, rows)
  list(marks = marks, fiducials = fiducials)
}

# TikZ 用: 用紙左上原点で (x mm 右, y mm 下) の点
.pt <- function(x, y) {
  sprintf("([xshift=%.3fmm,yshift=-%.3fmm]current page.north west)", x, y)
}

# config → .tex 文字列
.build_tex <- function(cfg, geo) {
  L <- character(0)
  add <- function(...) L[[length(L) + 1]] <<- paste0(...)

  add("% tikzomr: config から自動生成されたマークシート")
  add("\\documentclass[a4paper]{ltjsarticle}")
  add("\\usepackage{tikz}")
  add("\\usepackage[margin=0mm]{geometry}")
  add("\\usepackage{luatexja-fontspec}")
  add("\\pagestyle{empty}")
  add("\\begin{document}")
  add("\\begin{tikzpicture}[remember picture, overlay]")

  # 位置決めマーク（中心が geo$fiducials に一致する塗り四角）
  f <- cfg$fiducials
  fd <- geo$fiducials
  for (k in seq_len(nrow(fd))) {
    s <- if (fd$corner[k] == "TL") f$big else f$small
    add("  \\fill ", .pt(fd$x_mm[k] - s / 2, fd$y_mm[k] - s / 2),
        " rectangle ", .pt(fd$x_mm[k] + s / 2, fd$y_mm[k] + s / 2), ";")
  }

  # タイトル
  cx <- cfg$page$width / 2
  add("  \\node[anchor=north,font=\\Large\\bfseries] at ", .pt(cx, 10), " {", cfg$title[1], "};")
  if (length(cfg$title) > 1)
    add("  \\node[anchor=north,font=\\large] at ", .pt(cx, 18), " {", cfg$title[2], "};")

  # 氏名・学籍番号の手書き欄
  add("  \\node[anchor=west] at ", .pt(12, 30), " {氏名};")
  add("  \\draw ", .pt(24, 32), " -- ", .pt(100, 32), ";")

  # ID ブロック
  id <- cfg$id
  id_label <- if (!is.null(id$label)) id$label else "【学籍番号】"
  head_txt <- if (!is.null(id$prefix) && nzchar(id$prefix))
    paste0(id_label, "（先頭に ", id$prefix, " が付きます・マーク不要）") else id_label
  add("  \\node[anchor=west,font=\\bfseries] at ", .pt(id$x0 - 18, 58),
      " {", head_txt, "};")
  for (j in seq_along(id$symbols)) {
    x <- id$x0 + (j - 1) * id$colw
    add("  \\node[font=\\footnotesize\\bfseries] at ", .pt(x, id$y0 - id$header_dy),
        " {", id$symbols[j], "};")
  }
  for (d in seq_len(id$n_digits)) {
    y <- id$y0 + (d - 1) * id$rowh
    add("  \\node[anchor=east,font=\\scriptsize] at ", .pt(id$x0 - id$colw, y),
        " {", d, "桁目};")
  }
  idm <- geo$marks[grepl("^ID", geo$marks$field), ]
  for (k in seq_len(nrow(idm)))
    add("  \\draw[gray,line width=0.4pt] ", .pt(idm$x_mm[k], idm$y_mm[k]),
        " ellipse (2.2mm and 1.6mm);")
  add("  \\draw ", .pt(id$x0 - id$colw - 6, id$y0 - id$header_dy - 3),
      " rectangle ", .pt(id$x0 + (length(id$symbols)) * id$colw,
                          id$y0 + (id$n_digits - 1) * id$rowh + 3), ";")

  # 解答ブロック
  an <- cfg$answer
  add("  \\node[anchor=west,font=\\bfseries] at ", .pt(an$col_x0[1] - 12, an$y0 - 12),
      " {【解答欄】};")
  for (ci in seq_along(an$col_split)) {
    qs <- an$col_split[[ci]]; x0 <- an$col_x0[ci]
    for (j in seq_along(an$symbols))
      add("  \\node[font=\\small\\bfseries] at ",
          .pt(x0 + (j - 1) * an$optw, an$y0 - an$header_dy),
          " {", an$symbols[j], "};")
    for (i in seq_len(qs[2] - qs[1] + 1)) {
      q <- qs[1] + i - 1; y <- an$y0 + (i - 1) * an$rowh
      add("  \\node[anchor=east,font=\\scriptsize] at ", .pt(x0 - an$optw, y),
          " {M", q, "};")
    }
    ncol <- length(an$symbols); nrow_c <- qs[2] - qs[1] + 1
    add("  \\draw ", .pt(x0 - an$optw - 6, an$y0 - an$header_dy - 3),
        " rectangle ", .pt(x0 + ncol * an$optw, an$y0 + (nrow_c - 1) * an$rowh + 3), ";")
  }
  anm <- geo$marks[grepl("^M", geo$marks$field), ]
  for (k in seq_len(nrow(anm)))
    add("  \\draw[gray,line width=0.4pt] ", .pt(anm$x_mm[k], anm$y_mm[k]),
        " ellipse (2.2mm and 1.6mm);")

  add("\\end{tikzpicture}")
  add("\\end{document}")
  paste(unlist(L), collapse = "\n")
}

#' config からマークシート(.tex)と読み取り定義を生成する
#'
#' 同じ config から，組版用 `.tex` と，読み取り用の `marks`（field,value,x_mm,y_mm）・
#' `fiducials`（corner,x_mm,y_mm）を生成する。両者は座標が一致する。
#'
#' @param config `default_config()` と同形の list。
#' @param tex_path 書き出す `.tex` のパス（NULL なら書き出さない）。
#' @param marks_path 書き出す marks CSV のパス（NULL なら書き出さない）。
#' @param fiducials_path 書き出す fiducials CSV のパス（NULL なら書き出さない）。
#' @return `list(tex=, marks=, fiducials=, id_prefix=)`。marks/fiducials/id_prefix は
#'   そのまま `read_marksheet()` の `layout` に渡せる（接頭辞が自動で引き継がれる）。
#' @export
make_marksheet <- function(config = default_config(), tex_path = NULL,
                           marks_path = NULL, fiducials_path = NULL) {
  geo <- .compute_geometry(config)
  tex <- .build_tex(config, geo)
  if (!is.null(tex_path)) writeLines(tex, tex_path)
  if (!is.null(marks_path)) utils::write.csv(geo$marks, marks_path, row.names = FALSE)
  if (!is.null(fiducials_path)) utils::write.csv(geo$fiducials, fiducials_path, row.names = FALSE)
  id_prefix <- if (!is.null(config$id$prefix)) config$id$prefix else ""
  list(tex = tex, marks = geo$marks, fiducials = geo$fiducials, id_prefix = id_prefix)
}
