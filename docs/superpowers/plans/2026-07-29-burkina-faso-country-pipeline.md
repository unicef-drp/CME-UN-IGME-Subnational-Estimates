# Burkina Faso Country Pipeline Execution Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run the Burkina Faso country pipeline end to end using the 2003 and 2010 DHS surveys while explicitly excluding DHS 2021, then verify annual population weights, both BB8 model families, diagnostics, dashboard, and country summary PDF.

**Architecture:** Use `Info/Burkina_Faso_general_info.json` as the active country context. Treat DHS 2010 as the 2006-frame survey for survey-derived stratification, use DHS 2003 and 2010 in the unstratified all-survey family, materialize the existing UNICEF GeoRepo BFA pull, and rebuild population inputs from complete annual WorldPop sources.

**Tech Stack:** R 4.6.1, SUMMER, INLA, sf, terra, rdhs, Quarto-bundled Pandoc, Poppler or PyMuPDF.

---

### Task 1: Guard and configure the Burkina Faso survey policy

**Files:**
- Modify: `tests/test_info_config.R`
- Create: `tests/test_burkina_faso_pipeline_config.R`
- Modify: `Info/Burkina_Faso_general_info.json`

- [ ] **Step 1: Write the failing country configuration test**

Assert `country = Burkina_Faso`, `iso0 = BFA`, `frame_year = 2006`, `surveys_1frame = 2010`, `dhs_survey_year_start = 2000`, `survey_excluded = 2021`, `strata_weight_source = survey`, Admin-1/Admin-2 GeoRepo layers, and an unstratified benchmarked final model.

