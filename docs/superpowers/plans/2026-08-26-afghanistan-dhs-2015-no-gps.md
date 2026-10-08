# Afghanistan DHS 2015 No-GPS Admin-1 Implementation Plan

> **For agentic workers:** Execute the tasks in order and preserve unrelated changes in the existing dirty worktree.

**Goal:** Add DHS 2015 to Afghanistan's all-survey Admin-1 pipeline through validated `v024` province assignment, keep MICS 2023 as the same-frame-only input, and regenerate the final unstratified report.

**Architecture:** Introduce a configuration-driven births-recode Admin-1 fallback in a small supporting helper. Keep the existing births+GPS DHS path unchanged. Use the full cluster file for all-survey unstratified BB8 and the existing `surveys_1frame` filter for MICS-only stratified fits.

**Tech Stack:** R 4.6.1, rdhs, haven, SUMMER, INLA/BB8, GeoRepo shapefiles, R Markdown/PDF.

---

### Task 1: Specify and test the no-GPS DHS contract

**Files:**
- Create: `tests/test_dhs_admin1_recode_assignment.R`
- Modify: `Info/Afghanistan_general_info.json`
- Modify: `tests/test_afghanistan_mics_2023_preprocessing.R`

- [x] Add a focused failing test for births-only API selection, labelled province extraction, aliases, complete GeoRepo coverage, and unmatched-label rejection.
- [x] Add Afghanistan's explicit DHS 2015 `v024` fallback configuration and six name aliases.
- [x] Correct the Afghanistan preprocessing test to require the agreed final unstratified model.
- [x] Run the focused tests and retain the failing result before implementation.

### Task 2: Implement the shared, config-driven fallback

**Files:**
- Create: `Rcode/_supporting_scripts/dhs_admin1_recode.R`
- Modify: `Rcode/3_DataProcessing_sf.R`

- [x] Implement pure helpers for configuration lookup, survey selection, labelled Admin-1 extraction, aliasing, GeoRepo validation, and Admin-1 column attachment.
- [x] Include explicitly configured births-only DHS surveys during API selection.
- [x] Allow the file preflight and processing loop to proceed without a geographic dataset only for configured surveys.
- [x] Assign missing coordinate columns and validated GeoRepo Admin-1 fields in the fallback branch.
- [x] Keep the existing geographic-data branch behavior unchanged.
- [x] Run focused and shared configuration tests.

### Task 3: Rebuild Afghanistan survey inputs

**Files:**
- Regenerate: `Data/Countries/Afghanistan/Afghanistan_cluster_dat.rda`
- Regenerate: `Data/Countries/Afghanistan/Afghanistan_cluster_dat_1frame.rda`
- Regenerate: `Data/Countries/Afghanistan/Afghanistan_age_int_priors_bench.rda`

- [x] Inventory and back up Afghanistan artifacts that will be replaced.
- [x] Run data processing with the downloaded DHS 2015 births recode and existing MICS 2023 input.
- [x] Verify the complete dataset contains survey years 2015 and 2023.
- [x] Verify the same-frame dataset contains only 2023.
- [x] Verify DHS rows cover all 34 GeoRepo provinces and have intentionally missing coordinates.

### Task 4: Refit downstream Admin-1 models

**Files:**
- Regenerate: `Results/Afghanistan/Betabinomial/**`
- Regenerate: downstream direct, diagnostic, comparison, and summary artifacts

- [x] Back up stale MICS-only BB8 results before refitting.
- [x] Run the country pipeline in production with Admin-1-only scope.
- [x] Verify same-frame stratified result metadata contains MICS 2023 only where represented.
- [x] Verify all-survey unstratified results were fit after the rebuilt full cluster data and select DHS 2015 plus MICS 2023.
- [x] Verify benchmarked Admin-1 NMR and U5MR all-survey outputs are readable and complete.

### Task 5: Regenerate and verify deliverables

**Files:**
- Regenerate: `Results/Afghanistan/dashboard.html`
- Regenerate: `Results/Afghanistan/11_CountrySummary.pdf`
- Create: `Results/Afghanistan/logs/<run-id>/pipeline_manifest.json`

- [x] Run report plots, dashboard generation, and summary rendering with final model `ar1/unstrat/bench`.
- [x] Confirm the report resolves `_unstrat_*_allsurveys_bench` Admin-1 results.
- [x] Render representative PDF pages and inspect titles, tables, plots, clipping, blanks, and final comparison pages.
- [x] Run focused tests plus relevant pipeline regression tests.
- [x] Record input hashes, commands, backups, survey inventories, result hashes, warnings, and verification evidence in the run manifest.
