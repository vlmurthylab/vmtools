# Reference values come from published worked examples, so these tests check
# the implementations against the source papers rather than against themselves.

test_that("PCE reproduces the Goff 2013 worked example (55 y, TC 213, HDL 50, SBP 120 untreated)", {
  # Goff DC, et al. Circulation 2014;129:S49-S73, Table A: 2.1%, 3.0%, 5.3%, 6.1%.
  # The paper rounds the white-male individual sum to 60.69 before exponentiating,
  # which gives 5.3%; the unrounded sum (60.6996) gives 5.38%, hence the wider tolerance.
  expect_lt(abs(calcPCE(55, "white", "female", 213, 50, 120, 0, 0, 0) - 0.021), 0.0006)
  expect_lt(abs(calcPCE(55, "black", "female", 213, 50, 120, 0, 0, 0) - 0.030), 0.0006)
  expect_lt(abs(calcPCE(55, "white", "male",   213, 50, 120, 0, 0, 0) - 0.053), 0.0011)
  expect_lt(abs(calcPCE(55, "black", "male",   213, 50, 120, 0, 0, 0) - 0.061), 0.0006)
})

# PREVENT example: 50 y, SBP 160 on treatment, TC 200, HDL 45, diabetes, non-smoker,
# no statin, eGFR 90, BMI 35. Expected 10-year risks are the values in the
# preventr package's test suite (tests/testthat/test-estimate_risk.R, preventr 0.12.1).
test_that("PREVENT total CVD matches reference values", {
  expect_equal(round(calcPREVENT.totalCVD(50, "female", 200, 45, 160, 1, 0, 1, 0, 90), 3), 0.147)
  expect_equal(round(calcPREVENT.totalCVD(50, "male",   200, 45, 160, 1, 0, 1, 0, 90), 3), 0.163)
})

test_that("PREVENT ASCVD matches reference values", {
  expect_equal(round(calcPREVENT.ASCVD(50, "female", 200, 45, 160, 1, 0, 1, 0, 90), 3), 0.092)
  expect_equal(round(calcPREVENT.ASCVD(50, "male",   200, 45, 160, 1, 0, 1, 0, 90), 3), 0.102)
})

test_that("PREVENT heart failure matches reference values", {
  expect_equal(round(calcPREVENT.HF(50, "female", 160, 1, 0, 1, 35, 90), 3), 0.081)
  expect_equal(round(calcPREVENT.HF(50, "male",   160, 1, 0, 1, 35, 90), 3), 0.106)
})

test_that("documented smoking labels are recognized", {
  base <- calcPREVENT.ASCVD(50, 0, 200, 45, 160, 1, 0, 1, 0, 90)
  for (lbl in c("n", "no", "former", "non-smoker")) {
    expect_equal(calcPREVENT.ASCVD(50, 0, 200, 45, 160, 1, lbl, 1, 0, 90), base)
  }
  expect_equal(calcPCE(55, 0, 0, 213, 50, 120, 0, "no", 0), calcPCE(55, 0, 0, 213, 50, 120, 0, 0, 0))
})

test_that("risk functions are vectorized and return NA for unrecognized sex", {
  r <- calcPREVENT.ASCVD(c(50, 60), c(0, 1), 200, 45, 160, 1, 0, 1, 0, 90)
  expect_length(r, 2)
  expect_true(is.na(calcPREVENT.ASCVD(50, "unknown", 200, 45, 160, 1, 0, 1, 0, 90)))
})
