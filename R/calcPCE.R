#' Calculate Pooled Cohorts Equations risk scores
#'
#' This function calculates Pooled Cohorts Equations risk scores per prior ACC/AHA recommendations.
#' Reference: Goff DC, et al. Circulation 2014;129:S49-S73
#' DOI: 10.1161/01.cir.0000437741.48606.98
#' @param age age in years
#' @param race white (non-black) vs. black
#' @param sex 0=female/1=male
#' @param tc total cholesterol in mg/dl
#' @param hdl HDL cholesterol in mg/dl
#' @param sbp Systolic blood pressure in mmHg
#' @param bptx treatment for blood pressure 0=FALSE/1=TRUE
#' @param smoking active smoking 0=FALSE/1=TRUE
#' @param dm diabetes mellitus 0=FALSE/1=TRUE
#' @param white values which indicate white/non-black the parameter race, case-insensitive (default=0,"w","white")
#' @param black values which indicate blacks in the parameter race, case-insensitive (default=1,"b","black")
#' @param female values which indicate female in the parameter sex, case-insensitive (default=0,"f","female")
#' @param male values which indicate male in the parameter sex, case-insensitive (default=1,"m","male")
#' @param bptx.true values which indicate BP med use, case-insensitive (default=1,"t","true","y","yes")
#' @param bptx.false values which indicate no BP med use, case-insensitive (default=0,"f","false","n","no")
#' @param smoking.true values which indicate active smoking, case-insensitive (default=1,"t","true","y","yes","active")
#' @param smoking.false values which indicate no active smoking, case-insensitive (default=0,"f","false","n","no","former","non-smoker","nonsmoker")
#' @param dm.true values which indicate diabetes, case-insensitive (default=1,"t","true","y","yes")
#' @param dm.false values which indicate no diabetes, case-insensitive (default=0,"f","false","n","no")
#' @return PCE risk as numeric from 0 to 1
#' @keywords PCE
#' @examples
#' calcPCE(55,0,0,213,50,120,0,0,0)
#' calcPCE(55,1,0,213,50,120,0,0,0)
#' calcPCE(55,0,1,213,50,120,0,0,0)
#' calcPCE(55,1,1,213,50,120,0,0,0)
#'
#'
#' test.dat <- data.frame(age=rep(56:65,4),race=c(rep(0,10),rep(1,10),rep(0,10),rep(1,10)),
#'                        sex=c(rep(0,20),rep(1,20)),tc=rep(136:145,4),hdl=rep(46:55,4),sbp=rep(126:135,4),
#'                        bptx=rep(c(rep(0,5),rep(1,5)),4),smoking=rep(c(rep(0,5),rep("active",5)),4),
#'                        dm=rep(c(rep("No",5),rep(1,5)),4))
#'
#' test.dat$PCE <- calcPCE(test.dat$age,test.dat$race,test.dat$sex,test.dat$tc,test.dat$hdl,test.dat$sbp,
#'                         test.dat$bptx,test.dat$smoking,test.dat$dm)
#' @export

