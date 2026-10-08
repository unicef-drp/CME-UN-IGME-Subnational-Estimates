# Country Summary Admin-Level Comparison Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce one portrait A4 country-summary PDF for Ghana and Guinea whose comparison appendix includes Admin 1 and any available Admin 2 estimates, with six regions per page.

**Architecture:** Generalize the existing previous-final comparison helpers around an explicit `admin_level` argument while retaining Admin 1 compatibility. Collect and paginate each administrative level independently, then draw sections in Admin 1 U5MR/NMR followed by Admin 2 U5MR/NMR. Treat Admin 2 and its direct overlays as optional, but keep Admin 1 required.

**Tech Stack:** R 4.6, ggplot2/grid, readxl, qpdf, rmarkdown/LaTeX, pypdf/pypdfium2 for PDF verification.

---

### Task 1: Specify generic administrative levels and six-panel pagination

**Files:**
- Modify: `tests/test_previous_final_comparison.R`
- Test: `tests/test_previous_final_comparison.R`

- [ ] **Step 1: Write failing pagination and schema assertions**

Change the default pagination assertion to require 10 regions to split as 6 and 4. Add Admin 2 fixture rows and assert that `prepare_previous_final_estimates(..., admin_level = "Admin2")` selects only Admin 2 and emits an `admin_level` column. Add path assertions for:

```r
stopifnot(
  identical(
    basename(env$current_admin_result_path(
      "Results/Testland", "Testland", "U5MR", "Admin2",
      strata_model = "unstrat", benchmarked = TRUE, all_surveys = TRUE
    )),
    "Testland_res_adm2_unstrat_u5_allsurveys_bench.rda"
  ),
  identical(
    basename(env$direct_admin_result_path(
      "Results/Testland", "Testland", "NMR", "Admin2"
    )),
    "Testland_direct_admin2_nmr.rda"
  )
)
```

Update the plot assertion to pass `admin_level = "Admin2"`, require title `Testland Admin-2 NMR: 2026 CC vs 2023 final`, and require six facet slots.

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
Rscript tests/test_previous_final_comparison.R
```

Expected: FAIL because generic result-path functions and Admin 2 selection do not exist, and current defaults still produce four panels.

### Task 2: Generalize comparison data preparation and path resolution

**Files:**
- Modify: `Rcode/12_Previous_Final_Comparison.R`
- Test: `tests/test_previous_final_comparison.R`

- [ ] **Step 1: Add administrative-level validation**

Add:

```r
normalize_admin_level <- function(admin_level) {
  value <- gsub("[- _]", "", as.character(admin_level), perl = TRUE)
  value <- paste0("Admin", sub("^Admin", "", value, ignore.case = TRUE))
  if (length(value) != 1L || is.na(value) || !value %in% c("Admin1", "Admin2")) {
    stop("admin_level must be 'Admin1' or 'Admin2'.", call. = FALSE)
  }
  value
}
```

- [ ] **Step 2: Generalize previous-final selection**

Give `prepare_previous_final_estimates()` an `admin_level = "Admin1"` argument, filter `Admin.Level` by that value, add `admin_level` to the returned rows, and update the missing-data error to identify the requested level. Preserve `GADM.Region` as the primary display name and use `Admin1.Region` only as the Admin 1 fallback.

- [ ] **Step 3: Replace hard-coded result paths**

Implement:

```r
current_admin_result_path <- function(res_dir, country, outcome, admin_level,
                                      strata_model = "unstrat",
                                      benchmarked = TRUE,
                                      all_surveys = identical(strata_model, "unstrat")) {
  admin_level <- normalize_admin_level(admin_level)
  outcome <- toupper(outcome)
  outcome_dir <- if (outcome == "U5MR") "U5MR" else "NMR"
  short_name <- if (outcome == "U5MR") "u5" else "nmr"
  admin_token <- if (admin_level == "Admin1") "adm1" else "adm2"
  file.path(res_dir, "Betabinomial", outcome_dir, paste0(
    country, "_res_", admin_token, "_", strata_model, "_", short_name,
    if (isTRUE(all_surveys)) "_allsurveys" else "",
    if (isTRUE(benchmarked)) "_bench" else "", ".rda"
  ))
}

direct_admin_result_path <- function(res_dir, country, outcome, admin_level) {
  admin_level <- normalize_admin_level(admin_level)
  outcome <- toupper(outcome)
  outcome_dir <- if (outcome == "U5MR") "U5MR" else "NMR"
  short_name <- if (outcome == "U5MR") "u5" else "nmr"
  file.path(res_dir, "Direct", outcome_dir, paste0(
    country, "_direct_", tolower(admin_level), "_", short_name, ".rda"
  ))
}
```

Keep the old Admin 1 helpers as thin wrappers so existing callers remain valid.

- [ ] **Step 4: Run the focused test**

Run `Rscript tests/test_previous_final_comparison.R`.

Expected: path and selection assertions pass; the test remains RED on six-panel plotting and multi-level orchestration.

### Task 3: Draw six-panel pages for both administrative levels

**Files:**
- Modify: `Rcode/12_Previous_Final_Comparison.R`
- Modify: `tests/test_previous_final_comparison.R`

- [ ] **Step 1: Generalize page titles and defaults**

Change defaults to `regions_per_page = 6L` and `panel_slots = 6L`. Add `admin_level` to `build_previous_final_page()` and use:

```r
admin_label <- sub("^Admin", "Admin-", normalize_admin_level(admin_level))
title = paste0(country, " ", admin_label, " ", outcome, ": ",
               current_label, " vs ", previous_label)
