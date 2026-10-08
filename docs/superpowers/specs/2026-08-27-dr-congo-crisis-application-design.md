# DR Congo crisis application design

## Scope

Apply the prepared under-five crisis deaths in
`Data/Crisis_Adjustment/crisis_COD.rda` to the selected benchmarked DR Congo
U5MR results at Admin-1 and Admin-2. Preserve the non-crisis inputs and write
new `_crisis.rda` outputs. NMR is not changed.

This is a deterministic post-processing stage. It does not refit or rebenchmark
the model and it does not alter the active 71/29 allocation prepared upstream
by `Data/Crisis_Adjustment/prepare_cod_71_29.R`.

## Selected approach

Each crisis output will contain both:

1. the full benchmarked model object, with crisis increments applied to summary
   estimates and saved estimated draws; and
2. the legacy-compatible `res_adm1_u5_crisis` or `res_adm2_u5_crisis` table
   expected by `Rcode/11_Report_Plot.R`.

This is preferred to a table-only output because it preserves posterior draws
for downstream aggregation. It is preferred to overwriting the benchmarked
file because the change remains reversible. A third possible approach—changing
shared report loaders to introduce a new object contract—is unnecessary for
this country-specific application.

## Country metadata and loading rule

`Info/DR_Congo_general_info.json` will contain the Boolean field
`"doCrisisAdj": true`. A missing field or `false` means that downstream code
must load the ordinary model even when a `_crisis.rda` file happens to exist.
When the field is `true`, the selected benchmarked Admin-1 and Admin-2 U5MR
loads must resolve to `_crisis.rda`; absence of that file is a blocking error.

The selection rule will be implemented once in `project_paths.R` and used by
both `11_Report_Plot.R` and `11_CountrySummary.Rmd`. NMR, national models, and
unbenchmarked comparison models remain unchanged.

## Inputs

- `Data/Crisis_Adjustment/crisis_COD.rda`
  - `df_COD`
  - `cod_crisis_allocation_audit`
  - `cod_crisis_allocation_metadata`
- `Results/DR_Congo/Betabinomial/U5MR/DR_Congo_res_adm1_unstrat_u5_allsurveys_bench.rda`
- `Results/DR_Congo/Betabinomial/U5MR/DR_Congo_res_adm2_unstrat_u5_allsurveys_bench.rda`

The application uses the area population denominators stored in the allocation
audit. These are the exact denominators used when preparing the crisis-death
distribution and avoid a second, potentially drifting reconstruction.

## Mortality conversion

For each area and year with crisis deaths:

```text
m0  = deaths age 0 / population age 0
m14 = deaths ages 1-4 / population ages 1-4
q1  = m0 / (1 + 0.7 * m0)
q4  = 4 * m14 / (1 + 2.4 * m14)
crisis_5q0 = 1 - (1 - q1) * (1 - q4)
```

The constants reproduce the established crisis-adjustment conversion in the
archived application code. `crisis_5q0` is added to the non-crisis U5MR. The
script stops if any input or adjusted probability is non-finite, negative, or
greater than or equal to one.

## Model-object update

For affected region-years, add the deterministic crisis increment to:

- `overall`: `median`, `mean`, `lower`, and `upper`
- `stratified`: `median`, `mean`, `lower`, and `upper`
- every vector in `draws.est.overall`
- every vector in `draws.est`

Variance remains unchanged because adding a fixed quantity does not change
variance. Raw latent model draws remain unchanged because the crisis component
is post-processing, not a refit. Unaffected years must be byte-equivalent at the
numeric-field level.

## Outputs

- `DR_Congo_res_adm1_unstrat_u5_allsurveys_bench_crisis.rda`
- `DR_Congo_res_adm2_unstrat_u5_allsurveys_bench_crisis.rda`

Each file contains the adjusted full model under its original model object name,
the report-compatible crisis table, an area/year crisis-qx audit, and application
metadata with input hashes and generation time. Existing output files are not
overwritten unless the function receives explicit `overwrite = TRUE`.

## Validation

Automated checks cover the conversion formula, exact deterministic shifts in
summary tables and both estimated-draw lists, unchanged non-crisis years,
one-to-one region/year matching, bounds below one, report-compatible object
names, preservation of base-file hashes, and real Admin-1/Admin-2 integration.
They also verify that crisis files are selected only when `doCrisisAdj` is true,
that an enabled-but-missing crisis file fails clearly, and that DR Congo opts in
through its JSON metadata.

The application stage stops after producing and validating the crisis model
files. Regenerating plots and `11_CountrySummary.pdf` is the following pipeline
stage because those operations replace existing report artifacts and require a
separate pre-run inventory and rollback copy.
