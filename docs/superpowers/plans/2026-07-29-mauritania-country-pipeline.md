# Mauritania Country Pipeline Execution Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run the Mauritania 2020 DHS country pipeline end to end and verify its annual population weights, direct estimates, both BB8 model families, diagnostics, dashboard, and country summary PDF.

**Architecture:** Use `Info/Mauritania_general_info.json` as the country context and execute the repository's numbered R scripts in order from the project root. Reuse the existing normalized UNICEF GeoRepo `MRT` Admin-0/1/2 pull, rebuild population inputs from the complete annual WorldPop sources, derive stratification weights from the 2020 DHS survey, and preserve both stratified same-frame and unstratified all-survey BB8 outputs.

**Tech Stack:** R 4.6.1, SUMMER, INLA, sf, terra, rdhs, Quarto-bundled Pandoc, Poppler or PyMuPDF.

---

### Task 1: Preflight Mauritania configuration and source data

**Files:**
- Read: `Info/Mauritania_general_info.json`
- Read: `Data/DHS/Mauritania/2020/MRBR71SV/MRBR71FL.SAV`
- Read: `Data/DHS/Mauritania/2020/MRGE71FL/MRGE71FL.shp`
- Read: `Data/shapeFiles/georepo_MRT_shp/georepo_download_metadata.json`
- Create: `tmp/pipeline_logs/Mauritania/`

- [ ] **Step 1: Confirm the country configuration**

Verify `country = Mauritania`, `iso0 = MRT`, `country.abbrev = mrt`, `beg.year = 2000`, `end.proj.year = 2025`, Admin-1 and Admin-2 GeoRepo layers, `surveys_1frame = 2020`, `strata_weight_source = survey`, and the configured final model.

- [ ] **Step 2: Confirm the DHS files and GeoRepo pull**

Require exactly one Births Recode `.SAV`, one complete geographic shapefile, and normalized `georepo_MRT_0/1/2` shapefile components. Confirm the GeoRepo metadata identifies Mauritania and ISO3 `MRT`.

- [ ] **Step 3: Inspect raw region labels**

Use `haven::read_sav()` to list the `v024` value labels and `sf::st_read()` to list the GeoRepo Admin-1 names. Record both lists in the preflight log; after Step 3, verify the spatially assigned final names are a subset of the GeoRepo names.

- [ ] **Step 4: Verify R packages and credentials without printing secrets**

Run the preparation package check and confirm the DHS password resolver returns a non-empty value. GeoRepo credentials are not required when the verified existing API pull is reused.

### Task 2: Materialize and validate annual WorldPop inputs

**Files:**
- Read/extract: `../../Worldpop data/Global1_2000_2020_aligned/<year>.zip`
- Create/reuse: `../../Worldpop data/Global1_2000_2020_aligned/Mauritania_extracted/<year>/MRT/*.tif`
- Create/reuse: `../../Worldpop data/Global2_2015_2030/Mauritania/*.tif`
- Create: `tmp/pipeline_logs/Mauritania/worldpop_preflight.log`

- [ ] **Step 1: Resolve the shared WorldPop root**

Source `Rcode/_supporting_scripts/project_paths.R` and use `worldpop_data_home()`. Do not assume population files are stored in the repository.

- [ ] **Step 2: Ensure all annual source rasters**

Source `Rcode/_supporting_scripts/worldpop_population_inputs.R` and call `ensure_worldpop_population_inputs()` for 2000:2025. Extract 2000-2014 from local annual archives and download only missing/unreadable 2015-2025 Global2 files.

- [ ] **Step 3: Validate the source inventory**

Open every raster with `terra::rast()` and require 104 readable inputs: four sex-age rasters for each of 26 years.

### Task 3: Prepare folders, boundaries, and DHS cluster data

