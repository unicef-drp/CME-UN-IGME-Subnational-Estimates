# New-Country Current-Only Sub-Area Appendix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure every new-country summary appends current-only Admin-1 and available Admin-2 sub-area trend pages when the previous-final workbook has no rows for that country.

**Architecture:** Generalize the existing previous-final comparison generator instead of adding a second plotting path. Detect whether Admin-1 previous-final rows exist, retain the established comparison behavior when they do, and otherwise build the same paginated plots from current model and direct-survey data only. Return an explicit mode so artifacts use truthful names and the wrapper always appends the generated pages after the core summary.

**Tech Stack:** R 4.6, ggplot2/grid, readxl/openxlsx, qpdf, base-R regression tests.

---

### Task 1: Specify the no-prior-estimate behavior

**Files:**
- Modify: `tests/test_previous_final_comparison.R`
- Test: `tests/test_previous_final_comparison.R`

- [ ] **Step 1: Add a real new-country fixture**

Create a temporary previous-final workbook containing other countries but no rows for `TST`. Under a temporary `Results/Testland`, save current Admin-1 and Admin-2 NMR/U5MR result files plus survey-direct overlays and the required survey/admin lookup inputs.

- [ ] **Step 2: Assert the desired public deliverable**

Call `run_country_summary_comparison_appendix()` and require:

```r
stopifnot(
  identical(result$status, "appended_current_only"),
  identical(result$mode, "current_only"),
  setequal(result$admin_levels, c("Admin1", "Admin2")),
  qpdf::pdf_length(result$summary_pdf) >
    qpdf::pdf_length(result$core_summary_pdf)
)
```

Read the exported CSV and require current and direct-survey sources but no previous-final source. Also build one current-only page directly and require its title to omit the previous-round label and `vs`.

- [ ] **Step 3: Run the focused test and verify RED**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_previous_final_comparison.R
```

Expected: fail because the current no-prior branch returns `skipped_no_previous_final`, copies only the core PDF, and current-only titles are not supported.

### Task 2: Generalize plot data and titles

**Files:**
- Modify: `Rcode/12_Previous_Final_Comparison.R`
- Test: `tests/test_previous_final_comparison.R`

- [ ] **Step 1: Detect current-only mode**

In `run_previous_final_comparison()`, determine whether usable Admin-1 previous-final rows exist. If not, set `mode <- "current_only"` and load current Admin-1 plus any current Admin-2 results without calling `prepare_previous_final_estimates()`.

- [ ] **Step 2: Preserve comparison mode**

When Admin-1 previous-final rows exist, keep the existing current-versus-previous behavior, including optional Admin-2 comparison only when prior Admin-2 data and current files exist.

- [ ] **Step 3: Make current-only pages truthful**

Infer whether `previous_label` occurs in each page's model data. Build scales only for present modeled sources and use:

```r
title = paste0(country_display, " ", admin_label, " ", outcome,
               ": ", current_label, " sub-area trends")
```

for current-only pages. Keep the existing comparison title otherwise.

- [ ] **Step 4: Use mode-specific artifact names**

Write current-only artifacts as `<Country>_admin_levels_current_subarea.pdf` and `.csv`, return `mode`, and publish them under `Results/<Country>/Figures/CurrentSubarea`. Preserve the existing comparison names and directory for established countries.

- [ ] **Step 5: Run the focused test and verify GREEN**

Run the focused R test and require exit code 0.

### Task 3: Verify integration and PDF layout

**Files:**
- Test: `tests/test_country_summary_reproducible_paths.R`
- Inspect: a generated no-prior-estimate summary PDF

- [ ] **Step 1: Run summary regression tests**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_previous_final_comparison.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_country_summary_reproducible_paths.R
```

Expected: both exit 0.

- [ ] **Step 2: Verify the actual new-country artifact**

Rebuild an available new-country summary whose previous-final workbook has no rows. Confirm the public page count equals the core page count plus current-only plot pages and that the final pages contain Admin-1 plus available Admin-2 NMR/U5MR sections.

- [ ] **Step 3: Render and inspect representative pages**

Render pages 1, 2, and the last page to `tmp/pdf_checks/<country>_country_summary/`. Confirm the last sub-area plot is legible, current-only, and free of clipping or overlapping legends.