```

Keep `facet_wrap(ncol = 2, nrow = ceiling(panel_slots / 2))`, which gives a 2x3 portrait grid for six panels.

- [ ] **Step 2: Collect levels independently**

In `run_previous_final_comparison()`, add `admin_levels = c("Admin1", "Admin2")`. For each level:

1. Check whether the previous workbook has NMR/U5MR total-sex rows.
2. Require Admin 1; skip absent Admin 2 with `message()`.
3. Require current U5MR and NMR files for the level; skip Admin 2 if either is absent.
4. Load direct files when present; otherwise use an empty data frame with the comparison export schema and warn.
5. Add `admin_level` to current and direct rows.
6. Compute region names and pages within the level.

Draw and export sections in this order:

```r
for (admin_level in included_admin_levels) {
  for (outcome in c("U5MR", "NMR")) {
    for (page_number in seq_along(level_pages[[admin_level]])) {
      # build, blank unused slots, and draw the page
    }
  }
}
```

Include `admin_level` in the exported CSV and rename comparison artifacts to `<Country>_admin_levels_current_vs_2023_final.*`.

- [ ] **Step 3: Verify GREEN**

Run:

```powershell
Rscript tests/test_previous_final_comparison.R
```

Expected: `Previous-final comparison helpers pass schema and pagination checks.` and exit code 0.

### Task 4: Set pipeline entry points to six regions per page

**Files:**
- Modify: `Rcode/run_country_pipeline.R`
- Modify: `Rcode/_supporting_scripts/pipeline_runner.R`
- Modify: `tests/test_previous_final_comparison.R`

- [ ] **Step 1: Write the failing runbook assertion**

Require `regions_per_page = 6L` in both pipeline files and reject stale `regions_per_page = 4L` fragments.

- [ ] **Step 2: Run the test and verify RED**

Run `Rscript tests/test_previous_final_comparison.R`.

Expected: FAIL because both entry points still pass 4.

- [ ] **Step 3: Update both entry points**

Replace every comparison-appendix call with:

```r
regions_per_page = 6L
```

- [ ] **Step 4: Run comparison and summary-path tests**

Run:

```powershell
Rscript tests/test_previous_final_comparison.R
Rscript tests/test_country_summary_reproducible_paths.R
```

Expected: both exit 0.

### Task 5: Regenerate Ghana and Guinea summaries

**Files:**
- Generate: `Results/Ghana/11_CountrySummary.pdf`
- Generate: `Results/Guinea/11_CountrySummary.pdf`
- Generate: `Results/<Country>/Figures/PreviousFinalComparison/<Country>_admin_levels_current_vs_2023_final.pdf`
- Generate: `Results/<Country>/Figures/PreviousFinalComparison/<Country>_admin_levels_current_vs_2023_final_data.csv`

- [ ] **Step 1: Render each portrait core and append comparisons**

For each country, set `RSTUDIO_PANDOC` to the located RStudio/Quarto Pandoc tools directory, render `Rcode/11_CountrySummary.Rmd` to `Results/<Country>/Figures/Summary/11_CountrySummary_core.pdf`, then call `run_country_summary_comparison_appendix()` with `regions_per_page = 6L` and the country JSON's selected final model.

- [ ] **Step 2: Resolve open-file fallbacks**

If Windows writes `_with_comparison.pdf`, leave both source files intact and report the open standard file. Once it is closed, replace `11_CountrySummary.pdf`, verify the replacement, then remove the fallback using an absolute path confirmed to remain inside the workspace.

### Task 6: Verify final PDF structure and layout

**Files:**
- Inspect: `Results/Ghana/11_CountrySummary.pdf`
- Inspect: `Results/Guinea/11_CountrySummary.pdf`
- Generate temporary PNGs under: `tmp/pdfs/admin_level_final/`

- [ ] **Step 1: Run structural verification**

Use pypdf to assert every page is portrait, both files contain Admin-1 U5MR/NMR comparison titles, Ghana contains no Admin-2 comparison title, and Guinea contains Admin-2 U5MR/NMR titles after the Admin-1 sections.

- [ ] **Step 2: Render representative pages**

Render the first core page, one full six-panel Admin 1 page, one partial final Admin 1 page, one full Admin 2 page, and the final page for each applicable country with pypdfium2.

- [ ] **Step 3: Inspect visual output**

Confirm A4 portrait dimensions, readable titles/legends/axes, six visible panels on full pages, blank unused final slots, and no clipping or overlap.

- [ ] **Step 4: Run final focused tests**

Run the two R tests again after PDF generation and report their fresh exit codes together with PDF page counts and section inventory.