- [ ] **Step 2: Run the tests and verify the expected failure**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_burkina_faso_pipeline_config.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_info_config.R
```

Expected: failure because the active JSON does not yet contain the Burkina survey-start, exclusion, same-frame, and survey-stratification settings.

- [ ] **Step 3: Apply the minimal country configuration**

Add the four survey-policy fields to `Info/Burkina_Faso_general_info.json`, set `surveys_1frame` to `2010`, and preserve `final_model$strata.model = unstrat`.

- [ ] **Step 4: Run the focused tests and verify they pass**

Run the same two R test commands and require exit code 0.

### Task 2: Preflight raw DHS, GeoRepo, R, and WorldPop inputs

**Files:**
- Read: `Data/DHS/Burkina Faso/2003/BFBR43SV/BFBR43FL.SAV`
- Read: `Data/DHS/Burkina Faso/2003/BFGE43FL/BFGE43FL.shp`
- Read: `Data/DHS/Burkina Faso/2010/BFBR62SV/BFBR62FL.SAV`
- Read: `Data/DHS/Burkina Faso/2010/BFGE61FL/BFGE61FL.shp`
- Read: `../../Earlier Round/2025 Round Estimation/GeoRepoAPI/countries/BFA_Burkina_Faso/`
- Create: `tmp/pipeline_logs/Burkina_Faso/`

- [ ] **Step 1: Check R packages and credentials without printing secrets**

Require the preparation packages plus `jsonlite`, `terra`, `rmarkdown`, and `qpdf` or `pdftools`. Confirm the DHS credential resolver is non-empty. Reuse the verified existing GeoRepo API pull because live GeoRepo credentials are not configured.

- [ ] **Step 2: Inspect raw survey labels and coordinates**

Read both BR files with `haven::read_sav()` and both GPS shapefiles with `sf::st_read()`. Record survey years, raw `v024` labels, urban/rural labels, row counts, coordinate ranges, and missing coordinate counts.

- [ ] **Step 3: Confirm source inventories**

Require complete local BR/GPS inputs for 2003 and 2010, the two BFA GeoRepo source GeoJSON files, and all 15 local annual WorldPop Global1 archives for 2000–2014.

### Task 3: Prepare folders, GeoRepo boundaries, and DHS cluster data

**Files:**
- Create: `Data/Countries/Burkina_Faso/`
- Create/update: `Data/Countries/Burkina_Faso/Burkina_Faso_cluster_dat.rda`
- Create/update: `Data/Countries/Burkina_Faso/Burkina_Faso_cluster_dat_1frame.rda`
- Create/update: `Data/shapeFiles/georepo_BFA_shp/`
- Create: `tmp/pipeline_logs/Burkina_Faso/02_georepo.log`
- Create: `tmp/pipeline_logs/Burkina_Faso/03_data_processing.log`

- [ ] **Step 1: Load the country context and create folders**

Set `UN_SUBNATIONAL_HOME` and `UN_SUBNATIONAL_COUNTRY=Burkina_Faso`, source `Rcode/1_Preperation.R`, and confirm country data/results directories.

- [ ] **Step 2: Materialize and validate GeoRepo boundaries**

Run `Rcode/2_download_georepo_shapefiles.R`; with no live credentials it must use the existing same-ISO3 BFA GeoRepo API pull. Run `tests/test_georepo_shapefile_prep.R` and confirm normalized Admin-0/1/2 layers and metadata.

- [ ] **Step 3: Process DHS data**

Source preparation and `Rcode/3_DataProcessing_sf.R` in one R session. Require an explicit `Excluding DHS survey year(s) for Burkina_Faso: 2021` log entry and no 2021 data directory creation.

- [ ] **Step 4: Validate processed clusters**

Require full survey years exactly `2003, 2010`, same-frame survey years exactly `2010`, non-missing coordinates, and final Admin-1/Admin-2 names that are subsets of the GeoRepo layers.

### Task 4: Materialize annual WorldPop inputs and run steps 4–6

**Files:**
- Read/extract: `../../Worldpop data/Global1_2000_2020_aligned/<year>.zip`
- Create/reuse: `../../Worldpop data/Global1_2000_2020_aligned/Burkina_Faso_extracted/<year>/BFA/*.tif`
- Create/reuse: `../../Worldpop data/Global2_2015_2030/Burkina_Faso/*.tif`
- Create/update: `../../Worldpop data/Population/Burkina_Faso/bfa_u1_<year>_1km.tif`
- Create/update: `../../Worldpop data/Population/Burkina_Faso/bfa_u5_<year>_1km.tif`
- Create/update: `Data/Countries/Burkina_Faso/worldpop/adm1_weights_u1.rda`
- Create/update: `Data/Countries/Burkina_Faso/worldpop/adm1_weights_u5.rda`
- Create: `tmp/pipeline_logs/Burkina_Faso/04_direct.log`
- Create: `tmp/pipeline_logs/Burkina_Faso/05_admin_weights.log`
- Create: `tmp/pipeline_logs/Burkina_Faso/06_comparison.log`

- [ ] **Step 1: Ensure and validate annual population sources**

Call `ensure_worldpop_population_inputs()` for 2000:2025. Extract only BFA from local Global1 archives and download only missing/unreadable Global2 files. Require 104 readable source rasters.

- [ ] **Step 2: Run direct and smoothed-direct estimates**

Source preparation and `Rcode/4_Direct_SmoothDirect_sf.R`. Record Admin-2 NMR and U5MR fit availability independently.

- [ ] **Step 3: Force a complete annual weight rebuild**

Remove `ADMIN_WEIGHTS_POP_YEARS`; set `ADMIN_WEIGHTS_REBUILD_POPULATION=1` and `ADMIN_WEIGHTS_SKIP_100M_COMPARISON=1`; source preparation and `Rcode/5_Admin_Weights_sf.R`.

- [ ] **Step 4: Validate population logs, rasters, and weights**

Require 26 `Preparing 1km U1/U5` entries, zero `Interpolated` entries, zero `Downloading` entries, 52 readable aggregate rasters, complete 2000:2025 weight coverage, nonnegative finite proportions, and year-wise sums of one.

- [ ] **Step 5: Generate pre-BB8 comparisons**

Source preparation and `Rcode/6_Comparison_Plot.R`; inspect generated NMR and U5MR summary PDFs before BB8 fitting.

### Task 5: Run both BB8 model families and benchmarks

**Files:**
- Create/update: `Results/Burkina_Faso/Betabinomial/NMR/*.rda`
- Create/update: `Results/Burkina_Faso/Betabinomial/U5MR/*.rda`
- Create: `tmp/pipeline_logs/Burkina_Faso/08_bb8.log`
- Create: `tmp/pipeline_logs/Burkina_Faso/08_strat_benchmarks.log`
- Create: `tmp/pipeline_logs/Burkina_Faso/08_unstrat_benchmarks.log`

- [ ] **Step 1: Confirm survey-derived stratification**

Skip `7a_UR_prop.R` and `7b_UR_thresholding_sf.R`. Confirm 2010 same-frame clusters have usable survey stratum, urban/rural, and cluster-weight fields.

- [ ] **Step 2: Run integrated BB8 fitting**

Source preparation and `Rcode/8_10_BB8.R`. Require same-frame stratified 2010 results and all-survey unstratified 2003+2010 results for NMR and U5MR at every administrative level that fits.

- [ ] **Step 3: Run Admin-1 benchmark scripts**

Run `Rcode/8_10_Run_Admin1_Strat_Benchmarks.R` when present, then `Rcode/8_10_Run_Unstrat_Admin1_Benchmarks.R`. Reuse outputs only when they match current source models and annual weights.

- [ ] **Step 4: Validate BB8 inventories and benchmark gaps**

Confirm both model families and benchmarked Admin-1 results. Investigate U5 gaps above 5 per 1,000 or NMR gaps above 2 per 1,000. Record any attempted-but-unfitted model in `model_run_status`.

### Task 6: Generate diagnostics, dashboard, report figures, and summary PDF

**Files:**
- Create/update: `Results/Burkina_Faso/Burkina_Faso_bb8_comparison_dashboard.html`
- Create/update: `Results/Burkina_Faso/Figures/`
- Create/update: `Results/Burkina_Faso/11_CountrySummary.pdf`
- Create: `tmp/pipeline_logs/Burkina_Faso/09_comparison.log`
- Create: `tmp/pipeline_logs/Burkina_Faso/09_diagnostics.log`
- Create: `tmp/pipeline_logs/Burkina_Faso/11_report.log`
- Create: `tmp/pipeline_logs/Burkina_Faso/11_summary.log`

- [ ] **Step 1: Build comparisons and dashboard**

Source preparation and `Rcode/9_Comparison_Plot.R`; verify available direct, smoothed-direct, BB8, and benchmarked series in the dashboard inventory.

- [ ] **Step 2: Build diagnostics and final report figures**

Source preparation with `Rcode/9_Diagnostic_Plots.R`, then `Rcode/11_Report_Plot.R`. Require summary PDFs for the configured unstratified benchmarked final model.

- [ ] **Step 3: Render and visually verify the country summary**

Use the `un-subnational-country-summary-pdf` skill. Render the core and assembled PDF, then inspect pages 1, 2, and the last page for legibility, clipping, missing figures, and overlapping legends.

### Task 7: Run focused regressions and final artifact audit

**Files:**
- Read: `tests/test_georepo_shapefile_prep.R`
- Read: `tests/test_dataprocessing_survey_excluded.R`
- Read: `tests/test_bb8_benchmark_admin1_weighted_draws.R`
- Read: `tests/test_bb8_avoids_full_fit_artifacts.R`
- Create: `tmp/pipeline_logs/Burkina_Faso/final_verification.log`

- [ ] **Step 1: Run focused regression tests**

Run the Burkina configuration test, `test_info_config.R`, GeoRepo preparation test, survey-exclusion test, BB8 benchmark weighted-draw test, full-fit artifact test, and relevant manual-pipeline/path tests.

- [ ] **Step 2: Audit final artifacts**

Require non-empty cluster files, annual weights, both BB8 families, comparison/report PDFs, dashboard HTML, and `Results/Burkina_Faso/11_CountrySummary.pdf`.

- [ ] **Step 3: Review repository changes**

Inspect only Burkina-specific configuration, tests, runbook, logs, and generated artifacts. Do not stage, commit, or alter unrelated pre-existing changes.
