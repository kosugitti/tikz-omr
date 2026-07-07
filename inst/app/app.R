# マークシート工房 — tikzomr のローカル Shiny GUI（run_omr_app() から起動）
# 生成タブ: config → .tex / PDF / 読み取り定義。読取タブ: スキャン → responses.csv / review.csv。
# 答案はこの端末から出ない（クラウド送信なし）。

library(shiny)

# ---- 意匠（モックアップ準拠・ライト/ダーク対応） -----------------------------
.omr_css <- "
:root{
  --paper:#F1F4F5; --panel:#FFFFFF; --panel2:#F7F9FA; --ink:#171B1E; --ink2:#454D53; --ink3:#79838B;
  --line:#DBE1E4; --line2:#EAEEF0; --accent:#0C7A83; --accent2:#0C7A8314; --accentink:#FFFFFF;
  --ok:#2C7A55; --okbg:#2C7A5518; --warn:#A8630A; --warnbg:#A8630A18; --bad:#B8402F; --badbg:#B8402F16;
  --overlay:#D24B3E;
  --mono:'SFMono-Regular','SF Mono','Menlo','Consolas',monospace;
  --sans:'Hiragino Sans','Hiragino Kaku Gothic ProN','Helvetica Neue','Noto Sans JP',system-ui,sans-serif;
}
@media (prefers-color-scheme: dark){:root{
  --paper:#101315; --panel:#191D20; --panel2:#14181A; --ink:#E7ECEE; --ink2:#AEB7BD; --ink3:#79848B;
  --line:#2A3236; --line2:#222A2E; --accent:#34AEB8; --accent2:#34AEB820; --accentink:#08171A;
  --ok:#55C58C; --okbg:#55C58C1e; --warn:#E0993A; --warnbg:#E0993A1e; --bad:#E1705E; --badbg:#E1705E1c;
  --overlay:#E1705E;
}}
body{background:var(--paper); color:var(--ink); font-family:var(--sans); -webkit-font-smoothing:antialiased;}
.container-fluid{max-width:1140px; padding:22px 18px 60px;}
.app{background:var(--panel); border:1px solid var(--line); border-radius:14px; overflow:hidden;
  box-shadow:0 1px 2px rgba(20,30,35,.05),0 8px 30px rgba(20,30,35,.07);}
.appbar{display:flex; align-items:center; gap:14px; padding:13px 20px; border-bottom:1px solid var(--line); background:var(--panel2);}
.fid{display:grid; grid-template-columns:11px 7px; grid-template-rows:11px 7px; gap:3px; flex:none;}
.fid i{background:var(--ink); border-radius:1.5px; display:block;}
.fid i:nth-child(1){width:11px;height:11px;} .fid i:nth-child(2){width:7px;height:7px;align-self:center;}
.fid i:nth-child(3){width:7px;height:7px;justify-self:center;} .fid i:nth-child(4){width:7px;height:7px;align-self:center;justify-self:center;}
.brand h1{font-size:16px; margin:0; font-weight:650; letter-spacing:.2px;}
.brand .fn{font-family:var(--mono); font-size:12px; color:var(--ink3);}
.appbar .spacer{flex:1;}
.badge-priv{display:inline-flex; align-items:center; gap:7px; font-size:12.5px; color:var(--accent); font-weight:600;
  background:var(--accent2); border:1px solid color-mix(in srgb,var(--accent) 30%,transparent); padding:5px 11px; border-radius:999px;}
.badge-priv svg{width:13px;height:13px;}
/* tabs (bootstrap nav override) */
.app .nav-tabs{border-bottom:1px solid var(--line); background:var(--panel2); padding:0 12px; gap:2px;}
.app .nav-tabs>li>a, .app .nav-tabs .nav-link{border:none !important; color:var(--ink3) !important; font-size:14px; font-weight:550;
  padding:12px 15px !important; border-bottom:2px solid transparent !important; background:none !important;}
