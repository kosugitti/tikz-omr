# ローカル Shiny GUI「マークシート工房」の起動関数。
# 実体は inst/app/app.R（配布物に同梱）。答案はこの端末から出ない（クラウド送信なし）。

#' マークシート工房（ローカル Shiny GUI）を起動する
#'
#' マークシートの生成（config → `.tex` / PDF / 読み取り定義）と読み取り
#' （スキャン → responses.csv / review.csv）をブラウザ上の GUI で行う。
#' すべてこの端末上で動き、答案画像は外部に送信されない。
#'
#' 生成タブで PDF を書き出すには `lualatex`（LuaLaTeX）がパスに必要。無い場合は
#' `.tex` と読み取り定義 CSV のみ書き出せる（PDF ボタンは無効表示）。
#'
#' @param ... `shiny::runApp()` に渡す引数（`port`, `launch.browser`, `host` など）。
#' @return 起動した Shiny アプリ（`shiny::runApp()` の戻り値）。副作用としてアプリを起動する。
#' @examples
#' \dontrun{
#' run_omr_app()
#' }
#' @export
run_omr_app <- function(...) {
  need <- c("shiny", "DT")
  miss <- need[!vapply(need, requireNamespace, logical(1), quietly = TRUE)]
  if (length(miss))
    stop("run_omr_app() には ", paste(miss, collapse = " / "),
         " が必要です。install.packages(c(",
         paste(sprintf('"%s"', miss), collapse = ", "), ")) を実行してください。",
         call. = FALSE)

  app_dir <- system.file("app", package = "tikzomr")
  if (!nzchar(app_dir) || !file.exists(file.path(app_dir, "app.R")))
    stop("同梱 Shiny アプリ（inst/app/app.R）が見つかりません。", call. = FALSE)

  shiny::runApp(app_dir, ...)
}
