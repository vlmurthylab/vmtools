#' Calculate PREVENT 10 year total CVD risk scores
#'
#' This function calculates PREVENT 10 year total CVD risk scores per recent AHA recommendations.
#' Reference: Khan SS, et al. Circulation 2024;149:430-449
#' DOI: https://doi.org/10.1161/CIRCULATIONAHA.123.067626
#' @param age age in years
#' @param sex 0=female/1=male
#' @param tc total cholesterol in mg/dl
#' @param hdl HDL cholesterol in mg/dl
#' @param sbp Systolic blood pressure in mmHg
#' @param bptx treatment for blood pressure 0=FALSE/1=TRUE
#' @param smoking active smoking 0=FALSE/1=TRUE
#' @param dm diabetes mellitus 0=FALSE/1=TRUE
#' @param statin use of statin medication 0=FALSE/1=TRUE
#' @param egfr estimated glomerular filtration rate in ml/min/1.73m^2
#' @param female values which indicate female in the parameter sex, case-insensitive (default=0,"f","female")
#' @param male values which indicate male in the parameter sex, case-insensitive (default=1,"m","male")
#' @param bptx.true values which indicate BP med use, case-insensitive (default=1,"t","true","y","yes")
#' @param bptx.false values which indicate no BP med use, case-insensitive (default=0,"f","false","n","no")
#' @param smoking.true values which indicate active smoking, case-insensitive (default=1,"t","true","y","yes","active")
#' @param smoking.false values which indicate no active smoking, case-insensitive (default=0,"f","false","n","no","former","non-smoker","nonsmoker")
#' @param dm.true values which indicate diabetes, case-insensitive (default=1,"t","true","y","yes")
#' @param dm.false values which indicate no diabetes, case-insensitive (default=0,"f","false","n","no")
#' @param statin.true values which indicate statin use, case-insensitive (default=1,"t","true","y","yes")
#' @param statin.false values which indicate no statin use, case-insensitive (default=0,"f","false","n","no")
#' @return PREVENT 10 year total CVD risk as numeric from 0 to 1
#' @keywords PREVENT
#' @examples
#' calcPREVENT.totalCVD(50,0,200,45,160,1,0,1,0,90)
#' calcPREVENT.totalCVD(55,1,213,50,120,0,0,0,0,60)
#' calcPREVENT.totalCVD(55,0,213,50,120,0,0,0,0,60)
#' calcPREVENT.totalCVD(55,1,213,50,120,0,0,0,0,60)
#'
#'
#' test.dat <- data.frame(age=rep(56:65,4),sex=c(rep(0,20),rep(1,20)),tc=rep(136:145,4),hdl=rep(46:55,4),
#'                        sbp=rep(126:135,4),bptx=rep(c(rep(0,5),rep(1,5)),4),
#'                        smoking=rep(c(rep(0,5),rep("active",5)),4),dm=rep(c(rep("No",5),rep(1,5)),4),
#'                        statin=c(rep(0,10),rep(1,10),rep(0,10),rep(1,10)),
#'                        egfr=c(rep(40,10),rep(90,10),rep(40,10),rep(90,10)))
#'
#' test.dat$PREVENT.totalCVD <- calcPREVENT.totalCVD(test.dat$age,test.dat$sex,test.dat$tc,test.dat$hdl,
#'                                                   test.dat$sbp,test.dat$bptx,test.dat$smoking,test.dat$dm,
#'                                                   test.dat$statin,test.dat$egfr)
#' @export

