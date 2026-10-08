# Manual Country Pipeline Runbook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `Rcode/run_country_pipeline.R` a safe manual runbook whose numbered country-processing steps never run merely because the main file is sourced.

**Architecture:** Keep the existing argument parser and pipeline-runner library available, but replace the final automatic runner invocation with active context initialization plus disabled `if (FALSE)` blocks. Verify the entrypoint structurally so tests never start downloads, spatial processing, INLA models, or report rendering.

**Tech Stack:** Base R, existing pipeline runner helpers, standalone `stopifnot()` R tests.

---

### Task 1: Add the manual-entrypoint regression test

**Files:**
- Create: `tests/test_manual_country_pipeline_entrypoint.R`

- [ ] **Step 1: Write the failing test**

Create a static source-code test that reads `Rcode/run_country_pipeline.R`, rejects a top-level automatic `run_country_pipeline(` call, verifies disabled manual blocks, verifies the isolated country-info and GeoRepo `main()` patterns, and checks the required scripts occur in pipeline order.

```r
project_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
main_file <- file.path(project_dir, "Rcode", "run_country_pipeline.R")
lines <- readLines(main_file, warn = FALSE)
text <- paste(lines, collapse = "\n")
trimmed <- trimws(lines)

stopifnot(!any(grepl("^run_country_pipeline\\s*\\(", trimmed)))
stopifnot(sum(grepl("^if \\(FALSE\\) \\{", trimmed)) >= 12)
stopifnot(grepl("sys.source\\(", text))
stopifnot(grepl("country_info_env", text, fixed = TRUE))
stopifnot(grepl("georepo_env$main()", text, fixed = TRUE))

scripts <- c(
  "1_Preperation.R", "2_download_georepo_shapefiles.R",
  "3_DataProcessing_sf.R", "4_Direct_SmoothDirect_sf.R",
  "5_Admin_Weights_sf.R", "6_Comparison_Plot.R", "7a_UR_prop.R",
  "7b_UR_thresholding_sf.R", "8_10_BB8.R",
  "8_10_Run_Unstrat_Admin1_Benchmarks.R", "9_Comparison_Plot.R",
  "9_Diagnostic_Plots.R", "11_Report_Plot.R", "11_CountrySummary.Rmd"
)
positions <- vapply(scripts, function(script) regexpr(script, text, fixed = TRUE)[1], integer(1))
stopifnot(all(positions > 0), all(diff(positions) > 0))

message("manual country pipeline entrypoint tests passed")
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
Rscript tests/test_manual_country_pipeline_entrypoint.R
```

Expected: FAIL because the current file still contains a top-level `run_country_pipeline(...)` invocation and has no disabled manual blocks.

### Task 2: Replace the automatic invocation with the manual runbook

**Files:**
- Modify: `Rcode/run_country_pipeline.R`

- [ ] **Step 1: Add active manual context initialization**

After argument parsing/help handling, assign `project_dir`, `country`, `mode`, and `render_summary`; set `UN_SUBNATIONAL_HOME`, `UN_SUBNATIONAL_COUNTRY`, and `UN_SUBNATIONAL_MODE`; set the working directory to the project root; and print instructions. Do not invoke `run_country_pipeline()`.

- [ ] **Step 2: Add disabled numbered blocks**

Add `if (FALSE) { ... }` blocks in the approved order. Use a temporary `country_info_env` around the country configuration script and a temporary `georepo_env` followed by `georepo_env$main()` for GeoRepo. Add separate blocks for every ordinary numbered script so each can be executed independently.

- [ ] **Step 3: Add special safety and decision notes**

In the Admin Weights block, save and restore `ADMIN_WEIGHTS_SKIP_100M_COMPARISON`. Before data processing, document the optional MICS preprocessing scripts. Before 7a/7b, document the `frame_year` versus survey-derived-strata condition. After Steps 6 and 9, add explicit review messages. Render the summary into `Results/<country>/11_CountrySummary.pdf` only inside its disabled block.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run:

```powershell
Rscript tests/test_manual_country_pipeline_entrypoint.R
```

Expected: `manual country pipeline entrypoint tests passed` with exit status 0.

- [ ] **Step 5: Run regression verification**

Run:

```powershell
Rscript tests/test_pipeline_runner.R
```

Expected: `pipeline runner tests passed` with exit status 0. Also run `git diff --check` and parse the main file with `Rscript -e "parse(file='Rcode/run_country_pipeline.R')"`.

- [ ] **Step 6: Review the diff without committing user-owned changes**

Inspect only `Rcode/run_country_pipeline.R` and `tests/test_manual_country_pipeline_entrypoint.R`. Preserve the pre-existing Ethiopia default, and do not stage or commit the implementation unless the user explicitly requests it.
