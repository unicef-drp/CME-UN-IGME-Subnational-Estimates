# DR Congo Country Pipeline Execution Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run the DR Congo pipeline end to end with DHS 2007, DHS 2013, MICS 2018, and DHS 2023, producing verified Admin-1 and available Admin-2 estimates, both BB8 model families, diagnostics, dashboard, and a country summary with a current-only sub-area appendix.

**Architecture:** Use `Info/DR_Congo_general_info.json` as the active source of truth and the verified UNICEF GeoRepo `COD` pull as the boundary source. Use DHS 2023 as the single-survey, survey-derived stratified family and all four surveys in the unstratified all-survey family selected for the final report. Recode the non-geospatial MICS 2018 province labels to exact GeoRepo Admin-1 names before processing.

**Tech Stack:** R 4.6.1, SUMMER, INLA, sf, terra, haven, rdhs, survey-derived stratum weights, Quarto-bundled Pandoc, qpdf, and PyMuPDF.

---

### Task 1: Guard and configure the DR Congo survey policy

**Files:**
- Create: `tests/test_dr_congo_pipeline_config.R`
- Modify: `tests/test_info_config.R`
- Modify: `Info/DR_Congo_general_info.json`

- [ ] **Step 1: Write the failing country configuration test**

Assert `country = DR_Congo`, `iso0 = COD`, `country.abbrev = cod`, projection years `2000:2025`, GeoRepo Admin-0/1/2 layers and labels, `surveys_1frame = 2023`, `dhs_survey_year_start = 2000`, `strata_weight_source = survey`, and an unstratified benchmarked final model.

- [ ] **Step 2: Run the focused tests and verify the expected failure**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_dr_congo_pipeline_config.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_info_config.R
```

Expected: failure because the active JSON lacks Admin-2, survey-start, same-frame, and survey-stratification settings.

- [ ] **Step 3: Apply the minimal active configuration**

Add `poly.layer.adm2 = georepo_COD_2`, retain `frame_year = 2003`, set `surveys_1frame = 2023`, set `dhs_survey_year_start = 2000`, and set `strata_weight_source = survey`. Preserve `final_model$strata.model = unstrat` and `final_model$bench.model = bench`.

- [ ] **Step 4: Update the all-country expectations and rerun**

Add `DR_Congo = 2023` to `expected_surveys_1frame` in `tests/test_info_config.R`, then rerun both commands and require exit code 0.

### Task 2: Recode and verify MICS 2018 against GeoRepo

**Files:**
- Modify: `Rcode/_script_for_specific_tasks/MICS_DataProcessing.R`
- Create: `tests/test_dr_congo_mics_2018_georepo_names.R`
- Update: `Data/MICS/DR_Congo/cod.2018.tmp.rda`

- [ ] **Step 1: Write the failing GeoRepo-name test**

Load the prepared MICS file and the normalized GeoRepo Admin-1 layer. Require all 26 MICS province names to be exact GeoRepo `NAME_1` values, with `Equateur`, `Kasai`, `Kasai Central`, `Kasai Oriental`, and `Kongo Central` present and their accented or differently hyphenated variants absent.

- [ ] **Step 2: Run the test and verify the expected mismatch**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_dr_congo_mics_2018_georepo_names.R
```

Expected: failure listing the current accented/hyphenated MICS names.

- [ ] **Step 3: Update the DR Congo preprocessing block**

Recode the five differing MICS labels to exact GeoRepo names, preserving survey year 2018, urban/rural values, cluster weights, and the no-GPS coordinate convention.

- [ ] **Step 4: Regenerate only the DR Congo block**

Run only the DR Congo section of `MICS_DataProcessing.R`, not the whole multi-country script. Reload `cod.2018.tmp.rda`; require 77,495 rows, survey year 2018, both urban/rural values, and 26 exact GeoRepo Admin-1 names.

- [ ] **Step 5: Rerun the GeoRepo-name test**

Require exit code 0.

### Task 3: Prepare folders, boundaries, and processed survey clusters

**Files:**
- Create: `Data/Countries/DR_Congo/`
- Create: `Data/shapeFiles/georepo_COD_shp/`
- Create/update: `Data/Countries/DR_Congo/DR_Congo_cluster_dat.rda`
- Create/update: `Data/Countries/DR_Congo/DR_Congo_cluster_dat_1frame.rda`
- Create: `tmp/pipeline_logs/DR_Congo/02_georepo.log`
- Create: `tmp/pipeline_logs/DR_Congo/03_data_processing.log`

