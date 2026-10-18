# Shared engine for the GLI spirometry predictions. Coefficients are in gli_coefficients.R.

.gli_equations <- c("GLI-2012", "GLI-Global", "auto")

.gli_race_groups <- list(
  Caucasian = c("0", "c", "caucasian", "w", "white"),
  `African American` = c("1", "aa", "african-american", "african american", "black"),
  `North East Asian` = c("2", "nea", "n east asian", "north east asian"),
  `South East Asian` = c("3", "sea", "s east asian", "south east asian"),
  `Other/mixed` = c("4", "o", "other", "mixed")
)
.gli_race_unknown <- c("unknown", "u", "")

.gli_methods <- c("lookup", "polynomial")

# Age spline (Mspline, Sspline) at one age, by linear interpolation in the official
# lookup table (GLI's method) or from the fitted polynomials in gli_coefficients.R
.gli_splines <- function(key, age, method, cf) {
  if (method == "lookup") {
    t <- .gli_tables[[key]]
    i <- min(floor((age - 3) * 4) + 1, nrow(t) - 1)        # row at or below age (ages 3-95, step 0.25)
    w <- (age - t$age[i]) / 0.25
    return(c(t$Mspline[i] + w * (t$Mspline[i + 1] - t$Mspline[i]),
             t$Sspline[i] + w * (t$Sspline[i + 1] - t$Sspline[i])))
  }
  piece <- if (age < 12) 1 else if (age < 25) 2 else 3
  x <- (age / 100)^(0:5)
  c(sum(cf$Mspline[piece, ] * x), sum(cf$Sspline[piece, ] * x))
}

.gli_predict <- function(param, age, height, race, sex, measured, equations, method = "lookup") {
  equations <- match.arg(equations, .gli_equations)
  method <- match.arg(method, .gli_methods)
  n <- length(age)
  if (is.null(race)) race <- rep(NA, n)
  args <- list(height = height, race = race, sex = sex, measured = measured)
  for (nm in names(args)) {
    if (length(args[[nm]]) == 1) args[[nm]] <- rep(args[[nm]], n)
    if (length(args[[nm]]) != n) stop("age, height, race, sex and ", tolower(param),
                                      " must have the same length (or length 1)")
  }

  sex_key <- tolower(as.character(args$sex))
  sex_lab <- ifelse(sex_key %in% c("0", "f", "female"), "female",
                    ifelse(sex_key %in% c("1", "m", "male"), "male", NA))

  race_key <- tolower(trimws(as.character(args$race)))
  group <- rep(NA_character_, n)
  for (g in names(.gli_race_groups)) group[race_key %in% .gli_race_groups[[g]]] <- g
  unknown <- is.na(race_key) | race_key %in% .gli_race_unknown
  unrecognized <- !unknown & is.na(group)

  # Which equations each row uses
  eq <- switch(equations,
               "GLI-2012" = rep("GLI-2012", n),
               "GLI-Global" = rep("GLI-Global", n),
               "auto" = ifelse(unknown, "GLI-Global", "GLI-2012"))
  if (equations == "GLI-Global" && any(!unknown))
    warning("race is ignored with equations = \"GLI-Global\" (race-neutral)")
  if (equations != "GLI-Global" && any(unrecognized))
    warning("Unrecognized race values set to NA: ", paste(unique(args$race[unrecognized]), collapse = ", "))
  if (equations == "GLI-2012" && any(unknown))
    warning("Missing or unknown race gives NA with equations = \"GLI-2012\"; ",
            "use race = \"other\" (GLI-2012 Other/mixed), equations = \"GLI-Global\", or equations = \"auto\"")

  usable <- !is.na(age) & age >= 3 & age <= 95 & !is.na(sex_lab) & !is.na(args$height) &
    (eq == "GLI-Global" | !is.na(group))
  M <- S <- L <- rep(NA_real_, n)
  for (i in which(usable)) {
    key <- paste(eq[i], param, sex_lab[i], sep = ".")
    cf <- .gli_coef[[key]]
    spl <- .gli_splines(key, age[i], method, cf)
    eth <- match(group[i], names(.gli_race_groups)) - 1          # 0 = Caucasian
    a_eth <- if (eq[i] == "GLI-2012" && eth > 0) cf$a[3 + eth] else 0
    p_eth <- if (eq[i] == "GLI-2012" && eth > 0) cf$p[2 + eth] else 0
    M[i] <- exp(cf$a[1] + cf$a[2] * log(args$height[i]) + cf$a[3] * log(age[i]) + a_eth + spl[1])
    S[i] <- exp(cf$p[1] + cf$p[2] * log(age[i]) + p_eth + spl[2])
    L[i] <- cf$q[1] + cf$q[2] * log(age[i])
  }

  label <- ifelse(eq == "GLI-Global", "GLI-Global", paste0("GLI-2012 (", group, ")"))
  label[!usable] <- NA
  LLN <- exp(log(1 - 1.645 * L * S) / L + log(M))
  pct_pred <- (args$measured / M) * 100
  Z <- ((args$measured / M)^L - 1) / (L * S)
  out <- data.frame(M, S, L, LLN, pct_pred, Z, label, stringsAsFactors = FALSE)
  m <- tolower(param)
  names(out) <- c(paste0(m, "_pred"), "cv", "skew", paste0(m, "_lln"), paste0(m, "_pct_pred"), paste0(m, "_Z"), "equations")
  out
}
