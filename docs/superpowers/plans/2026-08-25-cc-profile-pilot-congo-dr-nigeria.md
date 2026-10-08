# 2026 CC Profile Pilot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and run a reproducible 2026 CC-profile exporter for Congo DR and Nigeria that produces four 2000–2025 map PNGs and two populated Excel profiles.

**Architecture:** Keep the estimation repository read-only. R modules resolve configured final-model files, validate and normalize estimates, join GeoRepo geography, and render the 2023-style maps. A JavaScript workbook module imports the two reused 2023 templates, preserves their styling, writes the normalized data, embeds the maps, removes the stale `data_region` name, and exports the profiles.

**Tech Stack:** R 4.6.1, `testthat`, `jsonlite`, `data.table`, `sf`, `ggplot2`, `ggrepel`, `cowplot`, `patchwork`, `ragg`; bundled Node.js and `@oai/artifact-tool`; PowerShell orchestration.

---

All implementation paths below are relative to:

`C:\Users\yanliu\OneDrive - UNICEF\Child Mortality - Documents\UN IGME Subnational\2026 Round Subnational\_code_CC_subnational`

The read-only model repository is:

`C:\Users\yanliu\OneDrive - UNICEF\Child Mortality - Documents\UN IGME Subnational\2026 Round Subnational\UN-Subnational-Estimates-main`

### Task 1: Scaffold the exporter and reuse the approved 2023 assets

**Files:**
- Create: `README.md`
- Create: `config/pilot_countries.csv`
- Create: `templates/2026_subnational_template_admin1.xlsx`
- Create: `templates/2026_subnational_template_admin2.xlsx`
- Create directories: `R`, `js`, `tests/testthat`, `tests/js`, `maps`, `output/profile_data`, `output/logs`

- [ ] **Step 1: Create the folder structure**

Use PowerShell `New-Item -ItemType Directory` with the exact target paths. Do not delete or overwrite existing content.

- [ ] **Step 2: Copy the two 2023 templates**

Copy only:

```text
Earlier Round/2023 Round Estimation/_code_CC_subnational_2023/2023_subnational_template_admin1.xlsx
Earlier Round/2023 Round Estimation/_code_CC_subnational_2023/2023_subnational_template_admin2.xlsx
```

Rename them to the 2026 names above. Verify both ZIP signatures begin `50-4B-03-04` and record SHA-256 hashes.

- [ ] **Step 3: Add the pilot metadata CSV**

Write this exact logical content with RFC-4180 quoting:

```csv
country,iso3,display_name,admin_levels,survey_source
DR_Congo,COD,Democratic Republic of the Congo,1|2,"Demographic and Health Survey 2007; Demographic and Health Survey 2013–2014; Multiple Indicator Cluster Survey 2018; Demographic and Health Survey 2023–2024"
Nigeria,NGA,Nigeria,1,"Demographic and Health Survey 2003; Demographic and Health Survey 2008; Malaria Indicator Survey 2010; Demographic and Health Survey 2013; Multiple Indicator Cluster Survey 2017; Demographic and Health Survey 2018; Multiple Indicator Cluster Survey 2021; Demographic and Health Survey 2024"
```

- [ ] **Step 4: Add a concise README**

Document the two roots, required R packages, the bundled Node dependency, `run_pilot.ps1` usage, default no-overwrite behavior, output paths, and the fact that the model repository is read-only.

- [ ] **Step 5: Verify the scaffold**

Run:

```powershell
Get-ChildItem -Recurse -File | Select-Object FullName,Length
```

Expected: the CSV, README, and two non-empty templates exist; no model-repository file changed.

### Task 2: Resolve, validate, and normalize final estimates with TDD

**Files:**
- Create: `tests/testthat/helper-load.R`
- Create: `tests/testthat/test-final-estimates.R`
- Create: `R/cc_paths.R`
- Create: `R/final_estimates.R`
- Create: `R/profile_data.R`

- [ ] **Step 1: Write the failing path-resolution tests**

`tests/testthat/helper-load.R` must define `exporter_root`, `model_root`, and source the three R modules. `test-final-estimates.R` must initially assert:

