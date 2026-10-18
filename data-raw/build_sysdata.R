# Builds R/sysdata.rda (the internal GLI age-spline lookup tables) from the CSV files in this folder.
# Run from the package root:  Rscript data-raw/build_sysdata.R
#
# Sources (see data-raw/README.md):
#   gli2012_splines.csv     GLI-2012 lookup tables for FEV1 and FVC (Quanjer PH, et al. Eur Respir J 2012).
#   gli_global_splines.csv  GLI Global lookup tables for FEV1 and FVC, from the official GLI workbook
#                           gli_global_lookuptables_dec6.xlsx (Bowerman C, et al. Am J Respir Crit Care Med 2023).

read_tables <- function(file, version) {
  d <- read.csv(file.path("data-raw", file))
  stopifnot(all(d$Lspline == 0))                     # L has no age spline for FEV1 and FVC
  out <- list()
  for (key in unique(paste(d$param, d$sex, sep = "."))) {
    t <- d[paste(d$param, d$sex, sep = ".") == key, ]
    t <- t[order(t$age), c("age", "Mspline", "Sspline")]
    stopifnot(isTRUE(all.equal(diff(t$age), rep(0.25, nrow(t) - 1))), min(t$age) == 3, max(t$age) == 95)
    rownames(t) <- NULL
    out[[paste(version, key, sep = ".")]] <- t
  }
  out
}

.gli_tables <- c(read_tables("gli2012_splines.csv", "GLI-2012"),
                 read_tables("gli_global_splines.csv", "GLI-Global"))
save(.gli_tables, file = "R/sysdata.rda", compress = "xz")
