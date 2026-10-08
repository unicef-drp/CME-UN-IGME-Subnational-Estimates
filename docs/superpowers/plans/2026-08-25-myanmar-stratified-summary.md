# Myanmar Stratified Summary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Select Myanmar's existing benchmarked stratified model as final, rebuild its report plots and assembled country-summary PDF, and identify other produced countries whose included surveys all share the selected sampling frame.

**Architecture:** Treat `Info/Myanmar_general_info.json` as the authoritative model-selection change and retain all existing BB8 fits. Enforce the selection with a focused configuration test, regenerate only the downstream report artifacts, and audit saved `*_cluster_dat.rda` against `*_cluster_dat_1frame.rda` with configuration metadata to avoid interpreting an unconfigured one-frame default as proof of a shared frame.

**Tech Stack:** R 4.6.1, JSON/jsonlite, R Markdown/Pandoc/LaTeX, saved RDA model outputs, PDF rendering and page inspection.

---

### Task 1: Enforce Myanmar's final model selection

**Files:**
- Create: `tests/test_myanmar_sampling_frame_config.R`
- Modify: `Info/Myanmar_general_info.json`
- Modify: `tests/test_info_config.R`

- [ ] **Step 1: Write a focused test**

Create a test that loads Myanmar's JSON and requires the 2016 shared-frame survey, survey-derived strata weights, and `final_model$strata.model == "strat"`.

- [ ] **Step 2: Verify the test fails for the current unstratified selection**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_myanmar_sampling_frame_config.R
```

Expected: failure on the final-model assertion because the JSON currently says `unstrat`.

- [ ] **Step 3: Make the minimal configuration change**

Change only Myanmar's final strata selection from `unstrat` to `strat`, and add Myanmar to `expected_strata_models` in the shared configuration test.

- [ ] **Step 4: Verify focused and shared configuration tests pass**

Run the new Myanmar test and `tests/test_info_config.R`; both must exit zero.

### Task 2: Audit produced countries for complete shared-frame coverage

**Files:**
- Read: `Data/Countries/<Country>/<Country>_cluster_dat.rda`
- Read: `Data/Countries/<Country>/<Country>_cluster_dat_1frame.rda`
- Read: `Info/<Country>_general_info.json`

- [ ] **Step 1: Compare actual survey inventories**

For every country with a produced `11_CountrySummary.pdf`, compare unique survey identifiers and row counts in the all-survey and one-frame cluster objects.

- [ ] **Step 2: Validate the frame claim against metadata**

Require an explicit `surveys_1frame` inventory matching all included survey years, or classify a one-survey country separately. Do not treat an identical `_1frame` file caused by null frame metadata as verified multi-survey shared-frame evidence.

- [ ] **Step 3: Report current model-setting mismatches**

List countries satisfying the rule but still configured as `unstrat`; do not change their settings without a specific request.

### Task 3: Rebuild and inspect Myanmar's downstream deliverables

**Files:**
- Regenerate: `Results/Myanmar/Figures/Summary/**`
- Regenerate: `Results/Myanmar/Figures/Summary/11_CountrySummary_core.pdf`
- Regenerate: `Results/Myanmar/11_CountrySummary.pdf`

- [ ] **Step 1: Back up the existing final PDF**

Copy the current PDF into the run log directory before replacing it.

- [ ] **Step 2: Regenerate final report plots**

Load Myanmar through `Rcode/1_Preperation.R`, then source `Rcode/11_Report_Plot.R` so filenames and plots use the stratified benchmarked selection.

- [ ] **Step 3: Render the core summary and append previous-final comparison pages**

Use the pipeline runner's `render_rmd` behavior so the core and assembled public PDF remain consistent with the current production workflow.

- [ ] **Step 4: Verify artifacts and visual layout**

Confirm the PDF is non-empty, inspect page count, render pages 1, 2, a middle page, and the last page to PNG, and check titles, tables, plots, clipping, blanks, and the last-page trend plot.

- [ ] **Step 5: Record run evidence**

Save the configuration, commands, backup path, generated paths, checks, warnings, and completion status under `Results/Myanmar/logs/<run-id>/`.
