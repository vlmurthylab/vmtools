#' Predict FVC from the Global Lung Function Initiative (GLI) equations
#'
#' Computes predicted FVC, its lower limit of normal (LLN), and, if a measured value is given,
#' percent predicted and Z-score, from either the race-specific GLI-2012 equations
#' (Quanjer PH, et al. Eur Respir J 2012;40:1324-43) or the race-neutral GLI Global equations
#' (Bowerman C, et al. Am J Respir Crit Care Med 2023;207:768-74; coefficients from its online supplement,
#' Table E2, and the official GLI Global lookup tables). Valid for ages 3-95.
#'
#' @section Default equations may change:
#' \strong{The default, \code{equations = "GLI-2012"} (race-specific), is kept for backward compatibility
#' and may change to \code{"GLI-Global"} (race-neutral) in a future major version of vmtools.}
#' Current ATS guidance favors race-neutral interpretation. For new analyses, always set
#' \code{equations} explicitly so your results do not change if the default does.
#'
#' @section Equations:
#' \describe{
#'   \item{\code{"GLI-2012"}}{Race-specific equations. \code{race} is required; missing or unknown
#'     race gives \code{NA} with a warning.}
#'   \item{\code{"GLI-Global"}}{Race-neutral equations. \code{race} is not used (a warning is given
#'     if it is supplied).}
#'   \item{\code{"auto"}}{GLI-2012 where race is known and GLI Global where race is missing or
#'     \code{"unknown"}. Check the \code{equations} column of the result: a dataset processed this
#'     way uses two reference systems.}
#' }
#'
#' @section Accuracy:
#' The GLI age splines are published as lookup tables. vmtools replaces them with three
#' fifth-order polynomials in (age/100) - the form the GLI memo "Implementing GLI 2012 lung function
#' regression equations" (19 July 2015) uses for adults - on ages 3-12, 12-25 and 25-95, fitted
#' (minimax) to the official GLI tables and joined with equal value and slope at ages 12 and 25.
#' Compared with the official tables at every 0.25-year age from 3 to 95, predicted values and LLNs
#' differ by less than 0.1\% on average (at most about 0.45\%), and Z-scores by less than 0.005 on
#' average (at most about 0.035). See tests/testthat/test-spirometry.R.
#'
#' @param age age in years (3-95); outside this range the result is \code{NA}
#' @param height height in centimeters
#' @param race GLI-2012 ethnic group, case-insensitive: 0 = Caucasian ("c", "caucasian", "w", "white"),
#' 1 = African American ("aa", "african-american", "black"), 2 = North East Asian ("nea"),
#' 3 = South East Asian ("sea"), 4 = Other/mixed ("o", "other", "mixed"). \code{NA} or "unknown" means
#' unknown. Not used with \code{equations = "GLI-Global"}.
#' @param sex 0/"f"/"female" or 1/"m"/"male"; other values give \code{NA}
#' @param fvc measured FVC in liters (optional). If provided, percent predicted and Z-score are computed
#' @param equations \code{"GLI-2012"} (default; see the section on defaults), \code{"GLI-Global"} or \code{"auto"}
#' @return data frame with predicted FVC (\code{fvc_pred}), coefficient of variation (\code{cv}),
#' skewness (\code{skew}), lower limit of normal (\code{fvc_lln}), percent predicted (\code{fvc_pct_pred}),
#' Z-score (\code{fvc_Z}) and the equations used for each row (\code{equations})
#' @keywords FVC spirometry GLI
#' @examples
#' # GLI-2012 (race-specific); always state the equations explicitly
#' predict_FVC(age = c(4.8, 12.2, 53, 39.1), height = c(107, 152, 175, 165),
#'              race = c("caucasian", "aa", "sea", "other"), sex = c("M", "M", "M", "F"),
#'              fvc = c(1.10, 2.80, 3.20, 2.90), equations = "GLI-2012")
#'
#' # GLI Global (race-neutral)
#' predict_FVC(age = 39.1, height = 165, sex = "F", fvc = 2.21, equations = "GLI-Global")
#' predict_FVC_gliglobal(age = 39.1, height = 165, sex = "F", fvc = 2.21)
#'
#' # Shortcut that always uses GLI-2012, whatever the default
#' predict_FVC_gli2012(age = 39.1, height = 165, race = "sea", sex = "F", fvc = 2.21)
#'
#' # auto: GLI-2012 where race is known, GLI Global where it is not
#' predict_FVC(age = c(40, 40), height = 175, race = c("caucasian", NA), sex = "M", equations = "auto")
#' @export

predict_FVC <- function(age, height, race = NULL, sex, fvc = NA, equations = "GLI-2012") {
  .gli_predict("FVC", age, height, race, sex, fvc, equations)
}

#' @describeIn predict_FVC Race-specific GLI-2012; same as \code{equations = "GLI-2012"}, but unaffected by any
#' future change of default. \code{race} is required.
#' @export

predict_FVC_gli2012 <- function(age, height, race, sex, fvc = NA) {
  .gli_predict("FVC", age, height, race, sex, fvc, "GLI-2012")
}

#' @describeIn predict_FVC Race-neutral GLI Global; same as \code{equations = "GLI-Global"}.
#' @export

predict_FVC_gliglobal <- function(age, height, sex, fvc = NA) {
  .gli_predict("FVC", age, height, NULL, sex, fvc, "GLI-Global")
}
