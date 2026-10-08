# Ghana Admin-1 Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce Ghana's Admin-1-only BB8 comparison dashboard and country summary PDF from six surveys, with MICS 2018 assigned through its GPS dataset.

**Architecture:** Keep GeoRepo Admin-2 available through survey preprocessing, then remove Admin-2 variables from each downstream R context and set `BB8_ADMIN1_ONLY=1`. Add country-specific MICS preprocessing and deterministic temporary-artifact selection so the 2018 geospatial artifact supersedes its older non-geospatial artifact.

**Tech Stack:** R 4.6.1, SUMMER, INLA, sf, haven, terra, rmarkdown, TinyTeX, standalone R regression tests.

---

### Task 1: Lock the Ghana survey and final-model configuration

**Files:**
- Modify: `tests/test_info_config.R`
- Create: `tests/test_ghana_pipeline_config.R`
- Modify: `Info/Ghana_create_info.R`
- Modify: `Info/Ghana_general_info.json`

- [ ] **Step 1: Write the failing Ghana configuration assertions**

Add Ghana to `expected_surveys_1frame` in `tests/test_info_config.R` and create a focused test that loads the JSON and checks:

```r
stopifnot(
  isTRUE(all.equal(info$frame_year, 2010)),
  isTRUE(all.equal(info$surveys_1frame, c(2011, 2014, 2018))),
  identical(info$final_model$strata.model, "unstrat"),
  identical(info$final_model$bench.model, "bench")
)
```

- [ ] **Step 2: Run the tests and verify RED**

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_info_config.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_ghana_pipeline_config.R
```

Expected: failure because Ghana's shared-frame surveys are currently null and the JSON final model is stratified.

- [ ] **Step 3: Apply the minimal configuration**

Set the R and JSON sources to:

```r
frame_year <- c(2010)
surveys_1frame <- c(2011, 2014, 2018)
```

Keep `final_model$strata.model` equal to `unstrat` so the summary uses the benchmarked all-survey family.

- [ ] **Step 4: Run the tests and verify GREEN**

Run the commands from Step 2. Expected: both pass.

### Task 2: Prefer recursive geospatial MICS artifacts

**Files:**
- Create: `tests/test_mics_tmp_file_selection.R`
- Create: `Rcode/_supporting_scripts/mics_tmp_files.R`
- Modify: `Rcode/3_DataProcessing_sf.R`

- [ ] **Step 1: Write the failing artifact-selection test**

Build a temporary directory containing `gha.2011.tmp.rda`, `gha.2018.tmp.rda`, and `2018/gha.2018.geo.tmp.rda`; assert that selection returns the 2011 file and only the geospatial 2018 file.

- [ ] **Step 2: Run the test and verify RED**

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_mics_tmp_file_selection.R
```

Expected: failure because the selector does not exist.

- [ ] **Step 3: Implement `select_mics_tmp_files()`**

Recursively list `*.tmp.rda`, derive the survey identity from the basename, sort deterministically, and choose `*.geo.tmp.rda` whenever both variants exist for the same country/year.

- [ ] **Step 4: Use the selector in Step 3 data processing**

Source `mics_tmp_files.R` beside the existing MICS admin helpers and replace the non-recursive `list.files()` call with `select_mics_tmp_files(mics.dir)`.

- [ ] **Step 5: Run selection and empty-directory tests**

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_mics_tmp_file_selection.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_dataprocessing_skips_empty_mics_dir.R
```

Expected: both pass.

### Task 3: Build Ghana MICS 2011 and GPS-based 2018 artifacts

**Files:**
- Create: `tests/test_mics_geospatial_ghana_2018.R`
- Modify: `Rcode/_script_for_specific_tasks/MICS_Geospatial_DataProcessing.R`
- Create: `Data/MICS/Ghana/2018/GPS/GhanaMICS2017-18GPS.{cpg,dbf,prj,qmd,shp,shx}`
- Create: `Data/MICS/Ghana/2018/gha.2018.geo.tmp.rda`
- Replace: `Data/MICS/Ghana/gha.2011.tmp.rda`

- [ ] **Step 1: Write the failing Ghana preprocessing test**

Require `process_ghana_mics_geospatial`, load both artifacts, and assert survey years, non-missing 2018 coordinates, all ten GeoRepo Admin-1 names, Brong Ahafo coverage, and 660 unique 2018 clusters.

- [ ] **Step 2: Run the test and verify RED**

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_mics_geospatial_ghana_2018.R
```

Expected: failure because the Ghana function and GPS artifact do not exist and the old artifacts omit Brong Ahafo.

