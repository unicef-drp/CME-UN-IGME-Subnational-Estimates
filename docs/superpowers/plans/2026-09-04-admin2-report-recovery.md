# Admin-2 Report Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the selected Admin-2 model outputs for Angola, Kenya, and Niger and publish verified 2026 reports for those countries plus Myanmar, while preserving validated national and Admin-1 outputs.

**Architecture:** Add a pure, testable recovery planner and an opt-in Admin-2-only runner used by `Rcode/8_10_BB8.R` when `BB8_FINAL_ADMIN2_ONLY=1`. The runner selects the configured final branch, reuses the production fitting and benchmarking functions, and writes only the selected Admin-2 family. Operational scripts back up artifacts, generate Niger's missing weights, run models, assemble reports, and record manifests and PDF QA evidence.

**Tech Stack:** R 4.6.1, SUMMER, INLA, sf/spdep, jsonlite, rmarkdown/Pandoc/LaTeX, qpdf, PowerShell, PyMuPDF.

---

### Task 1: Define the Admin-2 recovery contract with a failing test

**Files:**
- Create: `tests/test_bb8_final_admin2_only.R`
- Create: `Rcode/_supporting_scripts/final_admin2_recovery.R`
- Modify: `Rcode/8_10_BB8.R:39-70`

- [ ] **Step 1: Write the failing recovery-planner test**

Create `tests/test_bb8_final_admin2_only.R` with these assertions:

```r
helper <- file.path(
  "Rcode", "_supporting_scripts", "final_admin2_recovery.R"
)
stopifnot(file.exists(helper))

env <- new.env(parent = baseenv())
sys.source(helper, envir = env)

strat <- env$final_admin2_recovery_plan(list(
  strata.model = "strat", bench.model = "bench"
))
stopifnot(
  identical(strat$branch, "strat"),
  identical(strat$data_scope, "same_frame"),
  identical(strat$stubs$nmr$base, "adm2_strat_nmr"),
  identical(strat$stubs$nmr$bench, "adm2_strat_nmr_bench"),
  identical(strat$stubs$u5$base, "adm2_strat_u5"),
  identical(strat$stubs$u5$bench, "adm2_strat_u5_bench")
)

unstrat <- env$final_admin2_recovery_plan(list(
  strata.model = "unstrat", bench.model = "bench"
))
stopifnot(
  identical(unstrat$branch, "unstrat"),
  identical(unstrat$data_scope, "all_surveys"),
  identical(
    unstrat$stubs$nmr$bench,
    "adm2_unstrat_nmr_allsurveys_bench"
  ),
  identical(
    unstrat$stubs$u5$bench,
    "adm2_unstrat_u5_allsurveys_bench"
  )
)

bad_unbenchmarked <- try(
  env$final_admin2_recovery_plan(list(
    strata.model = "strat", bench.model = "unbench"
  )),
  silent = TRUE
)
stopifnot(inherits(bad_unbenchmarked, "try-error"))

bad_branch <- try(
  env$final_admin2_recovery_plan(list(
    strata.model = "unknown", bench.model = "bench"
  )),
  silent = TRUE
)
stopifnot(inherits(bad_branch, "try-error"))

main_text <- paste(readLines("Rcode/8_10_BB8.R", warn = FALSE), collapse = "\n")
stopifnot(
  grepl('Sys.getenv("BB8_FINAL_ADMIN2_ONLY", "0")', main_text, fixed = TRUE),
  grepl("run_final_admin2_only", main_text, fixed = TRUE)
)
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_bb8_final_admin2_only.R
```

Expected: FAIL because `final_admin2_recovery.R` does not exist.

- [ ] **Step 3: Add the pure recovery planner**

Create `Rcode/_supporting_scripts/final_admin2_recovery.R` beginning with:

