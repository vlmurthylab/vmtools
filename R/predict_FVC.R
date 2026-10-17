#' Predict FVC based on Global Lungs Initiative
#'
#' This function computes predicted FVC from the ERS Global Lung Initiative function (Eur Resp J 2012 40:1324-43)
#'
#' The GLI-2012 age splines are approximated by fifth-order polynomials in age/100, valid for ages 25-95.
#' These agree with the official GLI-2012 lookup tables to within 0.5\% (see tests/testthat/test-spirometry.R).
#' TODO: cite the published source of the polynomial coefficients.
#'
#' @param age age in years (ages 25-95)
#' @param height height in centimeters
#' @param race GLI-2012 ethnic group, case-insensitive: 0=Caucasian ("c", "caucasian", "w", "white"),
#' 1=African American ("aa", "african-american"), 2=North East Asian ("nea"), 3=South East Asian ("sea")
#' or 4=other/mixed ("o", "other"). Unrecognized values return NA with a warning.
#' @param sex 0=female/1=male
#' @param fvc measured FVC (optional). If provided, Z-score and percent predicted will be computed
#' @return vector of predicted FVC, coefficient of variation, skewness, lower limit normal,
#' Z-score (if fvc is provided), percent predicted FVC (if fvc is provided)
#' @keywords FEV1
#' @examples
#'
#' age <- c(30, 61.5, 53, 39.1)
#' height <- c(180, 152, 175, 165)
#' race <- c("caucasian", "aa", "SEA", "o")
#' sex <- c("M", "M", "M", "F")
#' fvc <- c(4.1, 2.405, 2.410, 2.210)
#'
#' predict_FVC(age, height, race, sex, fvc)
#'
#' @export

predict_FVC <- function(age, height, race, sex, fvc=NA) {

  # Make sure length of all variables are equal
  stopifnot(all(sapply(list(age, height, race), function(x) length(x) == length(sex))))
  stopifnot(all(is.na(fvc)) | (length(fvc)==length(age)))

  # Check if age is in the right range
  age <- ifelse(age <25 | age >95, NA, age)
  female <- ifelse(tolower(as.character(sex)) %in% c("0","f","female"),TRUE,FALSE)

  # Ethnic group; Caucasian is the GLI reference group (all indicators 0)
  race_key <- tolower(as.character(race))
  known_race <- race_key %in% c("0","c","caucasian","w","white","1","aa","african-american",
                                "2","nea","n east asian","3","sea","s east asian","4","o","other")
  if (any(!known_race & !is.na(race))) warning("Unrecognized race values set to NA: ",
                                               paste(unique(race[!known_race & !is.na(race)]), collapse=", "))
  age[!known_race] <- NA

  # Set up matrix of x-variables
  x_mat <- data.frame(intercept=1,
                      ln_height=log(height),
                      ln_age=log(age),
                      aa=ifelse(tolower(as.character(race)) %in% c("1","aa","african-american"),1,0),
                      nea=ifelse(tolower(as.character(race)) %in% c("2","nea","n east asian"),1,0),
                      sea=ifelse(tolower(as.character(race)) %in% c("3","sea","s east asian"),1,0),
                      o=ifelse(tolower(as.character(race)) %in% c("4","o","other"),1,0),
                      age.ge.25=ifelse(age>=25,1,0),
                      spline.age1=ifelse(age>=25,age/100,0),
                      spline.age2=ifelse(age>=25,(age/100)^2,0),
                      spline.age3=ifelse(age>=25,(age/100)^3,0),
                      spline.age4=ifelse(age>=25,(age/100)^4,0),
                      spline.age5=ifelse(age>=25,(age/100)^5,0)) |> as.matrix()

  # Set up matrix for M coefficients
  m_coef_mat <- data.frame(intercept=ifelse(female,-10.4030,-11.2281),
                           ln_height=ifelse(female,2.2633,2.4135),
                           ln_age=ifelse(female,0.0234,0.0865),
                           aa=ifelse(female,-0.1555,-0.1684),
                           nea=ifelse(female,-0.0262,-0.0405),
                           sea=ifelse(female,-0.1516,-0.1177),
                           o=ifelse(female,-0.0833,-0.0825),
                           age.ge.25=ifelse(female,0.0745,0.3298),
                           spline.age1=ifelse(female,0.6006,-1.1230),
                           spline.age2=ifelse(female,-1.0684,2.8110),
                           spline.age3=ifelse(female,-1.1308,-5.4811),
                           spline.age4=ifelse(female,0.9730,3.5964),
                           spline.age5=ifelse(female,0.0643,-0.5884)) |> as.matrix()

  # Set up matrix for S coefficients
  s_coef_mat <- data.frame(intercept=ifelse(female,-2.3549,-2.2963),
                           ln_height=ifelse(female,0,0),
                           ln_age=ifelse(female,0.1017,0.0718),
                           aa=ifelse(female,0.0810,0.0794),
                           nea=ifelse(female,-0.1809,-0.4600),
                           sea=ifelse(female,0.0459,0.0325),
                           o=ifelse(female,-0.0503,-0.0503),
                           age.ge.25=ifelse(female,-0.2301,-0.0645),
                           spline.age1=ifelse(female,3.7699,0.2070),
                           spline.age2=ifelse(female,-22.4318,-3.0606),
                           spline.age3=ifelse(female,51.8219,10.3907),
                           spline.age4=ifelse(female,-49.7845,-11.1003),
                           spline.age5=ifelse(female,17.2894,3.9633)) |> as.matrix()

  # Set up matrix for L coefficients
  l_coef_mat <- data.frame(intercept=ifelse(female,0.8236,0.9481),
                           ln_height=ifelse(female,0,0),
                           ln_age=ifelse(female,0,0),
                           aa=ifelse(female,0,0),
                           nea=ifelse(female,0,0),
                           sea=ifelse(female,0,0),
                           o=ifelse(female,0,0),
                           age.ge.25=ifelse(female,0,0),
                           spline.age1=ifelse(female,0,0),
                           spline.age2=ifelse(female,0,0),
                           spline.age3=ifelse(female,0,0),
                           spline.age4=ifelse(female,0,0),
                           spline.age5=ifelse(female,0,0))

  # Compute M, S, L, LLN, percent predicted, Z-score
  M <- exp(rowSums(x_mat * m_coef_mat))
  S <- exp(rowSums(x_mat * s_coef_mat))
  L <- rowSums(x_mat * l_coef_mat)
  LLN <- exp(log(1-1.644*L*S)/L + log(M))
  pct_pred <- (fvc/M) * 100
  Z <-((fvc/M)^L -1)/(L*S)

  # Data frame for return
  data.frame(fvc_pred=M, cv=S, skew=L, fvc_lln=LLN, fvc_pct_pred=pct_pred, fvc_Z=Z)
}
