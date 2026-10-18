# vmtools 0.1.0.9000 (development version)

## GLI spirometry equations

* **Important: the default equations may change.** `predict_FEV1()` and `predict_FVC()` now have an
  `equations` argument. The default, `"GLI-2012"` (race-specific), is kept so existing code keeps
  working, but **it may change to `"GLI-Global"` (race-neutral) in a future major version.**
  Set `equations` explicitly in all new analyses.
* New race-neutral GLI Global equations (Bowerman et al. 2023): `equations = "GLI-Global"`, or the
  shortcuts `predict_FEV1_gliglobal()` and `predict_FVC_gliglobal()`. The shortcuts
  `predict_FEV1_gli2012()` and `predict_FVC_gli2012()` always use GLI-2012, whatever the default.
* New `equations = "auto"`: GLI-2012 where race is known, GLI Global where race is missing or
  "unknown". Each row of the result records the equations used in a new `equations` column.
* Ages 3–95 are now supported (previously 25–95).
* New `method` argument. The default, `"lookup"`, uses GLI's official age-spline lookup tables
  with linear interpolation, so results are exact GLI values. `"polynomial"` uses closed-form
  formulas (three smoothly joined fifth-order polynomials in age/100, fitted to the official tables;
  within 0.1% on average and 0.45% at worst) for reproducing the calculation in other software.
* GLI-2012 results for adults change slightly (typically by less than 0.1%): the default now uses
  the official tables instead of the previous adult polynomial approximations.
* `race` is now optional, sex values other than female/male give `NA` (previously treated as male),
  inputs of length 1 are recycled, and the LLN uses z = 1.645 (previously 1.644).
