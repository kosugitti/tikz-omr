# make_marksheet() が config から生成する読み取り定義が，同梱の例（reader が使う定義）と
# 一致することを保証する。生成器と reader が同じ座標系を共有していることの担保。

test_that("生成 marks が同梱 example と一致（<0.1mm）", {
  g <- make_marksheet(default_config())
  ship <- example_layout()$marks

  expect_equal(nrow(g$marks), nrow(ship))
  gm <- g$marks[order(g$marks$field, g$marks$value), ]
  sh <- ship[order(ship$field, ship$value), ]
  expect_lt(max(abs(gm$x_mm - sh$x_mm)), 0.1)
  expect_lt(max(abs(gm$y_mm - sh$y_mm)), 0.1)
})

test_that("生成 fiducials が同梱 example と一致（<0.1mm）", {
  g <- make_marksheet(default_config())
  sf <- example_layout()$fiducials
  gf <- g$fiducials[match(sf$corner, g$fiducials$corner), ]
  expect_lt(max(abs(gf$x_mm - sf$x_mm)), 0.1)
  expect_lt(max(abs(gf$y_mm - sf$y_mm)), 0.1)
})

test_that("問題数を変えると marks 行数が追従する（年度変化）", {
  cfg <- default_config()
  cfg$answer$n_questions <- 60
  cfg$answer$col_split <- list(c(1, 30), c(31, 60))
  cfg$id$n_digits <- 8
  g <- make_marksheet(cfg)
  n_id <- sum(grepl("^ID", g$marks$field))
  n_m <- sum(grepl("^M", g$marks$field))
  expect_equal(n_id, 8 * length(cfg$id$symbols))
  expect_equal(n_m, 60 * length(cfg$answer$symbols))
})

test_that(".tex が生成され主要要素を含む", {
  g <- make_marksheet(default_config())
  expect_true(grepl("\\\\documentclass", g$tex))
  expect_true(grepl("remember picture", g$tex))
  expect_true(grepl("ellipse", g$tex))
})
