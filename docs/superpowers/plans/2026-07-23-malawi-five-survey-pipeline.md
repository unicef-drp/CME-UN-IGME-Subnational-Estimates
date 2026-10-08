# Malawi Five-Survey Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure and run Malawi with DHS 2004, 2010, 2015-16, and 2024 plus MICS 2019-20, using DHS 2024 and MICS 2019-20 as the shared 2018-frame surveys.

**Architecture:** Keep `Info/Malawi_general_info.json` as the runtime source of truth and keep its archived R generator consistent. Use the existing DHS start-year and survey-exclusion mechanisms to produce the exact all-survey set, then run the numbered country pipeline with survey-derived stratification because no Malawi 2018 urban-frame CSV is present.

**Tech Stack:** R, JSON, DHS/MICS survey inputs, GeoRepo, WorldPop, SUMMER, INLA, R Markdown.

---

### Task 1: Lock the Malawi survey configuration

**Files:**
- Create: `tests/test_malawi_pipeline_config.R`
- Modify: `Info/Malawi_general_info.json`
- Modify: `Info/Archive/Malawi_create_info.R`
- Modify: `tests/test_info_config.R`

- [ ] **Step 1: Write the failing Malawi configuration test**

Read the JSON with `jsonlite::fromJSON()` and assert `frame_year == 2018`, `surveys_1frame == c(2020, 2024)`, `dhs_survey_year_start == 2004`, `survey_excluded == 2014`, and `strata_weight_source == "survey"`.

- [ ] **Step 2: Run the test and verify RED**

Run: `Rscript tests/test_malawi_pipeline_config.R`

Expected: failure because the current JSON has both 2008 and 2018 frames and has no survey selection settings.

- [ ] **Step 3: Apply the minimal configuration changes**

Set the five fields in the JSON and archived generator. Add the new Malawi frame and shared-survey expectations to `tests/test_info_config.R`.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `Rscript tests/test_malawi_pipeline_config.R` and `Rscript tests/test_info_config.R`.

Expected: both exit with status 0.

### Task 2: Prepare and process survey inputs

**Files:**
- Use: `Data/MICS/Malawi/mwi.2020.tmp.rda`
- Generate: `Data/Countries/Malawi/Malawi_cluster_dat.rda`
- Generate: `Data/Countries/Malawi/Malawi_cluster_dat_1frame.rda`

- [ ] **Step 1: Run folder and GeoRepo preparation**

Run Steps 1 and 2 with `UN_SUBNATIONAL_COUNTRY=Malawi` and verify normalized MWI Admin-0/1/2 layers.

- [ ] **Step 2: Run data processing**

Run `Rcode/3_DataProcessing_sf.R` in the prepared Malawi context.

- [ ] **Step 3: Verify survey membership**

Load both cluster files. Require all-survey years `c(2004, 2010, 2015, 2020, 2024)` and shared-frame years `c(2020, 2024)`.

### Task 3: Run direct estimates and annual population weights

**Files:**
- Generate: `Results/Malawi/Direct/*`
- Generate: `Results/Malawi/SmoothDirect/*`
- Generate: `Data/Countries/Malawi/worldpop/*`

- [ ] **Step 1: Run Step 4**

Run direct and smoothed-direct models and record any structured sparse-data failure.

- [ ] **Step 2: Verify annual WorldPop sources**

Require four readable source rasters for every year 2000-2025.

- [ ] **Step 3: Rebuild annual weights**

Clear `ADMIN_WEIGHTS_POP_YEARS`, set `ADMIN_WEIGHTS_REBUILD_POPULATION=1` and `ADMIN_WEIGHTS_SKIP_100M_COMPARISON=1`, then run Step 5.

- [ ] **Step 4: Verify weight coverage**

Require 26 years in Admin-1 and Admin-2 U1/U5 weights, proportions summing to one by year, and no interpolation or download entries in the log.

### Task 4: Run both BB8 families and reporting

**Files:**
- Generate: `Results/Malawi/Betabinomial/*`
- Generate: `Results/Malawi/Malawi_bb8_comparison_dashboard.html`
- Generate: `Results/Malawi/11_CountrySummary.pdf`

- [ ] **Step 1: Run pre-BB8 comparisons**

Run Step 6 and inspect generated summary inventories.

- [ ] **Step 2: Run survey-derived stratified and all-survey unstratified BB8**

Skip Steps 7a/7b because `strata_weight_source` is `survey`. Run `8_10_BB8.R`, stratified Admin-1 benchmarks, unstratified all-survey Admin-1 base, and unstratified Admin-1 benchmarks.

- [ ] **Step 3: Generate comparisons and diagnostics**

Run Steps 9-11 and verify both model families are discoverable.

- [ ] **Step 4: Render the summary**

Render `Rcode/11_CountrySummary.Rmd` and assemble `Results/Malawi/11_CountrySummary.pdf` using the country-summary PDF workflow.

### Task 5: Final verification

**Files:**
- Verify: `Info/Malawi_general_info.json`
- Verify: `Data/Countries/Malawi/*`
- Verify: `Results/Malawi/*`

- [ ] **Step 1: Run required tests**

Run the Malawi configuration test, general info test, GeoRepo test, MICS tmp-selection test, annual-weight tests, and BB8 benchmark/artifact tests.

- [ ] **Step 2: Verify output inventories and benchmark gaps**

Confirm both BB8 families, dashboard, report figures, and summary PDF exist; compare population-weighted Admin-1 aggregates with IGME using the configured guardrails.

- [ ] **Step 3: Inspect the scoped diff**

Run `git diff --check` and inspect only the Malawi configuration, its tests, and this plan. Do not stage or commit user-owned work.
