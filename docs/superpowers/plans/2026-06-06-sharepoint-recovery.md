# SharePoint Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recreate the work lost from the SharePoint sync issue for the 2026 UN IGME Subnational round in the corrected workspace.

**Architecture:** Recover shared pipeline changes first, then rerun country jobs using the standard script order from `UN-Subnational-Estimates-main`. Each country should leave verifiable config, processed data, BB8 outputs for stratified and unstratified comparisons where applicable, dashboards, and summaries.

**Tech Stack:** R scripts in `Rcode/`, country configuration scripts in `Info/`, local `.rda` artifacts, DHS/MICS inputs, UNICEF GeoRepo shapefiles, BB8/SUMMER outputs, Quarto/R Markdown summary rendering, and R regression tests in `tests/`.

---

### Task 1: Confirm Correct Workspace And Surviving Assets

**Files:**
- Read: `C:/Users/yanliu/OneDrive - UNICEF/Child Mortality - Documents/UN IGME Subnational/2026 Round Subnational/UN-Subnational-Estimates-main`
- Read: `Data/`, `Info/`, `Results/`, `tests/`

- [x] **Step 1: Confirm corrected SharePoint path exists**

Run: `Get-Location`

Expected: path ends in `Child Mortality - Documents/UN IGME Subnational/2026 Round Subnational`.

- [x] **Step 2: Confirm old SharePoint path is unavailable**

Run: `Test-Path -LiteralPath 'C:\Users\yanliu\OneDrive - UNICEF\Documents - Child Mortality\UN IGME Subnational\2026 Round Subnational\UN-Subnational-Estimates-main'`

Expected: `False`.

- [x] **Step 3: Inventory surviving results**

Current survivor list under `Results/`: `Laos`, `Madagascar`, `Nigeria`.

### Task 2: Restore Shared Pipeline Changes

**Files:**
- Modify: `Info/Haiti_create_info.R`
- Modify: `Info/Benin_create_info.R`
- Modify: `Info/Cameroon_create_info.R`
- Create: `Info/Afghanistan_create_info.R`
- Modify: `Rcode/3_DataProcessing_sf.R`
- Modify: `Rcode/8_10_BB8.R`
- Modify: `Rcode/11_CountrySummary.Rmd`
- Modify: `Data/HIV/format-factors.R`
- Modify: `Rcode/_script_for_specific_tasks/MICS_DataProcessing.R`
- Test: focused R tests in `tests/`

- [x] **Step 1: Keep Haiti using 2012 and 2016 same-frame DHS surveys**

`Info/Haiti_create_info.R` includes `frame_year <- c(2011)`, `surveys_1frame <- c(2012, 2016)`, `dhs_survey_year_start <- 2005`, and `strata_weight_source <- "survey"`.

- [x] **Step 2: Add general DHS download controls**

`Rcode/3_DataProcessing_sf.R` reads DHS surveys from `dhs_survey_year_start` and uses `RDHS_USER_PASS` only as a non-interactive prompt flag.

- [x] **Step 3: Add general survey exclusion support**

`Rcode/3_DataProcessing_sf.R` applies a country-level `survey_excluded` vector to DHS selection and processed model inputs.

- [x] **Step 4: Add survey-derived stratum weights**

`Rcode/8_10_BB8.R` derives stratified weights when `strata_weight_source <- "survey"` is set in country info.

- [x] **Step 5: Make summary national comparison load the selected final model**

`Rcode/11_CountrySummary.Rmd` uses `final_model` for the national comparison plot instead of assuming all-survey unstratified files.

- [x] **Step 6: Restore HIV formatter portability and 2025 inputs**

`Data/HIV/format-factors.R` runs from `Rscript`, uses the 2025 adjustment folder, normalizes `Cote_dIvoire`, and conditionally drops national rows for Mozambique/Zimbabwe only when subnational rows exist.

### Task 3: Redo Desk Checks

**Files:**
- Create: `tmp/sampling_frame_checks.md`

- [x] **Step 1: Check Haiti DHS sampling frames**

Confirmed: 2005-06 uses the original 2003 census/SDE frame; 2012 and 2016-17 use the 2003 frame updated in 2011; 2012 also includes a post-earthquake camp frame.