.app .nav-tabs>li.active>a, .app .nav-tabs .nav-link.active{color:var(--ink) !important; border-bottom-color:var(--accent) !important; background:none !important;}
.panel-pad{padding:22px;}
.grid2{display:grid; grid-template-columns:minmax(0,1fr) minmax(0,1.15fr); gap:22px;}
@media (max-width:820px){.grid2{grid-template-columns:1fr;}}
.card2{background:var(--panel); border:1px solid var(--line); border-radius:9px;}
.card2.soft{background:var(--panel2);}
.card2 .h{font-size:11.5px; letter-spacing:.09em; text-transform:uppercase; color:var(--ink3); font-weight:650;
  padding:12px 15px; border-bottom:1px solid var(--line2);}
.card2 .b{padding:15px;}
label.control-label{font-size:13px; font-weight:600; color:var(--ink2); margin-bottom:5px;}
.form-control, .selectize-input, select.form-control{background:var(--panel) !important; color:var(--ink) !important;
  border:1px solid var(--line) !important; border-radius:7px !important; font-size:14px; box-shadow:none !important;}
.hint{font-size:11.5px; color:var(--ink3); line-height:1.45; margin-top:5px;}
.hint b{color:var(--ink2);}
.btn-omr{cursor:pointer; font-family:var(--sans); font-size:13.5px; font-weight:600; border-radius:8px; padding:9px 15px;
  border:1px solid var(--line); background:var(--panel); color:var(--ink); display:inline-flex; align-items:center; gap:8px;
  text-decoration:none; white-space:nowrap; line-height:1.2;}
.btn-omr svg{width:15px; height:15px; flex:none;}
.btn-omr:hover{border-color:var(--ink3); color:var(--ink);}
.btn-omr.primary, .btn-primary.btn-omr{background:var(--accent) !important; color:var(--accentink) !important; border-color:var(--accent) !important;}
.btnrow{display:flex; gap:10px; flex-wrap:wrap;}
.tiles{display:grid; grid-template-columns:repeat(4,1fr); gap:10px; margin-bottom:16px;}
@media (max-width:560px){.tiles{grid-template-columns:repeat(2,1fr);}}
.tile{border:1px solid var(--line); border-radius:9px; padding:11px 13px; background:var(--panel); position:relative; overflow:hidden;}
.tile::before{content:''; position:absolute; left:0; top:0; bottom:0; width:3px; background:var(--ink3);}
.tile.ok::before{background:var(--ok);} .tile.warn::before{background:var(--warn);} .tile.bad::before{background:var(--bad);} .tile.tot::before{background:var(--accent);}
.tile .n{font-family:var(--mono); font-size:25px; font-weight:600; line-height:1; font-variant-numeric:tabular-nums;}
.tile.ok .n{color:var(--ok);} .tile.warn .n{color:var(--warn);} .tile.bad .n{color:var(--bad);}
.tile .l{font-size:11.5px; color:var(--ink3); margin-top:6px; font-weight:600;}
.note{display:flex; gap:9px; align-items:flex-start; font-size:12px; color:var(--ink2); background:var(--warnbg);
  border:1px solid color-mix(in srgb,var(--warn) 28%,transparent); border-radius:8px; padding:10px 12px; margin-top:14px; line-height:1.5;}
.note svg{width:15px;height:15px;flex:none;color:var(--warn);margin-top:1px;}
.note code{font-family:var(--mono); font-size:11.5px;}
.caption{font-size:12px; color:var(--ink3); margin-top:10px; line-height:1.5;}
.caption b{color:var(--ink2);}
.pill{display:inline-flex; align-items:center; gap:5px; font-size:11.5px; font-weight:600; padding:2px 8px; border-radius:999px;}
.pill::before{content:''; width:6px; height:6px; border-radius:50%;}
.pill.ok{color:var(--ok); background:var(--okbg);} .pill.ok::before{background:var(--ok);}
.pill.warn{color:var(--warn); background:var(--warnbg);} .pill.warn::before{background:var(--warn);}
.pill.bad{color:var(--bad); background:var(--badbg);} .pill.bad::before{background:var(--bad);}
table.dataframe, .dataTables_wrapper{font-size:12.5px;}
.slider-animate-container{display:none;}
"

