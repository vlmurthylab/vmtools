#' Calculate PREVENT 10 year HF risk scores
#'
#' This function calculates PREVENT 10 year HF risk scores per recent AHA recommendations.
#' Reference: Khan SS, et al. Circulation 2024;149:430-449
#' DOI: https://doi.org/10.1161/CIRCULATIONAHA.123.067626
#' @param age age in years
#' @param sex 0=female/1=male
#' @param sbp Systolic blood pressure in mmHg
#' @param bptx treatment for blood pressure 0=FALSE/1=TRUE
#' @param smoking active smoking 0=FALSE/1=TRUE
#' @param dm diabetes mellitus 0=FALSE/1=TRUE
#' @param bmi body mass index in kg/m2
#' @param egfr estimated glomerular filtration rate in ml/min/1.73m^2
#' @param female values which indicate female in the parameter sex, case-insensitive (default=0,"f","female")
#' @param male values which indicate male in the parameter sex, case-insensitive (default=1,"m","male")
#' @param bptx.true values which indicate BP med use, case-insensitive (default=1,"t","true","y","yes")
#' @param bptx.false values which indicate no BP med use, case-insensitive (default=0,"f","false","n","no")
#' @param smoking.true values which indicate active smoking, case-insensitive (default=1,"t","true","y","yes","active")
#' @param smoking.false values which indicate no active smoking, case-insensitive (default=0,"f","false","n","no","former","non-smoker","nonsmoker")
#' @param dm.true values which indicate diabetes, case-insensitive (default=1,"t","true","y","yes")
#' @param dm.false values which indicate no diabetes, case-insensitive (default=0,"f","false","n","no")
#' @return PREVENT 10 year HF risk as numeric from 0 to 1
#' @keywords PREVENT
#' @examples
#' calcPREVENT.HF(50,0,160,1,0,1,35,90)
#' calcPREVENT.HF(55,1,120,0,0,0,40,60)
#' calcPREVENT.HF(55,0,120,0,0,0,20,60)
#' calcPREVENT.HF(55,1,120,0,0,0,50,60)
#'
#'
#' test.dat <- data.frame(age=rep(56:65,4),sex=c(rep(0,20),rep(1,20)),
#'                        sbp=rep(126:135,4),bptx=rep(c(rep(0,5),rep(1,5)),4),
#'                        smoking=rep(c(rep(0,5),rep("active",5)),4),dm=rep(c(rep("No",5),rep(1,5)),4),
#'                        bmi=c(rep(40,10),rep(20,10),rep(40,10),rep(20,10)),
#'                        egfr=c(rep(40,10),rep(90,10),rep(40,10),rep(90,10)))
#'
#' test.dat$PREVENT.HF <- calcPREVENT.HF(test.dat$age,test.dat$sex,test.dat$sbp,test.dat$bptx,
#'                                       test.dat$smoking,test.dat$dm,test.dat$bmi,test.dat$egfr)
#' @export

calcPREVENT.HF <- function(age, sex, sbp, bptx, smoking, dm, bmi, egfr,
                           female=c(0,"f","female"),male=c(1,"m","male"),
                           bptx.true=c(1,"t","true","y","yes"), bptx.false=c(0,"f","false","n","no"),
                           smoking.true=c(1,"t","true","y","yes","active"),
                           smoking.false=c(0,"f","false","n","no","former","non-smoker","nonsmoker"),
                           dm.true=c(1,"t","true","y","yes"),dm.false=c(0,"f","false","n","no")) {

  # Initialize vectors
  lodds <- rep(NA,length(age))

  age2 <- age
  age2[age2>79] <- 79
  age2[age2<30] <- 30

  bprx <- rep(NA,length(bptx))
  bprx[sapply(bptx,tolower) %in% sapply(bptx.true,tolower)] <- 1
  bprx[sapply(bptx,tolower) %in% sapply(bptx.false,tolower)] <- 0
  smoke <- rep(NA,length(smoking))
  smoke[sapply(smoking,tolower) %in% sapply(smoking.true,tolower)] <- 1
  smoke[sapply(smoking,tolower) %in% sapply(smoking.false,tolower)] <- 0
  diab <- rep(NA,length(dm))
  diab[sapply(dm,tolower) %in% sapply(dm.true,tolower)] <- 1
  diab[sapply(dm,tolower) %in% sapply(dm.false,tolower)] <- 0

  # Women
  women <- sapply(sex,tolower) %in% sapply(female,tolower)

  lodds[women] <- -4.310409 + 0.8998235*(age2[women] - 55)/10 - 0.4559771*(pmin(sbp[women], 110) - 110)/20 +
    0.3576505*(pmax(sbp[women], 110) - 130)/20 + 1.038346*(diab[women]) + 0.583916*(smoke[women]) -
    0.0072294*(pmin(bmi[women], 30) - 25)/5 + 0.2997706*(pmax(bmi[women], 30) - 30)/5 +
    0.7451638*(pmin(egfr[women], 60) - 60)/-15 + 0.0557087*(pmax(egfr[women], 60) - 90)/-15 +
    0.3534442*(bprx[women]) - 0.0981511*(bprx[women])*(pmax(sbp[women], 110) - 130)/20 -
    0.0946663*(age2[women] - 55)/10 * (pmax(sbp[women], 110) - 130)/20 -
    0.3581041*(age2[women] - 55)/10 * (diab[women]) - 0.1159453*(age2[women] - 55)/10 * (smoke[women]) -
    0.003878*(age2[women] - 55)/10 * (pmax(bmi[women], 30) - 30)/5 - 0.1884289*(age2[women] - 55)/10 * (pmin(egfr[women], 60) - 60) / -15

  # Men
  men <- sapply(sex,tolower) %in% sapply(male,tolower)

  lodds[men] <- -3.946391 + 0.8972642*(age2[men] - 55)/10 - 0.6811466*(pmin(sbp[men], 110) - 110)/20 +
    0.3634461*(pmax(sbp[men], 110) - 130)/20 + 0.923776*(diab[men]) + 0.5023736*(smoke[men]) -
    0.0485841*(pmin(bmi[men], 30) - 25)/5 + 0.3726929*(pmax(bmi[men], 30) - 30)/5 +
    0.6926917*(pmin(egfr[men], 60) - 60)/-15 + 0.0251827*(pmax(egfr[men], 60) - 90)/-15 +
    0.2980922*(bprx[men]) - 0.0497731*(bprx[men]) * (pmax(sbp[men], 110) - 130)/20 -
    0.1289201*(age2[men] - 55)/10 * (pmax(sbp[men], 110) - 130)/20 -
    0.3040924*(age2[men] - 55)/10 * (diab[men]) - 0.1401688*(age2[men] - 55)/10 * (smoke[men]) +
    0.0068126*(age2[men] - 55)/10 * (pmax(bmi[men], 30) - 30)/5 - 0.1797778*(age2[men] - 55)/10 * (pmin(egfr[men], 60) - 60)/-15

  prevent <- exp(lodds)/(1+exp(lodds))

  return(prevent)
}
