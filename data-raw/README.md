# GLI lookup tables

`build_sysdata.R` turns these CSV files into `R/sysdata.rda`, the internal age-spline tables used by
`predict_FEV1()` and `predict_FVC()` with `method = "lookup"` (the default). Each file has one row
per sex, measure and age (3 to 95 years in steps of 0.25): `Mspline`, `Sspline` and `Lspline`.

| File | Equations | Source |
|---|---|---|
| `gli2012_splines.csv` | GLI-2012 (race-specific) | The official GLI workbook `lookuptables.xls` (Quanjer PH, et al. *Eur Respir J* 2012;40:1324–43), sheets "FEV1 males", "FEV1 females", "FVC males" and "FVC females", copied at full precision. The base coefficients in `R/gli_coefficients.R` match the coefficient blocks in the same sheets, and the tables agree with every value printed in the GLI memo "Implementing GLI 2012 lung function regression equations" (19 July 2015). |
| `gli_global_splines.csv` | GLI Global (race-neutral) | The official GLI workbook `gli_global_lookuptables_dec6.xlsx` (Bowerman C, et al. *Am J Respir Crit Care Med* 2023;207:768–74), copied at full precision. |

Following GLI, values between table ages are found by linear interpolation.
