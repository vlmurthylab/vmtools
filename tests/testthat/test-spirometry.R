# Reference values are computed from the official GLI lookup tables (spline linearly interpolated
# between 0.25-year ages, as GLI specifies): GLI-2012 (Quanjer PH, et al. Eur Respir J 2012) for
# Caucasians and GLI Global (Bowerman C, et al. Am J Respir Crit Care Med 2023). vmtools replaces
# the lookup tables with fitted polynomials, so predicted values and LLNs are compared within 0.5%.
# The cases straddle the polynomial joins at ages 12 and 25.

cases <- data.frame(age    = c(4.5, 8.3, 11.9, 12.1, 16.5, 24.9, 25.1, 40, 70, 85),
                    height = c(105, 128, 150, 152, 170, 175, 165, 175, 160, 170),
                    sex    = c("F", "M", "F", "M", "M", "F", "F", "M", "F", "M"))
tol <- 0.005

test_that("GLI-2012 FEV1 matches the official tables (Caucasian)", {
  res <- predict_FEV1(cases$age, cases$height, "caucasian", cases$sex, equations = "GLI-2012")
  expect_equal(res$fev1_pred, c(0.9676, 1.6050, 2.4239, 2.5536, 3.9746, 3.8387, 3.3854, 4.0780, 2.1360, 2.4742), tolerance = tol)
  expect_equal(res$fev1_lln,  c(0.7532, 1.2889, 1.9524, 2.0665, 3.1917, 3.0850, 2.7205, 3.2313, 1.5561, 1.6799), tolerance = tol)
})

test_that("GLI-2012 FVC matches the official tables (Caucasian)", {
  res <- predict_FVC(cases$age, cases$height, "caucasian", cases$sex, equations = "GLI-2012")
  expect_equal(res$fvc_pred, c(1.0277, 1.8300, 2.7426, 2.9941, 4.5995, 4.5062, 3.9439, 5.0546, 2.7491, 3.3506), tolerance = tol)
  expect_equal(res$fvc_lln,  c(0.7962, 1.4695, 2.2170, 2.4327, 3.7321, 3.6000, 3.1508, 4.0233, 2.0069, 2.3833), tolerance = tol)
})

test_that("GLI Global FEV1 matches the official tables", {
  res <- predict_FEV1(cases$age, cases$height, sex = cases$sex, equations = "GLI-Global")
  expect_equal(res$fev1_pred, c(0.9247, 1.5690, 2.3403, 2.4729, 3.7003, 3.6808, 3.1965, 3.8355, 2.0651, 2.3923), tolerance = tol)
  expect_equal(res$fev1_lln,  c(0.7093, 1.2311, 1.8333, 1.9471, 2.9134, 2.8412, 2.4671, 2.9388, 1.4404, 1.7128), tolerance = tol)
})

test_that("GLI Global FVC matches the official tables", {
  res <- predict_FVC(cases$age, cases$height, sex = cases$sex, equations = "GLI-Global")
  expect_equal(res$fvc_pred, c(0.9843, 1.7791, 2.6327, 2.8870, 4.2380, 4.2974, 3.6840, 4.6986, 2.6400, 3.2628), tolerance = tol)
  expect_equal(res$fvc_lln,  c(0.7608, 1.3980, 2.0610, 2.2735, 3.3349, 3.3275, 2.8523, 3.6177, 1.8694, 2.3937), tolerance = tol)
})