**Files:**
- Create: `Data/Countries/Mauritania/`
- Create/update: `Data/Countries/Mauritania/Mauritania_cluster_dat.rda`
- Create/update: `Data/Countries/Mauritania/Mauritania_cluster_dat_1frame.rda`
- Create/update: `Data/shapeFiles/georepo_MRT_shp/Mauritania_Amat.rda`
- Create/update: `Data/shapeFiles/georepo_MRT_shp/Mauritania_Amat_Names.rda`
- Create: `tmp/pipeline_logs/Mauritania/03_data_processing.log`

- [ ] **Step 1: Load preparation context**

Run the full R 4.6.1 executable with `UN_SUBNATIONAL_COUNTRY=Mauritania`, source `Rcode/1_Preperation.R`, and confirm the country data/results directories exist.

- [ ] **Step 2: Validate GeoRepo boundaries**

Run `Rscript tests/test_georepo_shapefile_prep.R`. Reuse the existing normalized pull only after confirming Admin-0/1/2 layers are readable and correspond to ISO3 `MRT`.

- [ ] **Step 3: Run DHS data processing**

In one R session source `Rcode/1_Preperation.R` and `Rcode/3_DataProcessing_sf.R`, logging stdout and stderr. Require the success message and no processing error.

- [ ] **Step 4: Validate processed clusters**

Load both cluster files and verify the full and same-frame survey inventories are exactly `2020`; coordinates are non-missing; final Admin-1/Admin-2 names are GeoRepo names; and row, cluster, region, and survey counts are recorded.

### Task 4: Run direct estimates and annual population weights

**Files:**
- Create/update: `Results/Mauritania/Direct/`
- Create/update: `Results/Mauritania/Smooth_Direct/`
- Create/update: `../../Worldpop data/Population/Mauritania/mrt_u1_<year>_1km.tif`
- Create/update: `../../Worldpop data/Population/Mauritania/mrt_u5_<year>_1km.tif`
- Create/update: `Data/Countries/Mauritania/worldpop/adm1_weights_u1.rda`
- Create/update: `Data/Countries/Mauritania/worldpop/adm1_weights_u5.rda`
- Create: `tmp/pipeline_logs/Mauritania/04_direct.log`
- Create: `tmp/pipeline_logs/Mauritania/05_admin_weights.log`

- [ ] **Step 1: Run direct and smoothed-direct estimates**

Source preparation and `Rcode/4_Direct_SmoothDirect_sf.R` in one R session. Record independently whether Admin-2 NMR and U5MR fits are available.

- [ ] **Step 2: Force a complete annual weight rebuild**

Remove `ADMIN_WEIGHTS_POP_YEARS`; set `ADMIN_WEIGHTS_REBUILD_POPULATION=1` and `ADMIN_WEIGHTS_SKIP_100M_COMPARISON=1`; source preparation and `Rcode/5_Admin_Weights_sf.R`.

- [ ] **Step 3: Validate the population build log and raster inventory**

Require 26 `Preparing 1km U1/U5` entries, zero `Interpolated` entries, and zero `Downloading` entries in the Step 5 log. Require 52 readable aggregate rasters: U1 and U5 for every year from 2000 through 2025.

- [ ] **Step 4: Validate weight tables**

Load Admin-1 U1 and U5 weight files, require complete 2000:2025 coverage, finite nonnegative weights, and year-wise proportions summing to one.

- [ ] **Step 5: Generate pre-BB8 comparisons**

Source preparation and `Rcode/6_Comparison_Plot.R`; inspect the generated NMR and U5MR summary PDFs before model fitting.

### Task 5: Run both BB8 model families and benchmarks

**Files:**
- Create/update: `Results/Mauritania/Betabinomial/NMR/*.rda`
- Create/update: `Results/Mauritania/Betabinomial/U5MR/*.rda`
- Create: `tmp/pipeline_logs/Mauritania/08_bb8.log`
- Create: `tmp/pipeline_logs/Mauritania/08_unstrat_benchmarks.log`

