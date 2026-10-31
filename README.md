# vmtools

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23440811.svg)](https://doi.org/10.5281/zenodo.23440811)

R helpers for cardiometabolic epidemiology from the [Murthy Lab](https://murthylab.org) at the University of Michigan.

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
| Spirometry | `predict_FEV1()`, `predict_FVC()`: GLI-2012 (race-specific) or GLI Global (race-neutral), ages 3–95 | Quanjer PH, et al. *Eur Respir J* 2012;40:1324–43; Bowerman C, et al. *Am J Respir Crit Care Med* 2023;207:768–74 ([doi:10.1164/rccm.202205-0963OC](https://doi.org/10.1164/rccm.202205-0963OC)) |
| | `predict_FEV1_gli2012()`, `predict_FVC_gli2012()`, `predict_FEV1_gliglobal()`, `predict_FVC_gliglobal()`: shortcuts that always use one set of equations | |
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

# GLI predicted FEV1 with z-score and percent predicted; always state the equations
predict_FEV1(age = 40, height = 175, race = "caucasian", sex = "M", fev1 = 3.6, equations = "GLI-2012")
predict_FEV1(age = 40, height = 175, sex = "M", fev1 = 3.6, equations = "GLI-Global")   # race-neutral

# Insulin resistance from fasting insulin (uU/mL) and glucose (mg/dL)
calcHOMA.IR(insulin = 10, glucose = 100)
```

## Notes

- **Units.** Cholesterol and glucose are in mg/dL, insulin in uU/mL, height in cm, weight in kg.
- **Coded inputs.** Sex, race, treatment and smoking accept numeric codes or case-insensitive labels (for example `0`, `"f"` or `"female"`). Unrecognized values return `NA`. See each function's help page for the accepted labels.
- **Age ranges.** PREVENT clamps age to 30–79 and PCE to 40–79, the ranges the equations were derived in. The GLI functions return `NA` outside ages 3–95.
- **GLI equations: the default may change.** `predict_FEV1()` and `predict_FVC()` take `equations = "GLI-2012"` (race-specific, **the current default**), `"GLI-Global"` (race-neutral) or `"auto"` (GLI-2012 where race is known, GLI Global where it is not). **The default is kept for backward compatibility and may change to `"GLI-Global"` in a future major version. Always set `equations` explicitly in new analyses.** Every result includes an `equations` column naming what was used.
- **GLI methods.** By default (`method = "lookup"`) the GLI functions use GLI's official age-spline lookup tables with linear interpolation, giving exact GLI values. `method = "polynomial"` instead uses closed-form formulas (three smoothly joined fifth-order polynomials in age/100 for ages 3–12, 12–25 and 25–95, fitted to the official tables), handy for reproducing the calculation in other software; they agree with the tables to within 0.1% on average and 0.45% at worst. The sources of the tables are documented in `data-raw/`.
- **HMDB lookups** query the HMDB website, so they need internet access and may break if HMDB changes its pages.

## Validation

The test suite in `tests/testthat` checks the PCE against the worked example in Goff 2013 (Table A), the PREVENT equations against the reference values in the [preventr](https://github.com/martingmayer/preventr) package's test suite, and the spirometry functions against the official GLI-2012 and GLI Global lookup tables and the worked examples in the GLI implementation memo (2015).

## Citation

vmtools is archived on Zenodo. To cite a specific version, use its DOI (v0.2.0: [10.5281/zenodo.23445404](https://doi.org/10.5281/zenodo.23445404); v0.1.0: [10.5281/zenodo.23440812](https://doi.org/10.5281/zenodo.23440812)); [10.5281/zenodo.23440811](https://doi.org/10.5281/zenodo.23440811) always resolves to the latest version. See [`CITATION.cff`](CITATION.cff), or use GitHub's "Cite this repository" button.

## License

vmtools is licensed under the GNU General Public License, version 3 only (GPL-3.0-only). See [`LICENSE`](LICENSE).

## Contributing

This repository uses the lab's shared safeguards (from vlmurthylab/project-template): a `.gitignore`
that keeps data out, a PHI check that runs before each commit and on GitHub, and the rules for AI
assistants in [`AGENTS.md`](AGENTS.md). Turn the check on once in each clone, from the repository
folder: `git config core.hooksPath hooks` (or, in R, `source("tools/install_hooks.R")`).

Never put study data here, not in code, tests, examples or issues, even de-identified: tests use
published reference values or made-up inputs. The lab-core files (`hooks/`, `tools/`, `AGENTS.md`,
`CLAUDE.md`, `.gitattributes`, the top of `.gitignore`, `.github/`) are maintained in the template;
`phi-guard.conf` and the bottom sections of `.gitignore` and `AGENTS.md` are this repository's own.