```r
test_that("configured benchmarked results resolve without guessing", {
  info <- read_country_info(model_root, "DR_Congo")
  expect_match(selected_result_path(model_root, info, "adm2", "u5"),
               "DR_Congo_res_adm2_unstrat_u5_allsurveys_bench[.]rda$")
  info_ng <- read_country_info(model_root, "Nigeria")
  expect_error(selected_result_path(model_root, info_ng, "adm2", "u5"),
               "Admin-2 is not configured")
})
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
& $RscriptPath -e "testthat::test_file('tests/testthat/test-final-estimates.R')"
```

Expected: FAIL because `read_country_info()` and `selected_result_path()` do not exist.

- [ ] **Step 3: Implement portable path and result selection helpers**

`R/cc_paths.R` must implement:

```r
read_country_info <- function(model_root, country) {
  path <- file.path(model_root, "Info", paste0(country, "_general_info.json"))
  if (!file.exists(path)) stop("Missing country configuration: ", path, call. = FALSE)
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

configured_admin_levels <- function(info) {
  c("adm1", if (!is.null(info[["poly.layer.adm2"]])) "adm2")
}

selected_result_path <- function(model_root, info, level, outcome) {
  stopifnot(level %in% c("adm1", "adm2"), outcome %in% c("u5", "nmr"))
  if (!level %in% configured_admin_levels(info))
    stop("Admin-2 is not configured for ", info$country, call. = FALSE)
  fm <- info$final_model
  allsurveys <- if (identical(fm[["strata.model"]], "unstrat")) "_allsurveys" else ""
  bench <- if (identical(fm[["bench.model"]], "bench")) "_bench" else ""
  stem <- paste0(info$country, "_res_", level, "_", fm[["strata.model"]],
                 "_", outcome, allsurveys, bench, ".rda")
  timed <- sub(paste0("_", fm[["strata.model"]], "_"),
               paste0("_", fm[["time.model"]], "_", fm[["strata.model"]], "_"), stem)
  directory <- file.path(model_root, "Results", info$country, "Betabinomial",
                         if (outcome == "u5") "U5MR" else "NMR")
  hits <- file.path(directory, c(timed, stem))
  hits <- unique(hits[file.exists(hits)])
  if (length(hits) != 1L)
    stop("Expected exactly one selected result; found ", length(hits), call. = FALSE)
  normalizePath(hits, winslash = "/", mustWork = TRUE)
}
```

- [ ] **Step 4: Run the path tests and verify GREEN**

Expected: both assertions pass.

- [ ] **Step 5: Write failing extraction and validation tests**

Add tests that call `read_final_overall()` and `normalize_profile_estimates()` and assert:

```r
expect_equal(nrow(cod_adm1_u5), 676L)
expect_equal(nrow(cod_adm2_u5), 4888L)
expect_equal(nrow(nga_adm1_u5), 988L)
expect_equal(range(cod_adm1_u5$year), c(2000, 2025))
expect_true(all(cod_adm1_u5$lower <= cod_adm1_u5$median))
expect_true(all(cod_adm1_u5$median <= cod_adm1_u5$upper))
expect_equal(sum(duplicated(cod_adm1_u5[, c("internal", "year"), with = FALSE])), 0L)
expect_equal(cod_adm1_u5$median_per_1000, round(cod_adm1_u5$median * 1000, 1))
```

- [ ] **Step 6: Run and verify RED**

Expected: FAIL because the extraction functions do not exist.

- [ ] **Step 7: Implement extraction and normalization**

`R/final_estimates.R` must load into a private environment, require exactly one object with an `overall` data frame, require `region`, `years.num`, `median`, `lower`, and `upper`, and reject missing years, non-finite estimates, inverted bounds, and duplicate region-years.

`R/profile_data.R` must load `<Country>_Amat_Names.rda`, join `Internal` to result `region`, require exact result/name set agreement, add `admin_level`, retain probability-scale columns, and add one-decimal `*_per_1000` columns. For Admin-2, it must read the configured GeoRepo layer and join its Admin-1 parent name through `NAME_1` without changing the scientific result values.

