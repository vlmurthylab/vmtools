# vmtools

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23440811.svg)](https://doi.org/10.5281/zenodo.23440811)

R helpers for cardiovascular epidemiology from the [Murthy Lab](https://murthylab.org) at the University of Michigan.

## Installation

```r
# install.packages("remotes")
remotes::install_github("vlmurthylab/vmtools")
```

## What's included

| Area | Functions | Reference |
|---|---|---|
| Cardiovascular risk | `calcPREVENT.totalCVD()`, `calcPREVENT.ASCVD()`, `calcPREVENT.HF()` | Khan SS, et al. *Circulation* 2024;149:430–49 ([doi:10.1161/CIRCULATIONAHA.123.067626](https://doi.org/10.1161/CIRCULATIONAHA.123.067626)) |
| | `calcPCE()` (Pooled Cohort Equations) | Goff DC, et al. *Circulation* 2014;129:S49–73 ([doi:10.1161/01.cir.0000437741.48606.98](https://doi.org/10.1161/01.cir.0000437741.48606.98)) |
| Insulin resistance and sensitivity | `calcHOMA.IR()`, `calcHOMA.beta()` | Matthews DR, et al. *Diabetologia* 1985;28:412–9 |
| | `calcQUICKI()` | Katz A, et al. *J Clin Endocrinol Metab* 2000;85:2402–10 |
| | `calcMatsuda.ISI()` | Matsuda M, DeFronzo RA. *Diabetes Care* 1999;22:1462–70 |
| | `calcAvignon.SI()` | Avignon A, et al. *Int J Obes* 1999;23:512–7 |
| Spirometry | `predict_FEV1()`, `predict_FVC()` (GLI-2012, ages 25–95) | Quanjer PH, et al. *Eur Respir J* 2012;40:1324–43 |
| Metabolomics | `HMDB_ID_from_name()`, `HMDB_ID_from_ID()` | [Human Metabolome Database](https://hmdb.ca) |
| Utilities | `format.pval()`, `get_labels()`, `mqsave()`, `mqread()` | |

All risk and index functions are vectorized, so they work directly on data frame columns.

## Examples

```r
library(vmtools)

# PREVENT 10-year risk: 50-year-old woman, TC 200, HDL 45, SBP 160 on treatment,
# diabetes, non-smoker, no statin, eGFR 90
calcPREVENT.totalCVD(age = 50, sex = "female", tc = 200, hdl = 45, sbp = 160,
                     bptx = 1, smoking = 0, dm = 1, statin = 0, egfr = 90)
#> 0.147

# Pooled Cohort Equations: 55-year-old white man, TC 213, HDL 50, SBP 120 untreated
calcPCE(age = 55, race = "white", sex = "male", tc = 213, hdl = 50, sbp = 120,
        bptx = 0, smoking = 0, dm = 0)

# GLI-2012 predicted FEV1 with z-score and percent predicted
predict_FEV1(age = 40, height = 175, race = "caucasian", sex = "M", fev1 = 3.6)

# Insulin resistance from fasting insulin (uU/mL) and glucose (mg/dL)
calcHOMA.IR(insulin = 10, glucose = 100)
```

## Notes

- **Units.** Cholesterol and glucose are in mg/dL, insulin in uU/mL, height in cm, weight in kg.
- **Coded inputs.** Sex, race, treatment and smoking accept numeric codes or case-insensitive labels (for example `0`, `"f"` or `"female"`). Unrecognized values return `NA`. See each function's help page for the accepted labels.
- **Age ranges.** PREVENT clamps age to 30–79 and PCE to 40–79, the ranges the equations were derived in. The GLI functions return `NA` outside ages 25–95.
- **GLI equations.** The age splines from the official GLI-2012 lookup tables are approximated with polynomials, which agree with the tables to within 0.5% for ages 25–95.
- **HMDB lookups** query the HMDB website, so they need internet access and may break if HMDB changes its pages.

## Validation

The test suite in `tests/testthat` checks the PCE against the worked example in Goff 2013 (Table A), the PREVENT equations against the reference values in the [preventr](https://github.com/martingmayer/preventr) package's test suite, and the spirometry functions against the official GLI-2012 lookup tables.

## Citation

vmtools is archived on Zenodo. To cite a specific version, use its DOI (v0.1.0: [10.5281/zenodo.23440812](https://doi.org/10.5281/zenodo.23440812)); [10.5281/zenodo.23440811](https://doi.org/10.5281/zenodo.23440811) always resolves to the latest version. See [`CITATION.cff`](CITATION.cff), or use GitHub's "Cite this repository" button.

## License

GPL-3
