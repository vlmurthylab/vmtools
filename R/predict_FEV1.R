#' Predict FEV1 based on Global Lungs Initiative
#'
#' This function computes predicted FEV1 from the ERS Global Lung Initiative function (Eur Resp J 2012 40:1324-43)
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
#' @param fev1 measured FEV1 (optional). If provided, Z-score and percent predicted will be computed
#' @return vector of predicted FEV1, coefficient of variation, skewness, lower limit normal,
#' Z-score (if fev1 is provided), percent predicted FEV1 (if fev1 is provided)
#' @keywords FEV1
#' @examples
#'
#' age <- c(30, 61.5, 53, 39.1)
#' height <- c(180, 152, 175, 165)
#' race <- c("caucasian", "aa", "SEA", "o")
#' sex <- c("M", "M", "M", "F")
#' fev1 <- c(4.1, 2.405, 2.410, 2.210)
#'
#' predict_FEV1(age, height, race, sex, fev1)
#'
#' @export


predict_FEV1 <- function(age, height, race, sex, fev1=NA) {

  # Make sure length of all variables are equal
  stopifnot(all(sapply(list(age, height, race), function(x) length(x) == length(sex))))
  stopifnot(all(is.na(fev1)) | (length(fev1)==length(age)))

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
  m_coef_mat <- data.frame(intercept=ifelse(female,-9.6987,-10.3420),
                           ln_height=ifelse(female,2.1211,2.2196),
                           ln_age=ifelse(female,-0.0270,0.0574),
                           aa=ifelse(female,-0.1484,-0.1589),
                           nea=ifelse(female,-0.0149,-0.0351),
                           sea=ifelse(female,-0.1208,-0.0881),
                           o=ifelse(female,-0.0708,-0.0708),
                           age.ge.25=ifelse(female,0.0552,0.3901),
                           spline.age1=ifelse(female,1.6032,-1.0579),
                           spline.age2=ifelse(female,-6.4855,1.4743),
                           spline.age3=ifelse(female,10.2741,-2.1077),
                           spline.age4=ifelse(female,-9.8646,-0.1215),
                           spline.age5=ifelse(female,3.8808,0.8873)) |> as.matrix()

  # Set up matrix for S coefficients
  s_coef_mat <- data.frame(intercept=ifelse(female,-2.3765,-2.3268),
                           ln_height=ifelse(female,0,0),
                           ln_age=ifelse(female,0.0972,0.0798),
                           aa=ifelse(female,0.1016,0.1096),
                           nea=ifelse(female,-0.0109,-0.3973),
                           sea=ifelse(female,0.0733,0.0327),
                           o=ifelse(female,0.0114,0.0114),
                           age.ge.25=ifelse(female,-0.0825,-1.6902),
                           spline.age1=ifelse(female,1.4104,17.0986),
                           spline.age2=ifelse(female,-11.2699,-68.1649),
                           spline.age3=ifelse(female,29.4400,127.1964),
                           spline.age4=ifelse(female,-29.5505,-109.6777),
                           spline.age5=ifelse(female,10.4405,35.6832)) |> as.matrix()

  # Set up matrix for L coefficients
  l_coef_mat <- data.frame(intercept=ifelse(female,1.1540,0.8866),
                           ln_height=ifelse(female,0,0),
                           ln_age=ifelse(female,0,0.0850),
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
  pct_pred <- (fev1/M) * 100
  Z <-((fev1/M)^L -1)/(L*S)

  # Data frame for return
  data.frame(fev1_pred=M, cv=S, skew=L, fev1_lln=LLN, fev1_pct_pred=pct_pred, fev1_Z=Z)
}
