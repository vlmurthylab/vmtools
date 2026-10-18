# Reference values are computed independently from the official GLI lookup tables (spline linearly
# interpolated between 0.25-year ages, as GLI specifies): GLI-2012 (Quanjer PH, et al. Eur Respir J 2012)
# for Caucasians and GLI Global (Bowerman C, et al. Am J Respir Crit Care Med 2023), rounded to 4 decimals; LLN uses z = qnorm(0.95).
# method = "lookup" must match them to rounding; method = "polynomial" (fitted formulas) within 0.5%.
# The cases straddle the polynomial joins at ages 12 and 25.

cases <- data.frame(age    = c(4.5, 8.3, 11.9, 12.1, 16.5, 24.9, 25.1, 40, 70, 85),
                    height = c(105, 128, 150, 152, 170, 175, 165, 175, 160, 170),
                    sex    = c("F", "M", "F", "M", "M", "F", "F", "M", "F", "M"))
tols <- c(lookup = 2e-4, polynomial = 0.005)

test_that("GLI-2012 FEV1 matches the official tables (Caucasian)", {
  for (method in names(tols)) {
  tol <- tols[[method]]
  res <- predict_FEV1(cases$age, cases$height, "caucasian", cases$sex, equations = "GLI-2012", method = method)
  expect_equal(res$fev1_pred, c(0.9676, 1.6050, 2.4239, 2.5536, 3.9746, 3.8387, 3.3854, 4.0780, 2.1360, 2.4742), tolerance = tol)
  expect_equal(res$fev1_lln,  c(0.7533, 1.2890, 1.9524, 2.0666, 3.1917, 3.0851, 2.7206, 3.2313, 1.5562, 1.6800), tolerance = tol)
  }
})

test_that("GLI-2012 FVC matches the official tables (Caucasian)", {
  for (method in names(tols)) {
  tol <- tols[[method]]
  res <- predict_FVC(cases$age, cases$height, "caucasian", cases$sex, equations = "GLI-2012", method = method)
  expect_equal(res$fvc_pred, c(1.0277, 1.8300, 2.7426, 2.9941, 4.5995, 4.5062, 3.9439, 5.0546, 2.7491, 3.3506), tolerance = tol)
  expect_equal(res$fvc_lln,  c(0.7962, 1.4696, 2.2171, 2.4327, 3.7322, 3.6000, 3.1509, 4.0234, 2.0069, 2.3834), tolerance = tol)
  }
})

test_that("GLI Global FEV1 matches the official tables", {
  for (method in names(tols)) {
  tol <- tols[[method]]
  res <- predict_FEV1(cases$age, cases$height, sex = cases$sex, equations = "GLI-Global", method = method)
  expect_equal(res$fev1_pred, c(0.9247, 1.5690, 2.3403, 2.4729, 3.7003, 3.6808, 3.1965, 3.8355, 2.0651, 2.3923), tolerance = tol)
  expect_equal(res$fev1_lln,  c(0.7094, 1.2311, 1.8334, 1.9472, 2.9135, 2.8413, 2.4672, 2.9389, 1.4405, 1.7128), tolerance = tol)
  }
})

test_that("GLI Global FVC matches the official tables", {
  for (method in names(tols)) {
  tol <- tols[[method]]
  res <- predict_FVC(cases$age, cases$height, sex = cases$sex, equations = "GLI-Global", method = method)
  expect_equal(res$fvc_pred, c(0.9843, 1.7791, 2.6327, 2.8870, 4.2380, 4.2974, 3.6840, 4.6986, 2.6400, 3.2628), tolerance = tol)
  expect_equal(res$fvc_lln,  c(0.7608, 1.3980, 2.0611, 2.2736, 3.3350, 3.3276, 2.8524, 3.6178, 1.8694, 2.3937), tolerance = tol)
  }
})

test_that("GLI-2012 FEV1 reproduces the worked examples in the GLI implementation memo (2015)", {
  # 'Implementing GLI 2012 lung function regression equations', 19 July 2015, Section 3 (look-up table results).
  # The memo rounds intermediate values to 4 decimals and uses z = 1.644 for the LLN (vmtools uses qnorm(0.95) = 1.6449).
  memo <- function(method) predict_FEV1(age = c(4.8, 12.2, 53, 39.1, 39.1), height = c(107, 152, 175, 165, 165),
                      race = c("caucasian", "aa", "sea", "sea", "other"), sex = c("M", "M", "M", "F", "F"),
                      fev1 = c(0.800, 2.405, 2.410, 2.210, 2.210), equations = "GLI-2012", method = method)
  pred <- c(1.0442, 2.1860, 3.3911, 2.7794, 2.9219); lln <- c(0.8212, 1.7193, 2.5967, 2.1736, 2.3239)
  z <- c(-1.80, 0.78, -2.01, -1.55, -1.95)
  res <- memo("lookup")
  expect_equal(res$fev1_pred, pred, tolerance = 2e-4)
  expect_equal(res$fev1_lln, lln, tolerance = 5e-4)
  expect_lt(max(abs(res$fev1_Z - z)), 0.01)
  res <- memo("polynomial")
  expect_equal(res$fev1_pred, pred, tolerance = 0.005)
  expect_equal(res$fev1_lln, lln, tolerance = 0.005)
  expect_lt(max(abs(res$fev1_Z - z)), 0.03)
})

