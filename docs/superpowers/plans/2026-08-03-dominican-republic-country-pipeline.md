# Dominican Republic Country Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure and run the Dominican Republic production pipeline with DHS 2007 and DHS 2013, producing verified Admin-1 and attempted Admin-2 estimates without silently suppressing sparse Admin-2 outputs.

**Architecture:** Use `Info/Dominican_Republic_general_info.json` as the source of truth, UNICEF GeoRepo `DOM` Admin-0/1/2 layers as boundaries, DHS 2013 as the latest-frame survey-derived stratified family, and both DHS rounds in the all-survey unstratified family. Treat the benchmarked unstratified final model as provisional until the Step 9 comparison is reviewed; do not proceed with a different report model without explicit approval.

**Tech Stack:** R 4.6.1, SUMMER, INLA, sf, terra, haven, rdhs, survey-derived stratum weights, GeoRepo, WorldPop, rmarkdown/Pandoc, qpdf, and PyMuPDF.

---

### Task 1: Guard and create the Dominican Republic configuration

**Files:**
- Create: `tests/test_dominican_republic_pipeline_config.R`
- Modify: `tests/test_info_config.R`
- Create: `Info/Dominican_Republic_general_info.json`

- [ ] **Step 1: Write the focused failing test**

Create a test that loads `Info/Dominican_Republic_general_info.json` and requires country `Dominican_Republic`, ISO3 `DOM`, abbreviation `dom`, GeoRepo Admin-0/1/2 layers and name fields, years 2000–2025, frame years 2002/2010, same-frame survey 2013, DHS start year 2007, survey-derived strata, no HIV adjustment, and a provisional benchmarked unstratified final model.