```r
final_admin2_recovery_plan <- function(final_model) {
  if (!is.list(final_model) ||
      !identical(final_model$bench.model, "bench")) {
    stop(
      "BB8 final Admin-2 recovery requires a benchmarked final model.",
      call. = FALSE
    )
  }
  branch <- as.character(final_model$strata.model)[1]
  if (!branch %in% c("strat", "unstrat")) {
    stop(
      "Unsupported final Admin-2 recovery branch: ", branch,
      call. = FALSE
    )
  }
  all_surveys <- identical(branch, "unstrat")
  suffix <- if (all_surveys) "unstrat_%s_allsurveys" else "strat_%s"
  list(
    branch = branch,
    data_scope = if (all_surveys) "all_surveys" else "same_frame",
    stratified = identical(branch, "strat"),
    stubs = list(
      nmr = list(
        base = sprintf(paste0("adm2_", suffix), "nmr"),
        bench = paste0(sprintf(paste0("adm2_", suffix), "nmr"), "_bench")
      ),
      u5 = list(
        base = sprintf(paste0("adm2_", suffix), "u5"),
        bench = paste0(sprintf(paste0("adm2_", suffix), "u5"), "_bench")
      )
    )
  )
}
```

- [ ] **Step 4: Parse the opt-in flag in the production BB8 script**

After the existing resume flags in `Rcode/8_10_BB8.R`, add:

```r
bb8_final_admin2_only <- tolower(
  Sys.getenv("BB8_FINAL_ADMIN2_ONLY", "0")
) %in% c("1", "true", "yes", "y")
```

Source the helper beside the existing BB8 supporting scripts:

```r
source(file.path(
  home.dir,
  "Rcode", "_supporting_scripts", "final_admin2_recovery.R"
))
```

- [ ] **Step 5: Re-run the focused test**

Run the Task 1 command again.

Expected: PASS and exit code 0.

- [ ] **Step 6: Commit the recovery contract**

```powershell
git add -- tests/test_bb8_final_admin2_only.R Rcode/8_10_BB8.R Rcode/_supporting_scripts/final_admin2_recovery.R
git commit -m "test: define final Admin-2 recovery mode"
```

### Task 2: Implement Admin-2-only fitting and benchmarking

**Files:**
- Modify: `tests/test_bb8_final_admin2_only.R`
- Modify: `Rcode/_supporting_scripts/final_admin2_recovery.R`
- Modify: `Rcode/8_10_BB8.R:133-172`
- Modify: `Rcode/8_10_BB8.R:203-314`

- [ ] **Step 1: Extend the test with output and prerequisite contracts**

Add assertions that `final_admin2_expected_outputs()` returns exactly ten
files: one fit summary, three component RDAs, and one result RDA for each
outcome's benchmarked selected family. Also require
`validate_final_admin2_inputs()` to reject missing Admin-2 matrices, names,
population weights, or region coverage.

```r
outputs <- env$final_admin2_expected_outputs(
  country = "Testland",
  res_dir = "Results/Testland",
  plan = strat
)
stopifnot(
  length(outputs) == 10L,
  any(grepl("Testland_res_adm2_strat_nmr_bench.rda$", outputs)),
  any(grepl("Testland_res_adm2_strat_u5_bench.rda$", outputs)),
  all(grepl("Betabinomial", outputs, fixed = TRUE))
)

valid_names <- data.frame(
  GeoRepo = c("A", "B"),
  Internal = c("admin2_1", "admin2_2")
)
valid_matrix <- matrix(c(0, 1, 1, 0), 2, 2)
dimnames(valid_matrix) <- list(valid_names$Internal, valid_names$Internal)
valid_weights <- data.frame(
  region = rep(valid_names$Internal, each = 2),
  years = rep(2024:2025, times = 2),
  proportion = 0.5
)
stopifnot(isTRUE(env$validate_final_admin2_inputs(
  admin2_names = valid_names,
  admin2_matrix = valid_matrix,
  weight_u1 = valid_weights,
  weight_u5 = valid_weights,
  years = 2024:2025
)))
missing_region <- valid_weights[valid_weights$region != "admin2_2", ]
stopifnot(inherits(try(env$validate_final_admin2_inputs(
  valid_names, valid_matrix, missing_region, valid_weights, 2024:2025
), silent = TRUE), "try-error"))
```

- [ ] **Step 2: Run the focused test and verify RED**

Expected: FAIL because the two new functions do not exist.

- [ ] **Step 3: Implement prerequisite validation and expected-output listing**

In `final_admin2_recovery.R`, implement functions that:

