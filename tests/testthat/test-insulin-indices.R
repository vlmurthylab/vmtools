test_that("insulin indices follow their published formulas", {
  # Glucose 100 mg/dL, insulin 10 uU/mL
  expect_equal(calcHOMA.IR(10, 100), 100 * 10 / 405)
  expect_equal(calcHOMA.beta(10, 100), 360 * 10 / (100 - 63))
  expect_equal(calcQUICKI(10, 100), 1 / 3)
  expect_equal(calcMatsuda.ISI(10, 100, 40, 140), 10000 / sqrt(10 * 100 * 40 * 140))
})

test_that("calcAvignon.SI returns SI.b, SI.2h and SI.m", {
  res <- calcAvignon.SI(15, 100, 30, 150, 80)
  vd <- 150 * 80
  expect_named(res, c("SI.b", "SI.2h", "SI.m"))
  expect_equal(res$SI.b, 1e8 / (15 * 100 * vd))
  expect_equal(res$SI.2h, 1e8 / (30 * 150 * vd))
  expect_equal(res$SI.m, (0.137 * res$SI.b + res$SI.2h) / 2)
})

test_that("format.pval formats by magnitude", {
  expect_equal(format.pval(c(0.00001, 0.0004, 0.004, 0.04, NA)),
               c("p<0.0001", "p=0.0004", "p=0.004", "p=0.04", "NA"))
  expect_equal(format.pval(0.04, include.p = FALSE), "0.04")
})
