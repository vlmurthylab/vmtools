#' Calculate HOMA-β
#'
#' This function calculates Homeostatic Model Assessment β-cell function
#' Reference: Matthews DR, et al. Diabetologia 1985;28:412-9
#' DOI: 10.1007/BF00280883
#' @param insulin in μU/mL
#' @param glucose in mass units (mg/dL)
#' @return HOMA-β cell function as percentage value
#' @keywords HOMA-β
#' @examples
#' calcHOMA.beta(15.0,100.0)
#'
#' glucose.vals <- seq(75,175,by=25)
#' insulin.vals <- seq(2,20, by=1)
#' test.dat <- expand.grid(insulin=insulin.vals,glucose=glucose.vals)
#'
#' test.dat$HOMA.beta <- calcHOMA.beta(insulin=test.dat$insulin,glucose=test.dat$glucose)
#' @export

calcHOMA.beta <- function(insulin,glucose) {
  return((360*insulin)/(ifelse(glucose<63,63,glucose)-63))
}