```r
validate_final_admin2_inputs <- function(
    admin2_names, admin2_matrix, weight_u1, weight_u5, years) {
  ids <- as.character(admin2_names$Internal)
  if (length(ids) == 0L || anyNA(ids) || any(!nzchar(ids)) ||
      anyDuplicated(ids)) {
    stop("Admin-2 name map is incomplete.", call. = FALSE)
  }
  if (!identical(dim(admin2_matrix), c(length(ids), length(ids))) ||
      !identical(rownames(admin2_matrix), ids) ||
      !identical(colnames(admin2_matrix), ids)) {
    stop("Admin-2 adjacency does not match the name map.", call. = FALSE)
  }
  validate_weights <- function(weights, label) {
    required <- c("region", "years", "proportion")
    if (!all(required %in% names(weights))) {
      stop(label, " weights have an invalid schema.", call. = FALSE)
    }
    if (!setequal(unique(as.character(weights$region)), ids) ||
        !setequal(unique(as.integer(weights$years)), as.integer(years)) ||
        any(!is.finite(weights$proportion)) ||
        any(weights$proportion < 0)) {
      stop(label, " weights fail coverage or value checks.", call. = FALSE)
    }
    totals <- aggregate(proportion ~ years, weights, sum)
    if (any(abs(totals$proportion - 1) > 1e-6)) {
      stop(label, " weights do not sum to one by year.", call. = FALSE)
    }
  }
  validate_weights(weight_u1, "Admin-2 U1")
  validate_weights(weight_u5, "Admin-2 U5")
  TRUE
}
```

`final_admin2_expected_outputs()` will build the exact benchmarked NMR and U5
fit-summary/component/result paths from `plan$stubs`.

- [ ] **Step 4: Implement the isolated fit/save routine**

Add `run_final_admin2_only()` with explicit arguments for country context,
data, adjacency, population weights, stratum weights, IGME series, adjustment
frame, and existing production functions. For NMR and U5 it must:

1. fit the selected Admin-2 base model with `getBB8()`;
2. save temporal diagnostics, hyperparameters, fixed effects, results, and the
   text summary using the established variable and filename convention;
3. calculate `compute_admin_benchmark_adjustment()` from
   `$draws.est.overall` and the age-appropriate population weights;
4. save the Admin-2 benchmark adjustment;
5. fit and save the selected benchmarked model; and
6. return the paths written.

Use `stratified = plan$stratified`, Admin-2 stratum weights only for the
stratified branch, and `time.model = "ar1"`, `st.time.model = "ar1"`, and
`nsim = 1000`, matching the production script.

- [ ] **Step 5: Gate the production script at the two safe entry points**

For `final_model$strata.model == "unstrat"`, invoke the recovery runner after
population weights load and before UR-stratum files are required. Load
`Kenya_cluster_dat.rda` or `Niger_cluster_dat.rda`, according to the active
country, and rebuild its HIV adjustment frame first.

For `final_model$strata.model == "strat"`, invoke the runner after the existing
same-frame UR-stratum weights are prepared.

In both cases, validate prerequisites, run the helper, validate the expected
files, print their paths, and terminate the standalone R process with status 0.
Guard the existing population-weight `save()` calls with
`if (!bb8_final_admin2_only)` so the recovery run cannot rewrite Admin-1
weights. The default path remains byte-for-byte behaviorally unchanged.

- [ ] **Step 6: Run focused and regression tests**

```powershell
$r = 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe'
& $r tests/test_bb8_final_admin2_only.R
& $r tests/test_bb8_admin2_fit_filename.R
& $r tests/test_bb8_admin2_benchmark_saved_draws.R
& $r tests/test_bb8_allsurvey_benchmark_resume.R
& $r tests/test_bb8_resume_allsurvey_admin2_u5.R
& $r tests/test_bb8_resume_strat_admin2_u5.R
```

Expected: all commands exit 0.

- [ ] **Step 7: Commit the targeted runner**

```powershell
git add -- tests/test_bb8_final_admin2_only.R Rcode/8_10_BB8.R Rcode/_supporting_scripts/final_admin2_recovery.R
git commit -m "feat: recover only configured final Admin-2 models"
```

### Task 3: Back up and generate Niger Admin-2 population weights

