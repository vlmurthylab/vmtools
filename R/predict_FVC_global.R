#' Predict FVC based on the race-neutral Global Lung Function Initiative (GLI Global) equations
#'
#' This function computes predicted FVC from the race-neutral GLI Global equations
#' (Bowerman C, et al. Am J Respir Crit Care Med 2023; doi:10.1164/rccm.202205-0963OC).
#'
#' The GLI Global age splines are approximated by fifth-order polynomials in age/100, fitted by vmtools
#' to the official GLI Global lookup tables for ages 25-95. They agree with the tables to within 0.3\%
#' (see tests/testthat/test-spirometry.R).
#'
#' @param age age in years (ages 25-95)
#' @param height height in centimeters
#' @param sex 0=female/1=male
#' @param fvc measured FVC (optional). If provided, Z-score and percent predicted will be computed
#' @return data frame of predicted FVC, coefficient of variation, skewness, lower limit of normal,
#' Z-score (if fvc is provided) and percent predicted FVC (if fvc is provided)
#' @keywords FVC
#' @examples
#'
#' age <- c(30, 61.5, 53, 39.1)
#' height <- c(180, 152, 175, 165)
#' sex <- c("M", "M", "M", "F")
#' fvc <- c(5.0, 3.1, 3.2, 2.9)
#'
#' predict_FVC_global(age, height, sex, fvc)
#'
#' @export

predict_FVC_global <- function(age, height, sex, fvc=NA) {

  # Make sure length of all variables are equal
  stopifnot(all(sapply(list(age, height), function(x) length(x) == length(sex))))
  stopifnot(all(is.na(fvc)) | (length(fvc)==length(age)))

  # Check if age is in the right range
  age <- ifelse(age <25 | age >95, NA, age)
  female <- ifelse(tolower(as.character(sex)) %in% c("0","f","female"),TRUE,FALSE)
  male <- ifelse(tolower(as.character(sex)) %in% c("1","m","male"),TRUE,FALSE)
  age[!(female | male)] <- NA

  # Polynomial in age/100 approximating the GLI Global spline (age.ge.25 is the constant term)
  x <- age/100
  poly5 <- function(cf_f, cf_m) {
    cf <- ifelse(female, 1, 0) %o% cf_f + ifelse(female, 0, 1) %o% cf_m
    rowSums(cf * outer(x, 0:5, "^"))
  }
  Mspline <- poly5(c(-0.201, 2.0965, -3.8662, -0.4293, 4.163, -2.0826), c(0.222, -1.157, 5.2987, -12.9143, 12.4834, -4.2568))
  Sspline <- poly5(c(0.4666, -4.2666, 11.8046, -13.7418, 7.4424, -1.4965), c(0.054, -1.0685, 3.9559, -5.7182, 3.9655, -1.0856))

  # Compute M, S, L, LLN, percent predicted, Z-score
  M <- exp(ifelse(female, -12.055901, -12.629131) + ifelse(female, 2.621579, 2.727421)*log(height) +
             ifelse(female, -0.035975, 0.009174)*log(age) + Mspline)
  S <- exp(ifelse(female, -2.310148, -2.195595) + ifelse(female, 0.120428, 0.068466)*log(age) + Sspline)
  L <- ifelse(female, 0.899, 0.9346)
  LLN <- exp(log(1-1.645*L*S)/L + log(M))
  pct_pred <- (fvc/M) * 100
  Z <-((fvc/M)^L -1)/(L*S)

  # Data frame for return
  data.frame(fvc_pred=M, cv=S, skew=L, fvc_lln=LLN, fvc_pct_pred=pct_pred, fvc_Z=Z)
}
