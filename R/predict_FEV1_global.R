#' Predict FEV1 based on the race-neutral Global Lung Function Initiative (GLI Global) equations
#'
#' This function computes predicted FEV1 from the race-neutral GLI Global equations
#' (Bowerman C, et al. Am J Respir Crit Care Med 2023; doi:10.1164/rccm.202205-0963OC).
#'
#' The GLI Global age splines are approximated by fifth-order polynomials in age/100, fitted by vmtools
#' to the official GLI Global lookup tables for ages 25-95. They agree with the tables to within 0.3\%
#' (see tests/testthat/test-spirometry.R).
#'
#' @param age age in years (ages 25-95)
#' @param height height in centimeters
#' @param sex 0=female/1=male
#' @param fev1 measured FEV1 (optional). If provided, Z-score and percent predicted will be computed
#' @return data frame of predicted FEV1, coefficient of variation, skewness, lower limit of normal,
#' Z-score (if fev1 is provided) and percent predicted FEV1 (if fev1 is provided)
#' @keywords FEV1
#' @examples
#'
#' age <- c(30, 61.5, 53, 39.1)
#' height <- c(180, 152, 175, 165)
#' sex <- c("M", "M", "M", "F")
#' fev1 <- c(4.1, 2.405, 2.410, 2.210)
#'
#' predict_FEV1_global(age, height, sex, fev1)
#'
#' @export

predict_FEV1_global <- function(age, height, sex, fev1=NA) {

  # Make sure length of all variables are equal
  stopifnot(all(sapply(list(age, height), function(x) length(x) == length(sex))))
  stopifnot(all(is.na(fev1)) | (length(fev1)==length(age)))

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
  Mspline <- poly5(c(0.0988, -0.1738, 3.4408, -12.1741, 13.0819, -4.6777), c(0.712, -5.2702, 19.4787, -36.8269, 31.4798, -10.0241))
  Sspline <- poly5(c(0.3785, -3.5729, 9.8101, -11.0005, 5.5919, -1.0041), c(0.0632, -1.3004, 4.7424, -6.6416, 4.4482, -1.1759))

  # Compute M, S, L, LLN, percent predicted, Z-score
  M <- exp(ifelse(female, -10.901689, -11.399108) + ifelse(female, 2.385928, 2.462664)*log(height) +
             ifelse(female, -0.076386, -0.011394)*log(age) + Mspline)
  S <- exp(ifelse(female, -2.364047, -2.256278) + ifelse(female, 0.129402, 0.080729)*log(age) + Sspline)
  L <- ifelse(female, 1.21388, 1.22703)
  LLN <- exp(log(1-1.645*L*S)/L + log(M))
  pct_pred <- (fev1/M) * 100
  Z <-((fev1/M)^L -1)/(L*S)

  # Data frame for return
  data.frame(fev1_pred=M, cv=S, skew=L, fev1_lln=LLN, fev1_pct_pred=pct_pred, fev1_Z=Z)
}