# ---- SVG アイコン ------------------------------------------------------------
.ic <- function(paths) HTML(sprintf(
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">%s</svg>',
  paths))
.ic_dl   <- .ic('<path d="M12 3v12m0 0l4-4m-4 4l-4-4"></path><path d="M5 21h14"></path>')
.ic_run  <- .ic('<path d="M5 12l5 5L20 7"></path>')
.ic_lock <- .ic('<rect x="4" y="10" width="16" height="10" rx="2"></rect><path d="M8 10V7a4 4 0 0 1 8 0v3"></path>')
.ic_info <- .ic('<path d="M12 9v4"></path><path d="M12 17h.01"></path><circle cx="12" cy="12" r="9"></circle>')

# ---- UI ----------------------------------------------------------------------
ui <- fluidPage(
  tags$head(tags$style(HTML(.omr_css)), tags$title("マークシート工房")),
  div(class = "app",
    div(class = "appbar",
      span(class = "fid", tags$i(), tags$i(), tags$i(), tags$i()),
      div(class = "brand", tags$h1("マークシート工房"),
          span(class = "fn", "tikzomr · run_omr_app()")),
      div(class = "spacer"),
      span(class = "badge-priv", .ic_lock, "答案はこの端末から出ません")
    ),
    tabsetPanel(id = "tab", type = "tabs",

      # ===== TAB 1: 生成 =====
      tabPanel("① マークシートを作る",
        div(class = "panel-pad",
          div(class = "grid2",
            div(class = "card2",
              div(class = "h", "レイアウト設定 — config"),
              div(class = "b",
                textInput("ti1", "タイトル（1行目）", "心理学データ解析基礎"),
                textInput("ti2", "タイトル（2行目）", "マークシート"),
                fluidRow(
                  column(6, numericInput("nq", "問題数", 75, min = 1, max = 200)),
                  column(6, numericInput("nd", "ID 桁数", 6, min = 1, max = 12))
                ),
                textInput("cs", "段組み（col_split）", "1-38 / 39-75"),
                div(class = "hint", "解答欄を左右2段に分ける区切り。空欄なら問題数から自動で二分割。"),
                br(),
                textInput("pre", "固定接頭辞（prefix）", "HP"),
                div(class = "hint", HTML("学部コードなど全員共通の先頭文字。<b>印字のみ・マーク対象外</b>。読取時にフル学籍番号へ自動連結。空欄なら従来どおり。"))
              )
            ),
            div(class = "card2 soft",
              div(class = "h", "プレビュー — レイアウト幾何"),
              div(class = "b",
                plotOutput("preview", height = "420px"),
                div(class = "btnrow", style = "margin-top:14px",
                  downloadLink("dl_tex",   class = "btn-omr primary", list(.ic_dl, "marksheet.tex")),
                  downloadLink("dl_marks", class = "btn-omr",         list(.ic_dl, "読み取り定義 CSV")),
                  uiOutput("dl_pdf_ui", inline = TRUE)
                ),
                div(class = "note", .ic_info,
                  HTML("生成された <code>.tex</code> は四隅マークの位置決めに <code>remember picture</code> を使うため、<b>LuaLaTeX で 2 回</b>組版してください。"))
              )
            )
          )
        )
      ),

      # ===== TAB 2: 読取 =====
      tabPanel("② 読み取り",
        div(class = "panel-pad",
          div(class = "grid2",
            div(class = "card2",
              div(class = "h", "スキャンと読み取り設定"),
              div(class = "b",
                fileInput("scan", "スキャン画像 / PDF",
                          accept = c(".pdf", ".png", ".jpg", ".jpeg", ".tif", ".tiff"),
                          multiple = TRUE, buttonLabel = "選択...", placeholder = "200dpi・ADF・A4"),
                selectInput("laysrc", "レイアウト定義（layout）",
                            c("今作った config（①の設定）" = "gen",
                              "同梱サンプル example_layout()" = "example")),
                div(class = "hint", "生成に使った config をそのまま渡せば、接頭辞も座標も一致します。"),
                br(),
                sliderInput("thr", "塗り率しきい値（fill_thr）", min = 0, max = 0.6, value = 0.20, step = 0.01),
                fluidRow(
                  column(6, numericInput("dpi", "描画 dpi", 200, min = 100, max = 400)),
                  column(6, numericInput("dark", "暗画素しきい値", 140, min = 0, max = 255))
                ),
                div(class = "btnrow", style = "margin-top:4px",
                  actionButton("run", list(.ic_run, "読み取り実行"), class = "btn-omr primary"))
              )
            ),
            div(
              uiOutput("tiles"),
              div(class = "card2", style = "margin-bottom:16px",
                div(class = "h", "responses.csv"),
                div(style = "padding:0 4px", DT::dataTableOutput("resp"))
              ),
              div(class = "grid2", style = "gap:16px",
                div(class = "card2",
                  div(class = "h", "要目視 — review.csv"),
                  div(style = "padding:0 4px", DT::dataTableOutput("rev"))
                ),
                div(class = "card2 soft",
                  div(class = "h", "塗り率の分布 — 全セル"),
                  div(class = "b",
                    plotOutput("hist", height = "150px"),
                    div(class = "caption", HTML("空欄（左の山）と実マーク（右の山）が<b>二峰に分離</b>。谷にしきい値を置くと取りこぼし・誤検出が起きにくい状態です。"))
                  )
                )
              ),
              div(class = "btnrow", style = "margin-top:16px",
                downloadLink("dl_resp", class = "btn-omr primary", list(.ic_dl, "responses.csv")),
                downloadLink("dl_rev",  class = "btn-omr",         list(.ic_dl, "review.csv")))
            )
          )
        )
      )
    )
  )
)

