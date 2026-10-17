#' Calculate HOMA-IR
#'
#' This function calculates Homeostatic Model Assessment Insulin Resistance
#' Reference: Matthews DR, et al. Diabetologia 1985;28:412-9
#' DOI: 10.1007/BF00280883
#' @param insulin in μU/mL
#' @param glucose in mass units (mg/dL)
#' @return HOMA-IR as numeric value
#' @keywords HOMA-IR
#' @examples
#' calcHOMA.IR(15.0,100.0)
#'
#' glucose.vals <- seq(75,175,by=25)
#' insulin.vals <- seq(2,20, by=1)
#' test.dat <- expand.grid(insulin=insulin.vals,glucose=glucose.vals)
#'
#' test.dat$HOMA.IR <- calcHOMA.IR(insulin=test.dat$insulin,glucose=test.dat$glucose)
#' @export

calcHOMA.IR <- function(insulin,glucose) {
  return(glucose*insulin/405)
}
