# DR Congo Crisis Application Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply prepared COD crisis deaths to benchmarked Admin-1 and Admin-2 U5MR summaries and estimated draws without overwriting the non-crisis model files.

**Architecture:** A standalone R script exposes pure mortality-conversion and model-update functions plus an integration entry point. The entry point loads the self-contained crisis audit and current selected model files, writes report-compatible `_crisis.rda` artifacts, and embeds an audit trail. A shared path helper selects those files only when the country JSON explicitly enables crisis adjustment.

**Tech Stack:** R 4.6, base R, repository RDA model objects.

---

### Task 1: Specify mortality conversion and deterministic model shifts

**Files:**
- Create: `tests/test_apply_cod_crisis_adjustment.R`
- Create: `Data/Crisis_Adjustment/apply_cod_crisis_adjustment.R`

- [ ] **Step 1: Write the failing unit tests**

Test a known conversion and a synthetic model whose affected summary values and
both estimated-draw lists must shift by an exact fixed amount:

```r
qx <- crisis_deaths_to_u5mr(
  ed_0_1 = 10, ed_1_5 = 20,
  pop_0_1 = 1000, pop_1_5 = 4000
)
stopifnot(abs(qx - (1 - (1 - 0.01 / 1.007) *
  (1 - 0.02 / 1.012))) < 1e-12)

adjusted <- apply_crisis_increment_to_model(model, increments)
stopifnot(all(adjusted$overall$median[1] == model$overall$median[1] + qx))
stopifnot(all(adjusted$draws.est.overall[[1]]$draws ==
  model$draws.est.overall[[1]]$draws + qx))
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
Rscript tests/test_apply_cod_crisis_adjustment.R
```

Expected: failure because `apply_cod_crisis_adjustment.R` does not exist.

- [ ] **Step 3: Implement the minimal pure functions**

Implement:

```r
crisis_deaths_to_u5mr <- function(ed_0_1, ed_1_5, pop_0_1, pop_1_5) { ... }
validate_cod_crisis_application_inputs <- function(model, audit, level) { ... }
apply_crisis_increment_to_model <- function(model, increments) { ... }
```

The updater must change `overall`, `stratified`, `draws.est.overall`, and
`draws.est`, while rejecting duplicates, missing keys, and values outside
`[0, 1)`.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run the same command and expect `COD crisis application tests passed.`

### Task 2: Add real-input integration and safe output writing

**Files:**
- Modify: `tests/test_apply_cod_crisis_adjustment.R`
- Modify: `Data/Crisis_Adjustment/apply_cod_crisis_adjustment.R`

- [ ] **Step 1: Add a failing dry-run integration test**

```r
result <- apply_cod_crisis_adjustment(
  project_root = normalizePath(".", winslash = "/"),
  write_output = FALSE,
  quiet = TRUE
)
stopifnot(nrow(result$adm1$crisis_qx) == 26L * 5L)
stopifnot(nrow(result$adm2$crisis_qx) == 188L * 5L)
```

Also assert that years 2005-2025 are unchanged, all affected estimated draws
shift exactly, and all adjusted values remain below one.

- [ ] **Step 2: Run the test and verify RED**

Expected: failure because the integration function is absent.

- [ ] **Step 3: Implement the integration entry point**

Implement:

```r
apply_cod_crisis_adjustment <- function(
  project_root = normalizePath(".", winslash = "/"),
  write_output = TRUE,
  overwrite = FALSE,
  quiet = FALSE
) { ... }
```

Load exact input object names, validate hashes and schemas, create
`res_adm1_u5_crisis`/`res_adm2_u5_crisis`, retain the adjusted full model under
its original object name, and save with metadata.

- [ ] **Step 4: Run the focused test and verify GREEN**

Expected: all unit and real-input integration checks pass without writing.

### Task 3: Make crisis selection explicit in country metadata

**Files:**
- Create: `tests/test_crisis_adjustment_config.R`
- Modify: `Info/DR_Congo_general_info.json`
- Modify: `Rcode/_supporting_scripts/project_paths.R`
- Modify: `Rcode/11_Report_Plot.R`
- Modify: `Rcode/11_CountrySummary.Rmd`

- [ ] **Step 1: Write the failing metadata and selector tests**

```r
info <- jsonlite::fromJSON("Info/DR_Congo_general_info.json")
stopifnot(isTRUE(info$doCrisisAdj))
stopifnot(identical(
  select_crisis_result_file(base_file, enabled = FALSE),
  base_file
))
stopifnot(identical(
  select_crisis_result_file(base_file, enabled = TRUE),
  crisis_file
))
```

Also assert that enabled selection fails when the crisis file is missing and
that both report sources call the shared selector instead of detecting any
existing `_crisis.rda` file automatically.

- [ ] **Step 2: Run the selector test and verify RED**

Run `Rscript tests/test_crisis_adjustment_config.R`; expect failure because the
metadata field and helper do not exist.

- [ ] **Step 3: Implement the metadata-controlled selector**

Add `"doCrisisAdj": true` for DR Congo. Add
`crisis_adjustment_enabled()` and `select_crisis_result_file()` to
`project_paths.R`. Use the selector only for benchmarked subnational U5MR in
the report plot and country summary. Missing/false remains the default for all
other countries.

- [ ] **Step 4: Run the selector test and verify GREEN**

Expected: `Crisis-adjustment configuration tests passed.`

### Task 4: Generate and verify the crisis model files

**Files:**
- Create: `Results/DR_Congo/Betabinomial/U5MR/DR_Congo_res_adm1_unstrat_u5_allsurveys_bench_crisis.rda`
- Create: `Results/DR_Congo/Betabinomial/U5MR/DR_Congo_res_adm2_unstrat_u5_allsurveys_bench_crisis.rda`
- Modify: `Data/Crisis_Adjustment/README.md`

- [ ] **Step 1: Record SHA-256 hashes of the non-crisis inputs**

Use `Get-FileHash` on both benchmarked model files before the run.

- [ ] **Step 2: Run the application script**

```powershell
Rscript Data/Crisis_Adjustment/apply_cod_crisis_adjustment.R
```

Expected: two new crisis files and no modification to either base file.

- [ ] **Step 3: Verify fresh-load output contracts**

Check exact object names, 676/4,888 model rows, 130/940 affected region-years,
1,000 draws per row, finite probabilities below one, exact zero change after
2004, and exact shift by the saved crisis increment in 2000-2004.

- [ ] **Step 4: Run regressions**

```powershell
Rscript tests/test_cod_crisis_71_29.R
Rscript tests/test_apply_cod_crisis_adjustment.R
Rscript tests/test_georepo_shapefile_prep.R
```

- [ ] **Step 5: Document the run and report boundary**

Update the crisis README with application command, output contract, and the
fact that report regeneration remains a separate downstream stage.
