#' Calculate Avignon SI
#'
#' This function calculates Avignon insulin sensitivity index from 2 hour oral glucose tolerance test
#' Reference: Avignon A, et al. International Journal of Obesity 1999; 23:512-7
#' DOI: 10.1038/sj.ijo.0800864
#' @param insulin.fasting fasting insulin in μU/mL
#' @param glucose.fasting fasting glucose in mass units (mg/dL)
#' @param insulin.2h 2-hour insulin in μU/mL
#' @param glucose.2h 2-hour glucose in mass units (mg/dL)
#' @param weight body weight in kg
#' @return Avignon SI.b, SI.2h and SI.m as numeric value
#' @keywords Avignon SI.b
#' @examples
#' calcAvignon.SI(15.0,100.0,30,150,80)
#'
#' glucose.fasting.vals <- seq(75,175,by=25)
#' insulin.fasting.vals <- seq(2,20, by=1)
#' glucose.2h.vals <- seq(75,175,by=25)
#' insulin.2h.vals <- seq(2,20, by=1)
#' weight.vals <- seq(50,90,by=10)
#' test.dat <- expand.grid(insulin.fasting=insulin.fasting.vals,glucose.fasting=glucose.fasting.vals,
#'                         insulin.2h=insulin.2h.vals,glucose.2h=glucose.2h.vals,weight=weight.vals)
#'
#' test.dat <- cbind(test.dat,calcAvignon.SI(insulin.fasting=test.dat$insulin.fasting,
#'                                           glucose.fasting=test.dat$glucose.fasting,
#'                                           insulin.2h=test.dat$insulin.2h,
#'                                           glucose.2h=test.dat$glucose.2h,
#'                                           weight=test.dat$weight))
#' @export

calcAvignon.SI <- function(insulin.fasting,glucose.fasting,insulin.2h,glucose.2h,weight) {
  VD <- 150 * weight
  SI.b <- 1e8 / (insulin.fasting * glucose.fasting * VD)
  SI.2h <- 1e8 / (insulin.2h * glucose.2h * VD)
  SI.m <- ((0.137*SI.b) + SI.2h)/2

  return(data.frame(SI.b,SI.2h,SI.m))
}