- [ ] **Step 1: Confirm survey-derived stratification**

Because `strata_weight_source = survey`, skip `7a_UR_prop.R` and `7b_UR_thresholding_sf.R`. Confirm the 2020 same-frame DHS has usable survey stratum, urban/rural, and cluster-weight fields.

- [ ] **Step 2: Run integrated BB8 fitting**

Source preparation and `Rcode/8_10_BB8.R`. Require same-frame stratified results and all-survey unstratified results for NMR and U5MR at every administrative level that can be fitted.

- [ ] **Step 3: Ensure Admin-1 all-survey benchmarks**

Source preparation and `Rcode/8_10_Run_Unstrat_Admin1_Benchmarks.R`. Existing result files may be reused only when they match the current population weights and source model outputs.

- [ ] **Step 4: Validate BB8 inventories and benchmark gaps**

List every result file, confirm both model families are present, and compare benchmarked population-weighted Admin-1 aggregates with IGME. Investigate U5 gaps above 5 per 1,000 or NMR gaps above 2 per 1,000. If a requested model cannot fit, record a structured `model_run_status` entry instead of fabricating output.

### Task 6: Generate diagnostics, dashboard, report figures, and summary PDF

**Files:**
- Create/update: `Results/Mauritania/Mauritania_bb8_comparison_dashboard.html`
- Create/update: `Results/Mauritania/Figures/`
- Create/update: `Results/Mauritania/11_CountrySummary.pdf`
- Create: `tmp/pipeline_logs/Mauritania/09_comparison.log`
- Create: `tmp/pipeline_logs/Mauritania/09_diagnostics.log`
- Create: `tmp/pipeline_logs/Mauritania/11_report.log`
- Create: `tmp/pipeline_logs/Mauritania/11_summary.log`

- [ ] **Step 1: Build comparisons and dashboard**

Source preparation and `Rcode/9_Comparison_Plot.R`. Confirm available direct, smoothed-direct, BB8, and benchmarked series appear in the dashboard inventory.

- [ ] **Step 2: Build model diagnostics and final report figures**

Source preparation with `Rcode/9_Diagnostic_Plots.R`, then with `Rcode/11_Report_Plot.R`. Confirm `Results/Mauritania/Figures/Summary` contains the selected final-model PDFs.

- [ ] **Step 3: Render the country summary**

Set `RSTUDIO_PANDOC=C:\Program Files\Quarto\bin\tools`, load Mauritania context, and render `Rcode/11_CountrySummary.Rmd` to `Results/Mauritania/11_CountrySummary.pdf`.

- [ ] **Step 4: Visually verify the PDF**

Render pages 1, 2, and the last page to PNG. Confirm plausible page count, legible title/tables/text, no clipped or missing figures, no overlapping legends, and a rendered last-page Admin trend plot.

### Task 7: Run regression tests and final artifact audit

**Files:**
- Read: `tests/test_georepo_shapefile_prep.R`
- Read: `tests/test_bb8_benchmark_admin1_weighted_draws.R`
- Read: `tests/test_bb8_avoids_full_fit_artifacts.R`
- Create: `tmp/pipeline_logs/Mauritania/final_verification.log`

- [ ] **Step 1: Run required focused tests**

Run `tests/test_georepo_shapefile_prep.R`, `tests/test_bb8_benchmark_admin1_weighted_draws.R`, `tests/test_bb8_avoids_full_fit_artifacts.R`, `tests/test_info_config.R`, and the relevant country-path/manual-pipeline regression tests.

- [ ] **Step 2: Audit final artifacts**

Require non-empty cluster files, annual weight files, both BB8 families, comparison/report PDFs, the dashboard HTML, and `Results/Mauritania/11_CountrySummary.pdf`.

- [ ] **Step 3: Review repository changes**

Inspect Mauritania-specific generated files and selector/config changes without staging or committing. Preserve all pre-existing user modifications.