- [ ] **Step 1: Load preparation and create the country folders**

Set `UN_SUBNATIONAL_HOME` to the project root and `UN_SUBNATIONAL_COUNTRY=DR_Congo`, then source `Rcode/1_Preperation.R`.

- [ ] **Step 2: Materialize the verified GeoRepo pull**

Set `GEOREPO_EXISTING_PULL_DIR` to `Earlier Round/2025 Round Estimation/GeoRepoAPI/countries/COD_Congo_DR`, run `Rcode/2_download_georepo_shapefiles.R`, and require readable normalized Admin-0/1/2 layers with 26 and 188 Admin-1/Admin-2 features.

- [ ] **Step 3: Run the GeoRepo regression**

Run `tests/test_georepo_shapefile_prep.R` and require exit code 0.

- [ ] **Step 4: Process DHS and MICS data**

Source preparation and `Rcode/3_DataProcessing_sf.R` in one R session. Require DHS 2007/2013/2023 plus MICS 2018 in the full cluster file and only DHS 2023 in the same-frame file.

- [ ] **Step 5: Validate processed data**

Require DHS coordinates to be finite, MICS coordinates to be `NA`, MICS Admin-1 names to match GeoRepo, DHS Admin-1/Admin-2 names to match GeoRepo, and survey types/urban labels/cluster weights to be populated.

### Task 4: Prepare annual WorldPop inputs and run direct estimates

**Files:**
- Read/extract: `../../Worldpop data/Global1_2000_2020_aligned/<year>.zip`
- Create/reuse: `../../Worldpop data/Global1_2000_2020_aligned/DR_Congo_extracted/<year>/COD/*.tif`
- Create/reuse: `../../Worldpop data/Global2_2015_2030/DR_Congo/*.tif`
- Create: `tmp/pipeline_logs/DR_Congo/worldpop_preflight.log`
- Create: `tmp/pipeline_logs/DR_Congo/04_direct.log`

- [ ] **Step 1: Ensure complete annual source rasters**

Call `ensure_worldpop_population_inputs()` for 2000:2025. Extract only COD from the 15 existing Global1 archives and download only missing/unreadable Global2 files for 2015:2025.

- [ ] **Step 2: Validate the source inventory**

Open every input with `terra::rast()` and require 104 readable source rasters: four sex-age inputs for each of 26 years.

- [ ] **Step 3: Run direct and smoothed-direct estimates**

Source preparation and `Rcode/4_Direct_SmoothDirect_sf.R`. Record Admin-2 NMR and U5MR fit availability independently and do not fabricate a missing fit.

### Task 5: Build annual population weights and pre-BB8 comparisons

**Files:**
- Create/update: `../../Worldpop data/Population/DR_Congo/cod_u1_<year>_1km.tif`
- Create/update: `../../Worldpop data/Population/DR_Congo/cod_u5_<year>_1km.tif`
- Create/update: `Data/Countries/DR_Congo/worldpop/adm1_weights_u1.rda`
- Create/update: `Data/Countries/DR_Congo/worldpop/adm1_weights_u5.rda`
- Create: `tmp/pipeline_logs/DR_Congo/05_admin_weights.log`
- Create: `tmp/pipeline_logs/DR_Congo/06_comparison.log`

- [ ] **Step 1: Force a complete annual population rebuild**

Remove `ADMIN_WEIGHTS_POP_YEARS`; set `ADMIN_WEIGHTS_REBUILD_POPULATION=1` and `ADMIN_WEIGHTS_SKIP_100M_COMPARISON=1`; source preparation and `Rcode/5_Admin_Weights_sf.R`.

- [ ] **Step 2: Validate the build log and aggregate rasters**

Require 26 `Preparing 1km U1/U5` entries, zero `Interpolated` entries, zero `Downloading` entries during Step 5, and 52 readable U1/U5 aggregates.

- [ ] **Step 3: Validate Admin-1 weights**

Require full 2000:2025 coverage, finite nonnegative proportions, and sums of one by year for U1 and U5.

- [ ] **Step 4: Generate pre-BB8 comparison plots**

Source preparation and `Rcode/6_Comparison_Plot.R`; inspect the NMR/U5MR PDFs before fitting BB8.

### Task 6: Run both BB8 families and benchmarks