- [ ] **Step 8: Run all R unit tests and verify GREEN**

Run:

```powershell
& $RscriptPath -e "testthat::test_dir('tests/testthat', reporter='summary')"
```

Expected: 0 failures and 0 errors.

### Task 3: Render the reused 2023 map pattern with modern spatial code

**Files:**
- Create: `tests/testthat/test-profile-maps.R`
- Create: `R/profile_maps.R`

- [ ] **Step 1: Write failing legend and layout-policy tests**

Assert exact U5MR/NMR breaks, labels, colors, `should_label_regions(38) == TRUE`, and `should_label_regions(188) == FALSE`.

- [ ] **Step 2: Run and verify RED**

Expected: FAIL because `mortality_legend()` and `should_label_regions()` do not exist.

- [ ] **Step 3: Implement the fixed legend contract**

Implement `mortality_legend(indicator)` returning the exact eight labels and palette from the specification, and classify with `cut(..., right = TRUE, include.lowest = TRUE)` using `-Inf` and `Inf` outer bounds.

- [ ] **Step 4: Run and verify GREEN**

Expected: legend and label-policy tests pass.

- [ ] **Step 5: Write a failing integration test for one map**

The test prepares Nigeria U5MR and calls:

```r
out <- tempfile(fileext = ".png")
render_country_indicator_map(nga_data, nga_boundaries, "Nigeria", "U5MR", out)
expect_true(file.exists(out))
expect_gt(file.info(out)$size, 100000)
img <- png::readPNG(out)
expect_true(all(dim(img)[1:2] >= c(1200, 1800)))
```

- [ ] **Step 6: Run and verify RED**

Expected: FAIL because the renderer does not exist.

- [ ] **Step 7: Implement map rendering**

Use `sf` and `ggplot2` only for geometry. Reuse the 2023 composition: one large 2025 map left, six-column yearly facets right, fixed discrete legend, and stacked level panels. Use `ggrepel` for Admin-1 labels, omit Congo DR Admin-2 labels by the tested threshold, and draw a two-segment metric scale bar after transforming the display geometry to a metric CRS. Save with `ragg::agg_png`; Admin-1 maps are 4800×2400 pixels and two-level maps are 4800×4800 pixels at 300 DPI.

- [ ] **Step 8: Render all four pilot maps and run map tests**

Expected files:

```text
maps/DR_Congo_U5MR.png
maps/DR_Congo_NMR.png
maps/Nigeria_U5MR.png
maps/Nigeria_NMR.png
```

Expected: all tests pass and every file is non-empty.

### Task 4: Populate and verify the reused Excel templates

**Files:**
- Create: `tests/js/test_workbook_builder.mjs`
- Create: `js/build_profiles.mjs`

- [ ] **Step 1: Create the dependency junction and mark the spreadsheet edit once**

Create a `node_modules` junction pointing to the loader-provided Node packages. Immediately before the first workbook authoring command, run exactly once:

```powershell
& $NodePath 'C:\Users\yanliu\.cache\codex-runtimes\codex-primary-runtime\plugins\openai-primary-runtime\plugins\spreadsheets\skills\spreadsheets\container_tools\mark_artifact_operation_started.mjs' --operation-kind edit --expected-output-count 2 --output-format xlsx
```

- [ ] **Step 2: Write the failing Node tests**

Use `node:test` to assert `templateForLevels([1])` returns the Admin-1 template, `templateForLevels([1,2])` returns the Admin-2 template, and `workbookRows()` returns numeric year/estimate values with the exact Admin-1 and Admin-2 column layouts.

- [ ] **Step 3: Run and verify RED**

Run:

```powershell
& $NodePath --test tests/js/test_workbook_builder.mjs
```

Expected: FAIL because `build_profiles.mjs` does not exist.

- [ ] **Step 4: Implement the workbook builder**

Import each template with `SpreadsheetFile.importXlsx`. Delete `workbook.names.getItem('data_region')`. Update B3 and B6 on all relevant sheets; write estimate rows starting at B8; set years and estimates as numbers; apply `0` to year and `0.0` to estimate columns; write survey sources and the GeoRepo boundary note; embed the correct PNG at the established B8 map anchor; retain the four sheets; and export one workbook per country to the requested sibling profile folder.

