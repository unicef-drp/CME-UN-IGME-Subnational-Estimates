# Safe Manual MICS Preprocessing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent the manual country runbook from sourcing either whole MICS preprocessing script while preserving clear country-specific instructions before Step 3.

**Architecture:** Keep MICS preprocessing outside the executable runbook blocks. Replace both generic `source()` blocks with comments directing the operator to open the appropriate GPS or non-GPS script and run only the selected country's section or function.

**Tech Stack:** Base R, static standalone R regression test.

---

### Task 1: Reject whole-script MICS sourcing

**Files:**
- Modify: `tests/test_manual_country_pipeline_entrypoint.R`
- Modify: `Rcode/run_country_pipeline.R`

- [ ] **Step 1: Add the failing source-safety assertions**

Add this after the existing legacy country-info assertions in
`tests/test_manual_country_pipeline_entrypoint.R`:

```r
compact_text <- gsub("[[:space:]]+", "", text)
mics_scripts <- c(
  "MICS_DataProcessing.R",
  "MICS_Geospatial_DataProcessing.R"
)
unsafe_mics_sources <- paste0(
  'source(file.path("Rcode","_script_for_specific_tasks","',
  mics_scripts,
  '"))'
)
stopifnot(!any(vapply(
  unsafe_mics_sources,
  grepl,
  logical(1),
  x = compact_text,
  fixed = TRUE
)))
stopifnot(all(vapply(mics_scripts, grepl, logical(1), x = text, fixed = TRUE)))
stopifnot(grepl("Run only the selected country's section or function", text,
                fixed = TRUE))
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' 'tests/test_manual_country_pipeline_entrypoint.R'
```

Expected: FAIL because both compacted `source(file.path(...))` calls are present.

- [ ] **Step 3: Replace executable MICS blocks with instructions**

Replace the optional MICS section in `Rcode/run_country_pipeline.R` with:

```r
# Optional MICS preprocessing (before Step 3) ----------------------------------
# Do not source either whole preprocessing script from this runbook.
# For MICS without GPS, open:
#   Rcode/_script_for_specific_tasks/MICS_DataProcessing.R
# For MICS with GPS, open:
#   Rcode/_script_for_specific_tasks/MICS_Geospatial_DataProcessing.R
# Run only the selected country's section or function, then confirm the expected
# *.tmp.rda or *.geo.tmp.rda output exists before continuing to Step 3.
```

- [ ] **Step 4: Run focused and source-contract tests and verify GREEN**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' 'tests/test_manual_country_pipeline_entrypoint.R'
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' 'tests/test_active_pipeline_uses_json_info.R'
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' -e "parse(file='Rcode/run_country_pipeline.R')"
```

Expected: both tests pass and the runbook parses successfully.

- [ ] **Step 5: Review without committing implementation**

Run:

```powershell
git diff --check -- Rcode/run_country_pipeline.R tests/test_manual_country_pipeline_entrypoint.R
git diff -- Rcode/run_country_pipeline.R tests/test_manual_country_pipeline_entrypoint.R
```

Expected: no whitespace errors, no whole-script MICS source calls, and both script names remain in instructional comments. Leave the implementation uncommitted in the user-approved main workspace.