calcPREVENT.totalCVD <- function(age, sex, tc, hdl, sbp, bptx, smoking, dm, statin, egfr,
                                 female=c(0,"f","female"),male=c(1,"m","male"),
                                 bptx.true=c(1,"t","true","y","yes"), bptx.false=c(0,"f","false","n","no"),
                                 smoking.true=c(1,"t","true","y","yes","active"),
                                 smoking.false=c(0,"f","false","n","no","former","non-smoker","nonsmoker"),
                                 dm.true=c(1,"t","true","y","yes"),dm.false=c(0,"f","false","n","no"),
                                 statin.true=c(1,"t","true","y","yes"),statin.false=c(0,"f","false","n","no")) {

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
  lipidtx <- rep(NA,length(statin))
  lipidtx[sapply(statin,tolower) %in% sapply(statin.true,tolower)] <- 1
  lipidtx[sapply(statin,tolower) %in% sapply(statin.false,tolower)] <- 0

  # Formulas need cholesterol metrics to be in mmol/L
  tc2 <- tc * 0.02586
  hdl2 <- hdl * 0.02586

  # Women
  women <- sapply(sex,tolower) %in% sapply(female,tolower)

  lodds[women] <- -3.307728 + 0.7939329*(age2[women] - 55)/10 + 0.0305239*(tc2[women] - hdl2[women] - 3.5) -
    0.1606857*(hdl2[women] - 1.3)/0.3 - 0.2394003*(pmin(sbp[women], 110) - 110)/20 +
    0.360078*(pmax(sbp[women], 110) - 130)/20 + 0.8667604*(diab[women]) + 0.5360739*(smoke[women]) +
    0.6045917*(pmin(egfr[women], 60) - 60)/-15 + 0.0433769*(pmax(egfr[women], 60) - 90)/-15 +
    0.3151672*(bprx[women]) - 0.1477655*(lipidtx[women]) - 0.0663612*(bprx[women])*(pmax(sbp[women], 110) - 130)/20 +
    0.1197879*(lipidtx[women])*(tc2[women] - hdl2[women] - 3.5) -
    0.0819715*(age2[women] - 55)/10 * (tc2[women] - hdl2[women] - 3.5) +
    0.0306769*(age2[women] - 55)/10 * (hdl2[women] - 1.3)/0.3 -
    0.0946348*(age2[women] - 55)/10 * (pmax(sbp[women], 110) - 130)/20 -
    0.27057*(age2[women] - 55)/10 * (diab[women]) - 0.078715*(age2[women] - 55)/10 * (smoke[women]) -
    0.1637806*(age2[women] - 55) /10 * (pmin(egfr[women], 60) - 60)/-15

  # Men
  men <- sapply(sex,tolower) %in% sapply(male,tolower)

  lodds[men] <- -3.031168 + 0.7688528*(age2[men] - 55)/10 + 0.0736174*(tc2[men] - hdl2[men] - 3.5) -
    0.0954431*(hdl2[men] - 1.3)/0.3 - 0.4347345*(pmin(sbp[men], 110) - 110)/20 +
    0.3362658*(pmax(sbp[men], 110) - 130)/20 + 0.7692857*(diab[men]) + 0.4386871*(smoke[men]) +
    0.5378979*(pmin(egfr[men], 60) - 60)/-15 + 0.0164827*(pmax(egfr[men], 60) - 90)/-15 +
    0.288879*(bprx[men]) - 0.1337349*(lipidtx[men]) - 0.0475924*(bprx[men]) * (pmax(sbp[men], 110) - 130)/20 +
    0.150273*(lipidtx[men]) * (tc2[men] - hdl2[men] - 3.5) -
    0.0517874*(age2[men] - 55)/10 * (tc2[men] - hdl2[men] - 3.5) +
    0.0191169*(age2[men] - 55)/10 * (hdl2[men] - 1.3) /0.3 -
    0.1049477*(age2[men] - 55)/10 * (pmax(sbp[men], 110) - 130)/20 -
    0.2251948*(age2[men] - 55)/10 * (diab[men]) - 0.0895067*(age2[men] - 55)/10 * (smoke[men]) -
    0.1543702*(age2[men] - 55)/10 * (pmin(egfr[men], 60) - 60)/-15

  prevent <- exp(lodds)/(1+exp(lodds))

  return(prevent)
}