calcPCE <- function(age, race, sex, tc, hdl, sbp, bptx, smoking, dm, white=c(0,"w","white"),
                    black=c(1,"b","black"), female=c(0,"f","female"),male=c(1,"m","male"),
                    bptx.true=c(1,"t","true","y","yes"), bptx.false=c(0,"f","false","n","no"),
                    smoking.true=c(1,"t","true","y","yes","active"),
                    smoking.false=c(0,"f","false","n","no","former","non-smoker","nonsmoker"),
                    dm.true=c(1,"t","true","y","yes"),dm.false=c(0,"f","false","n","no")) {


  # Initialize vectors
  pce <- rep(NA,length(age))

  age2 <- age
  age2[age2>79] <- 79
  age2[age2<40] <- 40

  bprx <- rep(NA,length(bptx))
  bprx[sapply(bptx,tolower) %in% sapply(bptx.true,tolower)] <- 1
  bprx[sapply(bptx,tolower) %in% sapply(bptx.false,tolower)] <- 0
  smoke <- rep(NA,length(smoking))
  smoke[sapply(smoking,tolower) %in% sapply(smoking.true,tolower)] <- 1
  smoke[sapply(smoking,tolower) %in% sapply(smoking.false,tolower)] <- 0
  diab <- rep(NA,length(dm))
  diab[sapply(dm,tolower) %in% sapply(dm.true,tolower)] <- 1
  diab[sapply(dm,tolower) %in% sapply(dm.false,tolower)] <- 0

  # White women
  ww <- (sapply(sex,tolower) %in% sapply(female,tolower)) & (sapply(race,tolower) %in% sapply(white,tolower))
  pce[ww] <- 29.18 +
    (-29.799 * log(age2[ww])) + (4.884 * log(age2[ww])^2) +
    (13.540 * log(tc[ww])) + (-3.114 * log(age2[ww]) * log(tc[ww])) + (-13.578 * log(hdl[ww])) +
    (3.149 * log(age2[ww]) * log(hdl[ww])) + (2.019 * log(sbp[ww]) * bprx[ww]) +
    (1.957 * log(sbp[ww]) * as.numeric(bprx[ww]==0)) + (7.574 * smoke[ww]) +
    (-1.665 * log(age2[ww]) * smoke[ww]) + (0.661 * diab[ww])

  # Black women
  bw <- (sapply(sex,tolower) %in% sapply(female,tolower)) & (sapply(race,tolower) %in% sapply(black,tolower))
  pce[bw] <- -86.61 +
    (17.114 * log(age2[bw])) + (0.940 * log(tc[bw])) + (-18.920 * log(hdl[bw])) +
    (4.475 * log(age2[bw]) * log(hdl[bw])) + (29.291 * log(sbp[bw]) * bprx[bw]) +
    (-6.432 * log(age2[bw]) * log(sbp[bw]) * bprx[bw]) +
    (27.820 * log(sbp[bw]) * as.numeric(bprx[bw]==0)) +
    (-6.087 * log(age2[bw]) * log(sbp[bw]) * as.numeric(bprx[bw]==0)) +
    (0.691 * smoke[bw]) + (0.874 * diab[bw])

  # White men
  wm <- (sapply(sex,tolower) %in% sapply(male,tolower)) & (sapply(race,tolower) %in% sapply(white,tolower))
  pce[wm] <- -61.18 +
    (12.344 * log(age2[wm])) + (11.853 * log(tc[wm])) + (-2.664 * log(age2[wm]) * log(tc[wm])) +
    (-7.990 * log(hdl[wm])) + (1.769 * log(age2[wm]) * log(hdl[wm])) + (1.797 * log(sbp[wm]) * bprx[wm]) +
    (1.764 * log(sbp[wm]) * as.numeric(bprx[wm]==0)) + (7.837 * smoke[wm]) +
    (-1.795 * log(age2[wm]) * smoke[wm]) + (0.658 * diab[wm])

  # Black men
  bm <- (sapply(sex,tolower) %in% sapply(male,tolower)) & (sapply(race,tolower) %in% sapply(black,tolower))
  pce[bm] <- -19.54 +
    (2.469 * log(age2[bm])) + (0.302 * log(tc[bm])) +
    (-0.307 * log(hdl[bm])) + (1.916 * log(sbp[bm]) * bprx[bm]) +
    (1.809 * log(sbp[bm]) * as.numeric(bprx[bm]==0)) + (0.549 * smoke[bm]) +
    (0.645 * diab[bm])

  pce <- exp(pce)
  pce[ww] <- 1 - 0.9665 ^ pce[ww]
  pce[bw] <- 1 - 0.9533 ^ pce[bw]
  pce[wm] <- 1 - 0.9144 ^ pce[wm]
  pce[bm] <- 1 - 0.8954 ^ pce[bm]

  return(pce)
}