# ---- サーバ ------------------------------------------------------------------
server <- function(input, output, session) {

  has_lua <- nzchar(Sys.which("lualatex"))

  # 段組み文字列 "1-38 / 39-75" → list(c(1,38), c(39,75))。失敗時は問題数から二分割
  parse_split <- function(txt, nq) {
    seg <- trimws(strsplit(txt, "/")[[1]])
    pr <- lapply(seg, function(s) suppressWarnings(as.integer(trimws(strsplit(s, "[-–～]")[[1]]))))
    ok <- length(pr) >= 1 && all(vapply(pr, function(p) length(p) == 2 && !anyNA(p), logical(1)))
    if (ok) return(pr)
    half <- ceiling(nq / 2)
    list(c(1, half), c(half + 1, nq))
  }

  # 入力 → config
  cfg <- reactive({
    c0 <- tikzomr::default_config()
    c0$title <- c(input$ti1, input$ti2)
    nq <- max(1, as.integer(input$nq))
    c0$answer$n_questions <- nq
    c0$answer$col_split <- parse_split(input$cs, nq)
    c0$id$n_digits <- max(1, as.integer(input$nd))
    pre <- trimws(input$pre %||% "")
    c0$id$prefix <- if (nzchar(pre)) pre else NULL
    c0
  })
  `%||%` <- function(a, b) if (is.null(a)) b else a

  gen <- reactive(tikzomr::make_marksheet(cfg()))

  # プレビュー: marks を楕円、fiducials を黒四角で描く（用紙 210x297・y 下向き）
  output$preview <- renderPlot({
    g <- gen(); m <- g$marks; f <- g$fiducials
    op <- par(mar = c(0, 0, 0, 0), bg = NA); on.exit(par(op))
    plot(NA, xlim = c(0, 210), ylim = c(297, 0), asp = 1, axes = FALSE, xlab = "", ylab = "")
    rect(2, 2, 208, 295, border = "#B9C2C7", lwd = 1)
    fg <- "#3A4247"
    for (k in seq_len(nrow(f))) {
      s <- if (f$corner[k] == "TL") 12.8 else 9
      rect(f$x_mm[k] - s/2, f$y_mm[k] - s/2, f$x_mm[k] + s/2, f$y_mm[k] + s/2, col = "#111", border = NA)
    }
    th <- seq(0, 2*pi, length.out = 22)
    for (k in seq_len(nrow(m)))
      lines(m$x_mm[k] + 2.1*cos(th), m$y_mm[k] + 1.5*sin(th), col = "#7A858C", lwd = .8)
    text(105, 10, input$ti1, cex = 1.15, font = 2, col = fg)
    text(105, 20, input$ti2, cex = .8, col = fg)
    idlab <- if (!is.null(cfg()$id$prefix)) sprintf("【学籍番号】（先頭に %s）", cfg()$id$prefix) else "【学籍番号】"
    text(12, 60, idlab, cex = .72, font = 2, col = fg, adj = 0)
  }, res = 96)

  # ダウンロード（生成）
  output$dl_tex <- downloadHandler(
    filename = function() "marksheet.tex",
    content = function(file) writeLines(gen()$tex, file))
  output$dl_marks <- downloadHandler(
    filename = function() "marksheet.marks.csv",
    content = function(file) utils::write.csv(gen()$marks, file, row.names = FALSE))
  output$dl_pdf_ui <- renderUI({
    if (has_lua) downloadLink("dl_pdf", class = "btn-omr", list(.ic_dl, "PDF"))
    else span(class = "hint", style = "align-self:center", "PDF は LuaLaTeX 未検出のため無効")
  })
  output$dl_pdf <- downloadHandler(
    filename = function() "marksheet.pdf",
    content = function(file) {
      td <- tempfile("omr"); dir.create(td)
      tex <- file.path(td, "marksheet.tex"); writeLines(gen()$tex, tex)
      for (i in 1:2)
        system2("lualatex", c("-interaction=nonstopmode", "-halt-on-error",
                              "-output-directory", shQuote(td), shQuote(tex)),
                stdout = FALSE, stderr = FALSE)
      file.copy(file.path(td, "marksheet.pdf"), file, overwrite = TRUE)
    })

  # ---- 読み取り ----
  result <- reactiveVal(NULL)

  observeEvent(input$run, {
    req(input$scan)
    layout <- if (input$laysrc == "gen") gen() else tikzomr::example_layout()
    withProgress(message = "読み取り中...", value = 0, {
      files <- input$scan
      pieces <- list(); fills <- numeric(0); revs <- list()
      npdf <- sum(grepl("\\.pdf$", files$name, ignore.case = TRUE))
      for (r in seq_len(nrow(files))) {
        nm <- files$name[r]; dp <- files$datapath[r]
        incProgress(1 / nrow(files), detail = nm)
        if (grepl("\\.pdf$", nm, ignore.case = TRUE)) {
          res <- tikzomr::read_marksheet_batch(dp, layout, dpi = input$dpi,
                                               dark = input$dark, fill_thr = input$thr)
          # source をファイル名に戻す
          res$source <- sub("^[^ ]+", nm, res$source)
          pieces[[length(pieces) + 1]] <- res
          fills <- c(fills, attr(res, "fills"))
          rv <- attr(res, "review"); if (!is.null(rv)) { rv$source <- sub("^[^ ]+", nm, rv$source); revs[[length(revs)+1]] <- rv }
        } else {
          one <- tryCatch(tikzomr::read_marksheet(dp, layout, dpi = input$dpi,
                                                  dark = input$dark, fill_thr = input$thr),
                          error = function(e) NULL)
          if (is.null(one)) {
            revs[[length(revs)+1]] <- data.frame(source = nm, problem = "読取失敗", blanks = NA_integer_)
            pieces[[length(pieces)+1]] <- data.frame(source = nm)
          } else {
            fills <- c(fills, attr(one, "fills"))
            rv <- attr(one, "review"); probs <- character(0)
            if (isTRUE(rv$id_incomplete)) probs <- c(probs, "ID不明桁あり")
            if (length(rv$multi)) probs <- c(probs, paste0("複数塗り:", paste(rv$multi, collapse = ",")))
            if (length(probs)) revs[[length(revs)+1]] <- data.frame(source = nm, problem = paste(probs, collapse = " / "), blanks = rv$blanks)
            pieces[[length(pieces)+1]] <- cbind(source = nm, one)
          }
        }
      }
      # 列を揃えて結合
      allc <- unique(unlist(lapply(pieces, names)))
      pieces <- lapply(pieces, function(d) { for (m in setdiff(allc, names(d))) d[[m]] <- NA; d[allc] })
      resp <- do.call(rbind, pieces)
      review <- if (length(revs)) do.call(rbind, revs) else NULL
      result(list(resp = resp, review = review, fills = fills))
    })
  })

  # サマリータイル
  output$tiles <- renderUI({
    r <- result()
    tile <- function(cls, n, l) div(class = paste("tile", cls), div(class = "n", n), div(class = "l", l))
    if (is.null(r)) {
      div(class = "tiles",
        tile("tot", "–", "読み取り枚数"), tile("ok", "–", "正常"),
        tile("warn", "–", "要目視"), tile("bad", "–", "読取失敗"))
    } else {
      total <- nrow(r$resp)
      bad <- if (is.null(r$review)) 0 else sum(grepl("失敗", r$review$problem))
      warn <- if (is.null(r$review)) 0 else nrow(r$review) - bad
      div(class = "tiles",
        tile("tot", total, "読み取り枚数"), tile("ok", total - warn - bad, "正常"),
        tile("warn", warn, "要目視"), tile("bad", bad, "読取失敗"))
    }
  })

  dt_opts <- list(dom = "tp", pageLength = 6, scrollX = TRUE, ordering = FALSE,
                  language = list(emptyTable = "読み取りを実行してください"))

  output$resp <- DT::renderDataTable({
    r <- result(); DT::datatable(if (is.null(r)) data.frame() else r$resp,
      rownames = FALSE, options = dt_opts, class = "compact stripe")
  })
  output$rev <- DT::renderDataTable({
    r <- result()
    d <- if (is.null(r) || is.null(r$review)) data.frame(source = character(), problem = character(), blanks = integer()) else r$review
    DT::datatable(d, rownames = FALSE, options = list(dom = "tp", pageLength = 6, ordering = FALSE,
      language = list(emptyTable = "要目視なし")), class = "compact stripe")
  })

  # 塗り率ヒストグラム
  output$hist <- renderPlot({
    r <- result(); req(r); f <- r$fills; req(length(f) > 0)
    op <- par(mar = c(2.2, 0, 0, 0), bg = NA); on.exit(par(op))
    h <- hist(f, breaks = seq(0, 1, by = 0.05), plot = FALSE)
    cols <- ifelse(h$mids < input$thr, "#7A858C", "#0C7A83")
    barplot(h$counts, col = cols, border = NA, space = 0, axes = FALSE)
    axis(1, at = c(0, 20) , labels = c("0.0", "1.0"), col = "#B9C2C7", col.axis = "#79838B", cex.axis = .8, tick = FALSE)
    abline(v = input$thr * 20, col = "#D24B3E", lty = 2, lwd = 1.4)
  }, res = 96)

  # ダウンロード（読取）
  output$dl_resp <- downloadHandler(
    filename = function() "responses.csv",
    content = function(file) { r <- result(); req(r); utils::write.csv(r$resp, file, row.names = FALSE, na = "") })
  output$dl_rev <- downloadHandler(
    filename = function() "review.csv",
    content = function(file) { r <- result(); utils::write.csv(if (is.null(r$review)) data.frame() else r$review, file, row.names = FALSE, na = "") })
}

shinyApp(ui, server)