The builder must use block writes, preserve template formatting, and never clear unrelated cells or drawings such as the IGME logo.

- [ ] **Step 5: Run Node unit tests and verify GREEN**

Expected: 0 failed tests.

- [ ] **Step 6: Build the two workbooks**

Expected files:

```text
../CC profile Subnational/Democratic Republic of the Congo_subnational_estimates.xlsx
../CC profile Subnational/Nigeria_subnational_estimates.xlsx
```

- [ ] **Step 7: Inspect workbook structure and errors**

For each workbook, use `workbook.inspect` to verify sheet names, key table ranges, numeric cells, two map drawings plus logo drawings where applicable, no `#REF!|#DIV/0!|#VALUE!|#NAME?|#N/A`, and no `data_region` defined name.

### Task 5: Add one-command orchestration and run manifests

**Files:**
- Create: `R/run_pilot.R`
- Create: `run_pilot.ps1`
- Create: `tests/testthat/test-run-manifest.R`

- [ ] **Step 1: Write a failing manifest test**

Assert a pilot manifest contains `run_id`, repository commit/dirty state, country/config/result/boundary inputs, validation counts, commands, outputs, SHA-256 hashes, warnings, and per-country status, while excluding microdata rows.

- [ ] **Step 2: Run and verify RED**

Expected: FAIL because manifest generation does not exist.

- [ ] **Step 3: Implement R orchestration and manifest writing**

`R/run_pilot.R` accepts `--model-root`, `--exporter-root`, and `--overwrite`; processes the two CSV-configured countries independently; writes normalized CSVs and maps; and writes a timestamped JSON manifest under `output/logs/<run-id>/`.

- [ ] **Step 4: Implement PowerShell orchestration**

`run_pilot.ps1` resolves R from `CC_RSCRIPT`, PATH, or the newest `%LOCALAPPDATA%\Programs\R\R-*\bin\Rscript.exe`; requires explicit Node and node-modules paths when not discoverable; runs the full R test suite, R pilot, Node tests, workbook builder, and verification script; and refuses overwrites unless `-Overwrite` is passed.

- [ ] **Step 5: Run tests and verify GREEN**

Expected: all R and Node tests pass.

### Task 6: Execute the pilot and perform visual QA

**Files:**
- Outputs only; do not modify estimation inputs/results.

- [ ] **Step 1: Run the pilot without overwrite**

Run `run_pilot.ps1` with the discovered Rscript and bundled Node paths. Expected: exit 0, four PNGs, two XLSX files, normalized CSVs, and one complete manifest.

- [ ] **Step 2: Verify machine contracts**

Fresh checks must confirm:

- Congo DR: 26 Admin-1 and 188 Admin-2 regions for both indicators, 2000–2025.
- Nigeria: 38 Admin-1 regions for both indicators, 2000–2025, no Admin-2 output.
- No unmatched names/geometries, duplicates, inverted bounds, non-finite estimates, or missing years.
- Workbook values reconcile to representative RDA values after ×1,000 and one-decimal rounding.

- [ ] **Step 3: Inspect all four maps**

Open every PNG at original detail. Check all years, legends, 2025 panels, scale bars, labels, geometry, whitespace, and clipping. Repair only observed defects, using a failing regression test before code changes.

- [ ] **Step 4: Render and inspect every workbook sheet**

Render all eight sheets. Confirm template branding, titles, year labels, complete estimate tables, source notes, embedded maps, and no clipping or broken formulas. Inspect representative first/middle/last data rows in each estimates sheet.

- [ ] **Step 5: Run final verification**

Run the complete R suite, complete Node suite, pilot preflight, workbook error scans, file inventory, and hash generation again. Completion requires fresh exit-0 evidence and a manifest status of `completed_no_blockers` or an explicit named blocker without presenting invalid deliverables as successful.

- [ ] **Step 6: Commit only repository documentation changes**

The exporter folder is outside the model repository and is not committed there. Verify the model repository has no new staged files beyond explicitly approved documentation.
