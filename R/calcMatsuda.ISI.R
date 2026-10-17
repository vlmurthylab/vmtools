#' Calculate Matsuda ISI
#'
#' This function calculates Matsuda insulin sensitivity index from 2 hour oral glucose tolerance test
#' Reference: Matsuda M and DeFronzo RA. Diabetes Care 1999; 22:1462-70
#' DOI: 10.2337/diacare.22.9.1462
#' @param insulin.fasting in μU/mL
#' @param glucose.fasting in mass units (mg/dL)
#' @param insulin.mean in μU/mL
#' @param glucose.mean in mass units (mg/dL)
#' @return Matsuda ISI as numeric value
#' @keywords Matsuda ISI
#' @examples
#' calcMatsuda.ISI(15.0,100.0,30,150)
#'
#' glucose.fasting.vals <- seq(75,175,by=25)
#' insulin.fasting.vals <- seq(2,20, by=1)
#' glucose.mean.vals <- seq(75,175,by=25)
#' insulin.mean.vals <- seq(2,20, by=1)
#' test.dat <- expand.grid(insulin.fasting=insulin.fasting.vals,glucose.fasting=glucose.fasting.vals,
#'                         insulin.mean=insulin.mean.vals,glucose.mean=glucose.mean.vals)
#'
#' test.dat$Matsuda.ISI <- calcMatsuda.ISI(insulin.fasting=test.dat$insulin.fasting,
#'                                         glucose.fasting=test.dat$glucose.fasting,
#'                                         insulin.mean=test.dat$insulin.mean,
#'                                         glucose.mean=test.dat$glucose.mean)
#' @export

calcMatsuda.ISI <- function(insulin.fasting,glucose.fasting,insulin.mean,glucose.mean) {
  return(10000/sqrt(insulin.fasting*glucose.fasting*insulin.mean*glucose.mean))
}