- [ ] **Step 2: Verify RED**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_dominican_republic_pipeline_config.R
```

Expected: failure because `Info/Dominican_Republic_general_info.json` does not exist.

- [ ] **Step 3: Create the minimal JSON and all-country expectations**

Create the country JSON with `frame_year = [2002, 2010]`, `surveys_1frame = 2013`, `dhs_survey_year_start = 2007`, `strata_weight_source = "survey"`, and GeoRepo Admin-2 enabled. Add the exact frame and same-frame expectations to `tests/test_info_config.R`.

- [ ] **Step 4: Verify GREEN**

Run the focused test and `tests/test_info_config.R`; require exit code 0 from both.

### Task 2: Prepare folders, GeoRepo boundaries, and survey clusters

**Files:**
- Create: `Data/Countries/Dominican_Republic/`
- Create: `Data/shapeFiles/georepo_DOM_shp/`
- Create: `Results/Dominican_Republic/logs/<run-id>/pipeline_manifest.json`
- Create/update: `Data/Countries/Dominican_Republic/Dominican_Republic_cluster_dat.rda`
- Create/update: `Data/Countries/Dominican_Republic/Dominican_Republic_cluster_dat_1frame.rda`

- [ ] **Step 1: Run preparation**

Load the JSON through `Rcode/1_Preperation.R` with `UN_SUBNATIONAL_COUNTRY=Dominican_Republic`. Require country/ISO match, projection years 2000–2025, Admin-2 present, and new data/results directories.

- [ ] **Step 2: Download and normalize GeoRepo layers**

Run `Rcode/2_download_georepo_shapefiles.R` through its `main()` entry. Require readable, valid Admin-0/1/2 layers whose normalized fields include `NAME_1` and `NAME_2`, and record feature counts/hierarchy in the manifest.

- [ ] **Step 3: Run the GeoRepo regression**

Run `tests/test_georepo_shapefile_prep.R` and require exit code 0.

- [ ] **Step 4: Process both DHS rounds**

Source preparation and `Rcode/3_DataProcessing_sf.R` in one R session. Require full-survey years exactly 2007/2013 and same-frame years exactly 2013.

- [ ] **Step 5: Validate processed clusters**

Require finite DHS coordinates, populated weights and urban/rural values, exact GeoRepo Admin-1/Admin-2 matches, readable adjacency/name artifacts, and no excluded or unexpected survey year.

### Task 3: Run direct estimates, population weights, and pre-BB8 review

**Files:**
- Create/update: `Results/Dominican_Republic/Direct/`
- Create/update: `Results/Dominican_Republic/Figures/Direct/`
- Create/update: `Results/Dominican_Republic/Figures/SmoothedDirect/`
- Create/update: `Data/Countries/Dominican_Republic/worldpop/*.rda`
- Create/update: `Results/Dominican_Republic/Figures/Summary/`

- [ ] **Step 1: Run direct and smoothed-direct estimates**

Run `Rcode/4_Direct_SmoothDirect_sf.R`. Require national and Admin-1 NMR/U5MR outputs. Record Admin-2 NMR and U5MR availability independently; classify sparse optional fits as `attempted_not_fitted` only with evidence.

- [ ] **Step 2: Validate annual WorldPop inputs**

Resolve four sex-age inputs for every year 2000–2025 using `ensure_worldpop_population_inputs()`. Require all 104 rasters to open with `terra::rast()` before production weights.

- [ ] **Step 3: Build Admin-1 and Admin-2 population weights**

Leave `ADMIN_WEIGHTS_POP_YEARS` unset and run `Rcode/5_Admin_Weights_sf.R`. Require finite nonnegative weights covering 2000–2025 and summing to one by year and level for U1 and U5.

- [ ] **Step 4: Generate and inspect pre-BB8 comparisons**

Run `Rcode/6_Comparison_Plot.R`; inspect NMR/U5MR coverage, aggregation, missing series, discontinuities, and uncertainty before BB8.

### Task 4: Fit and compare supported BB8 families

**Files:**
- Create/update: `Results/Dominican_Republic/Betabinomial/NMR/*.rda`
- Create/update: `Results/Dominican_Republic/Betabinomial/U5MR/*.rda`
- Create/update: `Results/Dominican_Republic/Dominican_Republic_bb8_comparison_dashboard.html`

- [ ] **Step 1: Confirm survey-derived stratification**

Skip Steps 7a/7b because `strata_weight_source = "survey"`. Require the DHS 2013 same-frame clusters to contain usable survey strata, urban/rural values, and cluster weights.

- [ ] **Step 2: Run integrated BB8 fitting**

Run `Rcode/8_10_BB8.R`. Require supported NMR/U5MR families at Admin-1 and attempt Admin-2. Do not suppress a required family or edit saved outputs to create agreement.

- [ ] **Step 3: Run only applicable benchmark recovery**

Run `Rcode/8_10_Run_Unstrat_Admin1_Benchmarks.R` only if the integrated run did not already create the all-survey Admin-1 benchmark outputs.

- [ ] **Step 4: Build and review Step 9 comparisons**

Run `Rcode/9_Comparison_Plot.R`; inventory available families and investigate population-weighted Admin-1 gaps above 5 per 1,000 U5MR or 2 per 1,000 NMR. If the provisional final model is not analytically acceptable, stop for explicit model approval.

### Task 5: Generate diagnostics, reports, and verified summary

**Files:**
- Create/update: `Results/Dominican_Republic/Figures/`
- Create/update: `Results/Dominican_Republic/11_CountrySummary.pdf`
- Update: `Results/Dominican_Republic/logs/<run-id>/pipeline_manifest.json`

- [ ] **Step 1: Generate diagnostics and report plots**

Run `Rcode/9_Diagnostic_Plots.R` and `Rcode/11_Report_Plot.R` only after the exact final family exists and the Step 9 model review has no unresolved blocker.

- [ ] **Step 2: Render and assemble the country summary**

Render `Rcode/11_CountrySummary.Rmd`, then run the current-only or previous-final appendix path from `Rcode/12_Previous_Final_Comparison.R` as applicable.

- [ ] **Step 3: Verify the PDF and generated artifacts**

Use the `un-subnational-country-summary-pdf` skill, verify page counts and appendix placement, and inspect every page plus representative first/middle/last plots for clipping, blanks, labels, legends, and overlap.

- [ ] **Step 4: Run final regressions and record status**

Run the focused config test, `tests/test_info_config.R`, `tests/test_georepo_shapefile_prep.R`, and focused regressions for each exercised branch. Record commands, exits, artifacts, warnings, blockers, and one pipeline completion state in the manifest. Preserve all unrelated worktree changes and do not stage or commit.