test_that("GLI-2012 FEV1 reproduces the worked examples in the GLI implementation memo (2015)", {
  # 'Implementing GLI 2012 lung function regression equations', 19 July 2015, Section 3 (look-up table results).
  # The memo rounds to 4 decimals and uses 1.644 rather than 1.645 for the LLN, hence the tolerances.
  res <- predict_FEV1(age = c(4.8, 12.2, 53, 39.1, 39.1), height = c(107, 152, 175, 165, 165),
                      race = c("caucasian", "aa", "sea", "sea", "other"), sex = c("M", "M", "M", "F", "F"),
                      fev1 = c(0.800, 2.405, 2.410, 2.210, 2.210), equations = "GLI-2012")
  expect_equal(res$fev1_pred, c(1.0442, 2.1860, 3.3911, 2.7794, 2.9219), tolerance = tol)
  expect_equal(res$fev1_lln,  c(0.8212, 1.7193, 2.5967, 2.1736, 2.3239), tolerance = tol)
  expect_lt(max(abs(res$fev1_Z - c(-1.80, 0.78, -2.01, -1.55, -1.95))), 0.03)
})

test_that("Z-score and percent predicted are consistent", {
  res <- predict_FEV1(40, 175, "c", "M", fev1 = 4.0780, equations = "GLI-2012")
  expect_equal(res$fev1_pct_pred, 100, tolerance = tol)
  expect_lt(abs(res$fev1_Z), 0.03)
})

test_that("the equations column records what was used", {
  res <- predict_FEV1(c(40, 40), 175, c("caucasian", "sea"), "M", equations = "GLI-2012")
  expect_equal(res$equations, c("GLI-2012 (Caucasian)", "GLI-2012 (South East Asian)"))
  expect_equal(predict_FEV1(40, 175, sex = "M", equations = "GLI-Global")$equations, "GLI-Global")
})

test_that("auto uses GLI-2012 when race is known and GLI Global when it is not", {
  res <- predict_FEV1(c(40, 40, 40), 175, c("caucasian", NA, "unknown"), "M", equations = "auto")
  expect_equal(res$equations, c("GLI-2012 (Caucasian)", "GLI-Global", "GLI-Global"))
  expect_equal(res$fev1_pred[2], predict_FEV1(40, 175, sex = "M", equations = "GLI-Global")$fev1_pred)
})

test_that("missing race under GLI-2012 gives NA with a warning", {
  expect_warning(res <- predict_FEV1(40, 175, NA, "M", equations = "GLI-2012"), "Missing or unknown race")
  expect_true(is.na(res$fev1_pred))
})

test_that("race is ignored, with a warning, under GLI Global", {
  expect_warning(res <- predict_FVC(40, 175, "aa", "M", equations = "GLI-Global"), "race is ignored")
  expect_equal(res$fvc_pred, predict_FVC(40, 175, sex = "M", equations = "GLI-Global")$fvc_pred)
})

test_that("shortcuts match equations = 'GLI-Global'", {
  expect_equal(predict_FEV1_global(cases$age, cases$height, cases$sex),
               predict_FEV1(cases$age, cases$height, sex = cases$sex, equations = "GLI-Global"))
  expect_equal(predict_FVC_global(cases$age, cases$height, cases$sex),
               predict_FVC(cases$age, cases$height, sex = cases$sex, equations = "GLI-Global"))
})

test_that("out-of-range ages, unrecognized sex or race, and bad equations are handled", {
  expect_true(is.na(predict_FVC(2.5, 90, "c", "M", equations = "GLI-2012")$fvc_pred))
  expect_true(is.na(predict_FVC(96, 170, "c", "M", equations = "GLI-2012")$fvc_pred))
  expect_true(is.na(predict_FEV1(40, 175, "c", "x", equations = "GLI-2012")$fev1_pred))
  expect_warning(res <- predict_FEV1(40, 175, "martian", "M", equations = "GLI-2012"), "Unrecognized race")
  expect_true(is.na(res$fev1_pred))
  expect_error(predict_FEV1(40, 175, "c", "M", equations = "GLI-2021"))
  expect_error(predict_FEV1(c(40, 50), c(175, 170, 160), "c", "M"))
})

test_that("existing positional calls still work and default to GLI-2012", {
  res <- predict_FEV1(40, 175, "caucasian", "M", 4.0)
  expect_equal(res$equations, "GLI-2012 (Caucasian)")
})
