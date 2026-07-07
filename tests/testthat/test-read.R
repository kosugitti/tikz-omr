# 2026 サンプルスキャンで Python 参照実装（オラクル）と同一結果になることを保証する回帰テスト。

test_that("四隅検出が Python と ~1px で一致する", {
  gm <- tikzomr:::.load_gray(system.file("examples", "sample_scan.jpg", package = "tikzomr"))
  fid <- detect_fiducials(gm)
  # Python: TL(157.5,178.5) TR(1504.5,166.0) BL(138.5,2178.0) BR(1502.5,2179.5)
  expect_equal(fid$TL$cx, 157.5, tolerance = 2)
  expect_equal(fid$TL$cy, 178.5, tolerance = 2)
  expect_equal(fid$BR$cx, 1502.5, tolerance = 2)
  expect_equal(fid$BR$cy, 2179.5, tolerance = 2)
  # 左上マークが最大（天地判定用）
  expect_equal(unname(which.max(vapply(fid, function(f) f$side, numeric(1)))), 1L)
})

test_that("ホモグラフィの round-trip が厳密", {
  src <- rbind(c(10, 10), c(200, 12), c(12, 280), c(198, 282))
  dst <- rbind(c(0, 0), c(1000, 0), c(0, 1000), c(1000, 1000))
  H <- homography(src, dst)
  for (i in 1:4) {
    p <- tikzomr:::apply_h(H, src[i, ])
    expect_equal(p, dst[i, ], tolerance = 1e-6)
  }
})

test_that("2026 サンプルの読み取りがオラクルと一致する", {
  layout <- example_layout()
  res <- read_marksheet(
    system.file("examples", "sample_scan.jpg", package = "tikzomr"), layout)

  id <- paste0(unlist(res[paste0("ID", 1:6)]), collapse = "")
  expect_equal(id, "123456")

  ms <- unlist(res[paste0("M", 1:75)])
  detected <- ms[!is.na(ms)]
  expect_equal(
    detected,
    c(M1 = "8", M2 = "2", M3 = "9", M4 = "3", M51 = "5", M60 = "8")
  )
})

test_that("固定接頭辞: id_prefix 指定でフル学籍番号 id 列が付く", {
  scan <- system.file("examples", "sample_scan.jpg", package = "tikzomr")
  lay <- example_layout()

  # 既定（接頭辞なし）は id 列を出さず，従来出力のまま
  r0 <- read_marksheet(scan, lay)
  expect_false("id" %in% names(r0))

  # 引数で接頭辞指定 → 先頭に id 列，マーク桁 ID1..6 は不変
  r1 <- read_marksheet(scan, lay, id_prefix = "HP")
  expect_equal(names(r1)[1], "id")
  expect_equal(r1$id, "HP123456")
  expect_equal(paste0(unlist(r1[paste0("ID", 1:6)]), collapse = ""), "123456")
})

test_that("固定接頭辞: make_marksheet の layout から自動で引き継ぐ", {
  scan <- system.file("examples", "sample_scan.jpg", package = "tikzomr")
  cfg <- default_config(); cfg$id$prefix <- "HP"
  # make_marksheet の marks/fiducials は同梱 example と一致するので layout に使える
  lay <- make_marksheet(cfg)
  r <- read_marksheet(scan, lay)              # id_prefix 引数なしでも layout 由来で付く
  expect_equal(r$id, "HP123456")
})