test_that("lookup interpolates linearly and covers the table ends", {
  # Halfway between two table ages the spline is the average of the two rows
  a <- predict_FVC(c(40, 40.125, 40.25), 170, sex = "F", equations = "GLI-Global")$fvc_pred
  sp <- log(a) - (-12.055901 + 2.621579 * log(170) - 0.035975 * log(c(40, 40.125, 40.25)))
  expect_equal(sp[2], mean(sp[c(1, 3)]), tolerance = 1e-10)
  expect_false(is.na(predict_FEV1(3, 95, "c", "M", equations = "GLI-2012")$fev1_pred))
  expect_false(is.na(predict_FEV1(95, 170, "c", "F", equations = "GLI-2012")$fev1_pred))
})

test_that("method must be lookup or polynomial", {
  expect_error(predict_FEV1(40, 175, "c", "M", equations = "GLI-2012", method = "spline"))
})

test_that("Z-score and percent predicted are consistent", {
  res <- predict_FEV1(40, 175, "c", "M", fev1 = 4.0780, equations = "GLI-2012")
  expect_equal(res$fev1_pct_pred, 100, tolerance = 2e-4)
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

test_that("shortcuts match the corresponding equations argument", {
  expect_equal(predict_FEV1_gliglobal(cases$age, cases$height, cases$sex),
               predict_FEV1(cases$age, cases$height, sex = cases$sex, equations = "GLI-Global"))
  expect_equal(predict_FVC_gliglobal(cases$age, cases$height, cases$sex),
               predict_FVC(cases$age, cases$height, sex = cases$sex, equations = "GLI-Global"))
  expect_equal(predict_FEV1_gli2012(cases$age, cases$height, "aa", cases$sex),
               predict_FEV1(cases$age, cases$height, "aa", cases$sex, equations = "GLI-2012"))
  expect_equal(predict_FVC_gli2012(cases$age, cases$height, "nea", cases$sex),
               predict_FVC(cases$age, cases$height, "nea", cases$sex, equations = "GLI-2012"))
  expect_error(predict_FEV1_gli2012(40, 175, sex = "M"))   # race is required
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

test_that("base coefficients match their published sources exactly", {
  cf <- vmtools:::.gli_coef
  # GLI Global: Bowerman C, et al. Am J Respir Crit Care Med 2023, online supplement Table E2
  expect_identical(cf[["GLI-Global.FEV1.male"]]$a[1:3],   c(-11.399108, 2.462664, -0.011394))
  expect_identical(cf[["GLI-Global.FEV1.male"]]$p[1:2],   c(-2.256278, 0.080729))
  expect_identical(cf[["GLI-Global.FEV1.male"]]$q[1],     1.22703)
  expect_identical(cf[["GLI-Global.FVC.male"]]$a[1:3],    c(-12.629131, 2.727421, 0.009174))
  expect_identical(cf[["GLI-Global.FVC.male"]]$p[1:2],    c(-2.195595, 0.068466))
  expect_identical(cf[["GLI-Global.FVC.male"]]$q[1],      0.9346)
  expect_identical(cf[["GLI-Global.FEV1.female"]]$a[1:3], c(-10.901689, 2.385928, -0.076386))
  expect_identical(cf[["GLI-Global.FEV1.female"]]$p[1:2], c(-2.364047, 0.129402))
  expect_identical(cf[["GLI-Global.FEV1.female"]]$q[1],   1.21388)
  expect_identical(cf[["GLI-Global.FVC.female"]]$a[1:3],  c(-12.055901, 2.621579, -0.035975))
  expect_identical(cf[["GLI-Global.FVC.female"]]$p[1:2],  c(-2.310148, 0.120428))
  expect_identical(cf[["GLI-Global.FVC.female"]]$q[1],    0.899)
  # GLI-2012 FEV1: GLI memo (2015) Tables E1 (male) and E3 (female)
  expect_identical(cf[["GLI-2012.FEV1.male"]]$a,   c(-10.3420, 2.2196, 0.0574, -0.1589, -0.0351, -0.0881, -0.0708))
  expect_identical(cf[["GLI-2012.FEV1.male"]]$p,   c(-2.3268, 0.0798, 0.1096, -0.3973, 0.0327, 0.0114))
  expect_identical(cf[["GLI-2012.FEV1.male"]]$q,   c(0.8866, 0.0850))
  expect_identical(cf[["GLI-2012.FEV1.female"]]$a, c(-9.6987, 2.1211, -0.0270, -0.1484, -0.0149, -0.1208, -0.0708))
  expect_identical(cf[["GLI-2012.FEV1.female"]]$p, c(-2.3765, 0.0972, 0.1016, -0.0109, 0.0733, 0.0114))
  expect_identical(cf[["GLI-2012.FEV1.female"]]$q, c(1.1540, 0))
})