- [x] **Step 2: Check Bangladesh DHS sampling frame years**

Confirmed: DHS 2017-18 and DHS 2022 use the 2011 Bangladesh Population and Housing Census EA frame.

- [x] **Step 3: Recreate MICS-without-GPS candidate list**

Saved the restored short-list candidate result under `tmp/`. The `mics_surveys_catalogue.xlsx` source workbook is missing from the corrected SharePoint tree, so this output is marked for recomputation if that workbook is restored.

### Task 4: Rerun Countries

**Files:**
- Modify: `Rcode/1_Preperation.R`
- Read/Write: `Data/<Country>/`
- Read/Write: `Results/<Country>/`
- Read/Write: `Info/<Country>_general_info.Rdata`

- [ ] **Step 1: Run Haiti**

Run DHS data processing with 2005-06, 2012, and 2016-17; use 2012 and 2016 for stratified same-frame; run unstratified all-survey for comparison; render dashboard and country summary.

Blocked locally: `Data/DHS/Haiti/` and `Data/MICS/Haiti/` exist but contain no files, and `RDHS_USER_PASS` is not set.

- [ ] **Step 2: Run Afghanistan Admin-1 MICS6**

Process MICS 2022-2023 without GPS using province labels, run Admin-1 only, and produce both stratified and unstratified outputs.

Blocked locally: `Data/MICS/Afghanistan/2022_2023/bh.sav` is not present.

- [ ] **Step 3: Run Cameroon**

Use DHS 2004 and 2011 as same-frame surveys, include DHS 2018 in all-survey unstratified comparison, and render dashboard and summary.

Blocked locally: no Cameroon DHS files are present, and `RDHS_USER_PASS` is not set.

- [ ] **Step 4: Run Benin**

Exclude DHS 2011-12 with `survey_excluded <- 2011:2012`, use DHS 2017 as the final same-frame survey, and render dashboard and summary.

Blocked locally: no Benin DHS files are present, and `RDHS_USER_PASS` is not set.

- [ ] **Step 5: Run Bangladesh Admin-1 outputs**

Run Bangladesh using the 2011 sampling-frame DHS configuration and Admin-1 deliverables.

Blocked locally: Bangladesh DHS files, especially GE datasets, are not present; only Bangladesh MICS files are present.

- [x] **Step 6: Run Angola**

Run Angola through the standard country pipeline and produce deliverables.

Completed: Angola has processed DHS 2015/2023 cluster data, stratified same-frame and unstratified all-survey Admin-1 BB8 outputs, comparison dashboard/data, report figures, and `Results/Angola/11_CountrySummary.pdf`.

- [ ] **Step 7: Run Myanmar DHS 2015-16**

Run Myanmar DHS 2015-16 through the standard country pipeline and produce deliverables.

Blocked locally: no Myanmar DHS files are present, and `RDHS_USER_PASS` is not set.

### Task 5: Final Verification

**Files:**
- Read: `Results/<Country>/Betabinomial/`
- Read: `Results/<Country>/Figures/Summary/`
- Read: `Results/<Country>/11_CountrySummary.pdf`
- Read: country dashboard HTML files

- [x] **Step 1: Run focused regression tests**

Passed:

```powershell
Rscript tests/test_haiti_sampling_frame_config.R
Rscript tests/test_dataprocessing_dhs_start_year.R
Rscript tests/test_dhs_rdhs_password_env.R
Rscript tests/test_info_config.R
Rscript tests/test_dataprocessing_survey_excluded.R
Rscript tests/test_afghanistan_mics_2023_preprocessing.R
Rscript tests/test_country_summary_uses_final_national_model.R
Rscript tests/test_hiv_formatter_2025.R
Rscript tests/test_bb8_strata_weight_fallback.R
Rscript tests/test_georepo_shapefile_prep.R
Rscript tests/test_mics_admin1_fallback.R
```

- [x] **Step 2: Confirm both BB8 model families exist for comparison countries**

For each rerun country, confirm stratified same-frame and unstratified all-survey `.rda` outputs exist under `Results/<Country>/Betabinomial/`.

- [x] **Step 3: Confirm dashboards and summaries exist**

For each rerun country, confirm the comparison dashboard and `11_CountrySummary.pdf` exist.