**Files:**
- Create/update: `Results/DR_Congo/Betabinomial/NMR/*.rda`
- Create/update: `Results/DR_Congo/Betabinomial/U5MR/*.rda`
- Create: `tmp/pipeline_logs/DR_Congo/08_bb8.log`
- Create: `tmp/pipeline_logs/DR_Congo/08_strat_benchmarks.log`
- Create: `tmp/pipeline_logs/DR_Congo/08_unstrat_benchmarks.log`

- [ ] **Step 1: Confirm survey-derived stratification**

Skip `7a_UR_prop.R` and `7b_UR_thresholding_sf.R`. Confirm the DHS 2023 same-frame clusters provide usable survey strata, urban/rural values, and cluster weights.

- [ ] **Step 2: Run integrated BB8 fitting**

Source preparation and `Rcode/8_10_BB8.R`. Require DHS-2023 stratified results and 2007/2013/2018/2023 unstratified all-survey results for NMR and U5MR at each administrative level that fits.

- [ ] **Step 3: Run benchmark scripts**

Run the stratified Admin-1 benchmark helper when present, followed by `Rcode/8_10_Run_Unstrat_Admin1_Benchmarks.R`.

- [ ] **Step 4: Validate inventories and benchmark gaps**

Confirm both model families and benchmarked Admin-1 results. Investigate U5 national gaps above 5 per 1,000 or NMR gaps above 2 per 1,000. Record any attempted-but-unfitted model in `model_run_status`.

### Task 7: Build dashboard, diagnostics, reports, and summary PDF

**Files:**
- Create/update: `Results/DR_Congo/DR_Congo_bb8_comparison_dashboard.html`
- Create/update: `Results/DR_Congo/Figures/`
- Create/update: `Results/DR_Congo/11_CountrySummary.pdf`
- Create: `tmp/pipeline_logs/DR_Congo/09_comparison.log`
- Create: `tmp/pipeline_logs/DR_Congo/09_diagnostics.log`
- Create: `tmp/pipeline_logs/DR_Congo/11_report.log`
- Create: `tmp/pipeline_logs/DR_Congo/11_summary.log`

- [ ] **Step 1: Build comparisons and dashboard**

Source preparation and `Rcode/9_Comparison_Plot.R`; confirm available direct, smoothed-direct, BB8, and benchmarked series appear in the inventory.

- [ ] **Step 2: Build diagnostics and report figures**

Run `Rcode/9_Diagnostic_Plots.R` and `Rcode/11_Report_Plot.R` with the configured unstratified benchmarked final model.

- [ ] **Step 3: Render core and assembled summaries**

Render `Rcode/11_CountrySummary.Rmd` using Quarto-bundled Pandoc, then run `run_country_summary_comparison_appendix()`. Because COD has no previous-final rows, require `appended_current_only`, Admin-1 plus available Admin-2, and current-only artifact names.

- [ ] **Step 4: Verify PDF content and layout**

Require public page count equal to core plus appendix pages, verify no `2023 final` wording, and inspect pages 1, 2, and the last page for legibility and clipping.

### Task 8: Update the round workbook and perform final verification

**Files:**
- Modify: `../Subnational_country_list_2026.xlsx`
- Read: `tests/test_previous_final_comparison.R`
- Read: `tests/test_bb8_benchmark_admin1_weighted_draws.R`
- Read: `tests/test_bb8_avoids_full_fit_artifacts.R`
- Create: `tmp/pipeline_logs/DR_Congo/final_verification.log`

- [ ] **Step 1: Update the DR Congo workbook row**

Set `surveys_1frame` to `2023` and `all surveys 2026` to `DHS 2007, 2013, 2023; MICS 2018`, preserving workbook formatting.

- [ ] **Step 2: Run focused regressions**

Run the DR Congo configuration and MICS tests, all-country Info test, GeoRepo test, previous-final comparison test, BB8 benchmark weighted-draw test, full-fit artifact test, and manual pipeline/path tests.

- [ ] **Step 3: Audit final artifacts**

Require non-empty full/same-frame cluster files, annual weights, both BB8 families, comparisons, diagnostics, report figures, dashboard, current-only appendix, and public country summary.

- [ ] **Step 4: Preserve the shared worktree**

Review only DR Congo-specific configuration, tests, logs, generated artifacts, and workbook cells. Do not stage, commit, or modify unrelated pre-existing changes.