**Files:**
- Create: `Results/Niger/logs/20260904_113000_admin2_report_recovery/pre_run_inventory.csv`
- Create: `Results/Niger/logs/20260904_113000_admin2_report_recovery/backup_before_admin2_recovery/**`
- Create: `Results/Niger/logs/20260904_113000_admin2_report_recovery/admin_weights.log`
- Generate: `Data/Countries/Niger/worldpop/adm2_weights_u1.rda`
- Generate: `Data/Countries/Niger/worldpop/adm2_weights_u5.rda`

- [ ] **Step 1: Create a timestamped run directory and inventory**

Record path, size, modification time, and SHA-256 for Niger's current WorldPop
weight files, Betabinomial files, report figures, and public PDFs.

- [ ] **Step 2: Back up every existing artifact the weight step may replace**

Copy the four Admin-1 weight files, any existing Admin-2 weight files, report
figures, and PDFs into `backup_before_admin2_recovery` while preserving names.

- [ ] **Step 3: Run the supported Admin Weights step**

Load Niger with `Rcode/1_Preperation.R`, then source
`Rcode/5_Admin_Weights_sf.R` in production mode with output captured in
`admin_weights.log`.

- [ ] **Step 4: Validate the generated weights**

Load both Admin-2 RDA files and require complete region/year coverage,
finite nonnegative proportions, and per-year sums within `1e-6` of one.
Compare the Admin-1 weight objects numerically with their backups and stop if
they changed.

### Task 4: Recover Angola, Kenya, and Niger selected Admin-2 models

**Files:**
- Create: `Results/Angola/logs/20260904_113000_admin2_report_recovery/**`
- Create: `Results/Kenya/logs/20260904_113000_admin2_report_recovery/**`
- Create: `Results/Niger/logs/20260904_113000_admin2_report_recovery/**`
- Generate: selected Admin-2 base and benchmarked RDAs and diagnostics under
  `Results/Angola/Betabinomial/NMR/`,
  `Results/Angola/Betabinomial/U5MR/`,
  `Results/Kenya/Betabinomial/NMR/`,
  `Results/Kenya/Betabinomial/U5MR/`,
  `Results/Niger/Betabinomial/NMR/`, and
  `Results/Niger/Betabinomial/U5MR/`

- [ ] **Step 1: Inventory and back up each country independently**

Back up the exact selected Admin-2 family if partially present, all Admin-2
benchmark-adjustment files, report figures, and public PDFs. Hash every
national and Admin-1 Betabinomial artifact into `protected_hashes_before.csv`.

- [ ] **Step 2: Run Angola's selected recovery branch**

```powershell
$env:UN_SUBNATIONAL_COUNTRY = 'Angola'
$env:UN_SUBNATIONAL_MODE = 'production'
$env:BB8_FINAL_ADMIN2_ONLY = '1'
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' `
  -e 'source("Rcode/1_Preperation.R"); source("Rcode/8_10_BB8.R")'
