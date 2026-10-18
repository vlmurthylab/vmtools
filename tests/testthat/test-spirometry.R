# Reference values computed from the official GLI-2012 lookup tables
# (Quanjer PH, et al. Eur Respir J 2012;40:1324-43) for Caucasian adults.
# vmtools approximates the GLI age splines with polynomials for ages 25-95,
# which agree with the tables to within 0.5%.

gli_cases <- data.frame(age = c(40, 70, 30, 85), height = c(175, 160, 165, 170),
                        sex = c("M", "F", "F", "M"))

test_that("predict_FEV1 matches GLI-2012 for Caucasian adults", {
  res <- predict_FEV1(gli_cases$age, gli_cases$height, rep("caucasian", 4), gli_cases$sex)
  expect_equal(res$fev1_pred, c(4.0780, 2.1360, 3.3158, 2.4742), tolerance = 0.005)
  expect_equal(res$fev1_lln,  c(3.2313, 1.5561, 2.6614, 1.6799), tolerance = 0.006)
})

test_that("predict_FVC matches GLI-2012 for Caucasian adults", {
  res <- predict_FVC(gli_cases$age, gli_cases$height, rep("caucasian", 4), gli_cases$sex)
  expect_equal(res$fvc_pred, c(5.0546, 2.7491, 3.9290, 3.3506), tolerance = 0.005)
  expect_equal(res$fvc_lln,  c(4.0233, 2.0069, 3.1413, 2.3833), tolerance = 0.006)
})

test_that("Z-score and percent predicted are consistent", {
  res <- predict_FEV1(40, 175, "c", "M", fev1 = 4.0780)
  expect_equal(res$fev1_pct_pred, 100, tolerance = 0.005)
  expect_equal(res$fev1_Z, 0, tolerance = 0.02)
})

test_that("out-of-range ages and unrecognized ethnicity return NA", {
  expect_true(is.na(predict_FVC(20, 175, "c", "M")$fvc_pred))
  expect_warning(res <- predict_FEV1(40, 175, "martian", "M"), "Unrecognized race")
  expect_true(is.na(res$fev1_pred))
})

test_that("mismatched input lengths are rejected", {
  expect_error(predict_FEV1(c(40, 50), 175, c("c", "c"), c("M", "M")))
})

# GLI Global (race-neutral) reference values, computed from the official GLI Global
# lookup tables and equations (Bowerman C, et al. Am J Respir Crit Care Med 2023).
# vmtools approximates the age splines with polynomials fitted for ages 25-95.

test_that("predict_FEV1_global matches GLI Global", {
  res <- predict_FEV1_global(gli_cases$age, gli_cases$height, gli_cases$sex)
  expect_equal(res$fev1_pred, c(3.8355, 2.0651, 3.1354, 2.3923), tolerance = 0.003)
  expect_equal(res$fev1_lln,  c(2.9388, 1.4404, 2.4096, 1.7128), tolerance = 0.003)
})

test_that("predict_FVC_global matches GLI Global", {
  res <- predict_FVC_global(gli_cases$age, gli_cases$height, gli_cases$sex)
  expect_equal(res$fvc_pred, c(4.6986, 2.6400, 3.6839, 3.2628), tolerance = 0.003)
  expect_equal(res$fvc_lln,  c(3.6177, 1.8694, 2.8451, 2.3937), tolerance = 0.003)
})

test_that("GLI Global functions return NA outside 25-95 or for unrecognized sex", {
  expect_true(is.na(predict_FEV1_global(20, 175, "M")$fev1_pred))
  expect_true(is.na(predict_FVC_global(40, 175, "unknown")$fvc_pred))
})