- [ ] **Step 3: Add Ghana-specific preprocessing**

Reuse the generic birth-history and spatial-assignment helpers. Preserve the HH7 survey label for the non-GPS 2011 artifact, recode `Asante` to `Ashanti`, and retain all ten regions. For 2018, join GPS by HH1 and assign GeoRepo polygons before saving `gha.2018.geo.tmp.rda`.

- [ ] **Step 4: Extract GPS components and create both artifacts**

Extract `GhanaMICS2017-18GPS.zip` from the shared MICS GIS directory into the survey-specific GPS folder, then run the Ghana preprocessing entry point.

- [ ] **Step 5: Run Ghana, Nigeria, and selection tests**

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_mics_geospatial_ghana_2018.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_mics_geospatial_nigeria_2021.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_mics_tmp_file_selection.R
```

Expected: all pass.

### Task 4: Process Ghana surveys and verify inventories

**Files:**
- Create: `Data/Countries/Ghana/Ghana_cluster_dat.rda`
- Create: `Data/Countries/Ghana/Ghana_cluster_dat_1frame.rda`

- [ ] **Step 1: Run preparation and data processing**

Use the existing `rdhs.json` credential inside the R process, source `1_Preperation.R`, and source `3_DataProcessing_sf.R`. Keep Admin-2 enabled for this step so all GPS joins remain available.

- [ ] **Step 2: Verify the survey sets and MICS coordinates**

Assert exact all-survey years `2003, 2008, 2011, 2014, 2018, 2022`, exact same-frame years `2011, 2014, 2018`, ten Admin-1 names, and non-missing MICS 2018 coordinates.

- [ ] **Step 3: Run boundary and data-processing tests**

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_georepo_shapefile_prep.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_mics_geospatial_ghana_2018.R
```

Expected: tests pass and artifacts contain the required inventories.

### Task 5: Run Admin-1 direct estimates, weights, and stratification inputs

**Files:**
- Create/update: `Results/Ghana/Direct/**`
- Create/update: `Data/Countries/Ghana/worldpop/**`
- Create/update: `Results/Ghana/UR/**`

- [ ] **Step 1: Run direct/smoothed-direct estimates with Admin-2 removed from context**

Load Ghana preparation, remove `poly.layer.adm2` and `poly.label.adm2`, then source `4_Direct_SmoothDirect_sf.R`.

- [ ] **Step 2: Prepare annual Admin-1 population weights**

Run `5_Admin_Weights_sf.R` with `ADMIN_WEIGHTS_SKIP_100M_COMPARISON=1`. Verify U1 and U5 weights cover 2000–2025 and sum to one by year.

- [ ] **Step 3: Run the preliminary comparison and 2010 UR frame steps**

With the same Admin-1-only context, run `6_Comparison_Plot.R`, `7a_UR_prop.R`, and `7b_UR_thresholding_sf.R` using `Data/urban_frames/gha_2010_frame_urb_prop.csv`.

### Task 6: Fit BB8 families and render deliverables

**Files:**
- Create/update: `Results/Ghana/Betabinomial/**`
- Create/update: `Results/Ghana/Ghana_bb8_comparison_dashboard.html`
- Create/update: `Results/Ghana/Figures/**`
- Create/update: `Results/Ghana/11_CountrySummary.pdf`

- [ ] **Step 1: Run BB8 and Admin-1 benchmarks**

Set `BB8_ADMIN1_ONLY=1`, remove Admin-2 context variables, run `8_10_BB8.R`, then run `8_10_Run_Unstrat_Admin1_Benchmarks.R`.

- [ ] **Step 2: Run benchmark regression tests**

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_bb8_benchmark_admin1_weighted_draws.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_bb8_avoids_full_fit_artifacts.R
```

Expected: both pass.

- [ ] **Step 3: Generate dashboard, diagnostics, and report plots**

Run `9_Comparison_Plot.R`, `9_Diagnostic_Plots.R`, and `11_Report_Plot.R` with `BB8_ADMIN1_ONLY=1`.

- [ ] **Step 4: Render and visually verify the summary PDF**

Render `Rcode/11_CountrySummary.Rmd` to `Results/Ghana/11_CountrySummary.pdf`, then use the country-summary PDF skill to render pages and inspect layout.

- [ ] **Step 5: Verify final deliverables and benchmark gaps**

Confirm the dashboard and PDF exist and are non-empty, confirm both model families appear in the inventory, and compare population-weighted benchmarked Admin-1 aggregates with IGME using the 5-per-1,000 U5 and 2-per-1,000 NMR guardrails.