```

Expected: only `adm2_strat_{nmr,u5}` base and benchmarked families are written.

- [ ] **Step 3: Run Kenya's selected recovery branch**

Use the same command with `UN_SUBNATIONAL_COUNTRY='Kenya'`.

Expected: only `adm2_unstrat_{nmr,u5}_allsurveys` base and benchmarked families
are written.

- [ ] **Step 4: Run Niger's selected recovery branch**

Use the same command with `UN_SUBNATIONAL_COUNTRY='Niger'` after Task 3 passes.

Expected: only `adm2_unstrat_{nmr,u5}_allsurveys` base and benchmarked families
are written.

- [ ] **Step 5: Validate model structures and protected hashes**

For every selected benchmarked result require:

- the expected object name;
- all configured Admin-2 region IDs;
- years 2000-2025;
- finite `lower`, `median`, and `upper` values;
- `lower <= median <= upper`; and
- a nonzero file size.

Re-hash every national and Admin-1 artifact and require exact equality with
`protected_hashes_before.csv`.

### Task 5: Assemble the five friendly country reports

**Files:**
- Create/replace: `Results/Lesotho/Lesotho Report 2026.pdf`
- Create/replace: `Results/Myanmar/Myanmar Report 2026.pdf`
- Create/replace: `Results/Angola/Angola Report 2026.pdf`
- Create/replace: `Results/Kenya/Kenya Report 2026.pdf`
- Create/replace: `Results/Niger/Niger Report 2026.pdf`
- Create: per-country manifests and timing workbooks under
  `Results/Lesotho/logs/20260904_111000_report_repair/`,
  `Results/Myanmar/logs/20260904_111000_report_repair/`, and each of
  `Results/Angola/logs/20260904_113000_admin2_report_recovery/`,
  `Results/Kenya/logs/20260904_113000_admin2_report_recovery/`, and
  `Results/Niger/logs/20260904_113000_admin2_report_recovery/`
- Regenerate each country's existing `Figures/Summary`, `Figures/Trends`,
  `Figures/CurrentSubarea`, and `Figures/PreviousFinalComparison` artifacts as
  applicable

- [ ] **Step 1: Publish Myanmar in explicit current-only mode**

Reuse the already regenerated report plots and core PDF. Call
`run_country_summary_comparison_appendix()` with both Admin levels and a
deliberately unavailable `previous_workbook` path so the existing supported
`current_only` branch is selected. Record this reason in the manifest:

```r
previous_final_disabled_reason <- paste(
  "2023 Bago and Shan aggregate regions cannot be mapped one-to-one to",
  "the 2026 Bago East/West and Shan North/South/East regions"
)
```

- [ ] **Step 2: Refresh Angola, Kenya, and Niger report plots**

For each country, run the pipeline setup step and `report_plots` step through
`pipeline_runner.R`, recording step logs and elapsed times.

- [ ] **Step 3: Render and assemble Angola, Kenya, and Niger summaries**

Render `Rcode/11_CountrySummary.Rmd` to each of
`Results/Angola/Figures/Summary/11_CountrySummary_core.pdf`,
`Results/Kenya/Figures/Summary/11_CountrySummary_core.pdf`, and
`Results/Niger/Figures/Summary/11_CountrySummary_core.pdf`, then call
`run_country_summary_comparison_appendix()` with
`admin_levels=c("Admin1", "Admin2")`. Stop on strict geography-validation
errors; do not fabricate a crosswalk or omit Admin-2.

- [ ] **Step 4: Reconfirm Lesotho**

Confirm the existing refreshed `Lesotho Report 2026.pdf` is newer than its
selected Admin-2 results, references Admin-2 in extracted text, and retains
the successful run manifest and artifact backup.

### Task 6: Verify all outputs before completion

**Files:**
- Create: `Results/Lesotho/logs/20260904_111000_report_repair/pdf_review/**`
- Create: `Results/Myanmar/logs/20260904_111000_report_repair/pdf_review/**`
- Create: `Results/Angola/logs/20260904_113000_admin2_report_recovery/pdf_review/**`
- Create: `Results/Kenya/logs/20260904_113000_admin2_report_recovery/pdf_review/**`
- Create: `Results/Niger/logs/20260904_113000_admin2_report_recovery/pdf_review/**`
- Create: one `validation_summary.json` in each run directory above

- [ ] **Step 1: Run focused repository tests**

```powershell
$r = 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe'
& $r tests/test_bb8_final_admin2_only.R
& $r tests/test_country_report_filename.R
& $r tests/test_report_model_configuration.R
& $r tests/test_myanmar_sampling_frame_config.R
& $r tests/test_previous_final_admin1_mapping.R
```

Expected: every focused test exits 0. Record unrelated failures separately
rather than changing out-of-scope country configuration.

- [ ] **Step 2: Perform structural PDF checks**

Run `Rcode/_script_for_specific_tasks/verify_country_pdf.py` for each friendly
PDF. Require nonzero pages, no blank-page flags, extractable country title,
and Admin-2 text for countries configured with Admin-2.

- [ ] **Step 3: Inspect every page visually**

Inspect all generated contact sheets, then inspect page 1, a middle page, and
the last page at full resolution. Reject clipping, overlaps, missing figures,
unreadable legends, unintended blanks, or incorrect country titles.

- [ ] **Step 4: Write final validation summaries**

For each country record observed model files, region/year coverage, protected
hash comparison, PDF path/name, page count, blank-page check, visual-review
status, warnings, and backup location.

- [ ] **Step 5: Commit code and tests only**

Do not commit generated country data or reports unless they are already tracked
and explicitly intended for version control. Confirm the final code commits and
leave all operational run evidence in the country log directories.
