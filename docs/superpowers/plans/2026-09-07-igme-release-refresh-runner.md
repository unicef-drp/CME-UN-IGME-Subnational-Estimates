# IGME Release Refresh Runner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and verify a safe country-level workflow for promoting updated IGME inputs, rerunning applicable benchmarked models, and regenerating dashboard/report deliverables.

**Architecture:** Add a small refresh-specific orchestration module and CLI while retaining `8_10_BB8.R` as the statistical authority. Extend Step 8 with one explicit benchmark-refresh switch, reuse the existing pipeline logging/rendering primitives, and fail before mutation unless source, IGME-release backup, and country checks pass.

**Tech Stack:** R, base R file/hash utilities, jsonlite/openxlsx when installed, existing BB8/Quarto/rmarkdown/PDF pipeline, PowerShell test execution.

---

### Task 1: Lock the refresh contract in tests

**Files:**
- Create: `tests/test_igme_refresh_runner.R`
- Create: `tests/test_bb8_refresh_benchmarks_only.R`

- [ ] **Step 1: Write failing tests for the public API**

Create fixtures under `tempdir()` and assert that `parse_igme_refresh_args()`
defaults to preview, requires a country, accepts production/report year, and
that `classify_staged_igme_release()` returns `promote`, `identical`, `ignore`,
or fails on a mixed four-file release. Assert the refresh step IDs are exactly
`bb8_refresh`, `bb8_comparison`, `diagnostics`, `report_plots`, and
`country_summary` when summary rendering is enabled.

- [ ] **Step 2: Write a failing static Step 8 contract test**

Require `BB8_REFRESH_BENCHMARKS_ONLY`, its implication of the two base-model
skip/resume switches, and four all-survey benchmark conditions that include the
refresh switch.

- [ ] **Step 3: Run RED tests**

Run:

```powershell
Rscript --vanilla tests/test_igme_refresh_runner.R
Rscript --vanilla tests/test_bb8_refresh_benchmarks_only.R
```

Expected: both fail because the refresh module, CLI contract, and Step 8 flag do
not yet exist.

### Task 2: Implement release validation, inventory, and backup helpers

**Files:**
- Create: `Rcode/_supporting_scripts/igme_refresh_runner.R`
- Test: `tests/test_igme_refresh_runner.R`

- [ ] **Step 1: Add the minimal pure helpers**

Implement `igme_release_names()`, `file_sha256()`,
`read_igme_release_file()`, `validate_igme_release()`,
`classify_staged_igme_release()`, `file_inventory()`,
`relative_to_root()`, `copy_verified_backup()`, and
`discover_igme_refresh_targets()`. Require the four expected filenames,
`Country.Name`, `ISO.Code`, `Quantile`, `Indicator`, `Subgroup`, three rows for
the selected ISO, and complete configured year columns.

- [ ] **Step 2: Run the focused test to GREEN**

Run `Rscript --vanilla tests/test_igme_refresh_runner.R` and expect exit code 0.

- [ ] **Step 3: Refactor with tests green**

Keep path containment and hash verification in shared helpers; do not duplicate
copy or validation loops in the orchestrator.

### Task 3: Add benchmark-only execution support

**Files:**
- Modify: `Rcode/8_10_BB8.R`
- Test: `tests/test_bb8_refresh_benchmarks_only.R`

- [ ] **Step 1: Read the explicit refresh flag**

Add `bb8_refresh_benchmarks_only` from
`BB8_REFRESH_BENCHMARKS_ONLY`. When true, set
`bb8_skip_same_frame_main <- TRUE` and
`bb8_resume_allsurvey_benchmarks <- TRUE`, leaving model scope and formulas
unchanged.

- [ ] **Step 2: Force only stale benchmark branches**

Change each Admin-1/Admin-2 NMR/U5MR all-survey condition to run when
`bb8_refresh_benchmarks_only` is true even if a benchmark result already
exists. Same-frame benchmark branches already execute after the base-model skip
and load their saved unbenchmarked results.

- [ ] **Step 3: Run the Step 8 test to GREEN**

Run `Rscript --vanilla tests/test_bb8_refresh_benchmarks_only.R` and expect exit
code 0.

### Task 4: Implement the country refresh orchestration and CLI

**Files:**
- Modify: `Rcode/_supporting_scripts/igme_refresh_runner.R`
- Create: `Rcode/run_igme_refresh.R`
- Modify: `Data/IGME/update results file.R`
- Modify: `README.md`
- Test: `tests/test_igme_refresh_runner.R`

- [ ] **Step 1: Implement argument and step planning**

Add `parse_igme_refresh_args()` and `make_igme_refresh_steps()`. The CLI supports
`--country`, `--preview`, `--production`, `--report-year`, `--skip-summary`, and
`--help`; unknown flags fail and `--skip-summary` is preview-only.

- [ ] **Step 2: Implement `run_igme_refresh()`**

Create the run log/manifest, source preparation, validate country/ISO/year
coverage, classify the staged release, inventory country outputs, verify backups
only for active IGME inputs before promotion, run Step 8 with
`BB8_REFRESH_BENCHMARKS_ONLY=1`, reapply an existing
country crisis adjustment when `doCrisisAdj` is enabled, run Steps 9–11,
render/assemble the summary, validate deliverables, and restore all process
environment variables and working directory on exit. The four-country crisis
implementation must accept a country filter so a country run never writes
another country's output.

- [ ] **Step 3: Add the executable entry point**

Source `pipeline_runner.R` and `igme_refresh_runner.R`, parse command-line
arguments, print help when requested, and invoke `run_igme_refresh()`.

- [ ] **Step 4: Correct future release-copy destination**

Resolve the update script through `--file=` and write the four files to
`Data/IGME/staged`. The copy helper must never overwrite the active release;
promotion remains the responsibility of the master runner after preflight and
verified backup.

- [ ] **Step 5: Document exact commands and outputs**

Add a README section with preview/production commands, affected stages, the IGME
input backup path, manifest path, and the rule that one invocation handles one
country. Country model and deliverable outputs are overwritten without backups.

- [ ] **Step 6: Run focused tests**

Run both new tests and expect exit code 0.

### Task 5: Promote the staged release safely

**Files:**
- Update: `Data/IGME/igme2026_nmr.csv`
- Update: `Data/IGME/igme2026_nmr_nocrisis.csv`
- Update: `Data/IGME/igme2026_u5.csv`
- Update: `Data/IGME/igme2026_u5_nocrisis.csv`
- Create: `Data/IGME/backups/<run_id>/...`

- [ ] **Step 1: Validate all four staged files**

Run the refresh source validator against `Data/IGME/Data/IGME` and record hashes
and schema/ISO coverage.

- [ ] **Step 2: Back up the four active files and verify hashes**

Copy only the exact active release files to a timestamped backup directory and
compare source/backup SHA-256 values.

- [ ] **Step 3: Promote and verify**

Copy the four staged files to `Data/IGME`, then prove every active hash equals
its staged hash. Do not run any country model because no country was specified
for this implementation request.

### Task 6: Run regression verification

**Files:**
- Verify: all files above

- [ ] **Step 1: Run focused and adjacent tests**

Run the new tests plus `test_pipeline_runner.R`,
`test_admin_benchmark_postfit_calibration.R`,
`test_bb8_benchmark_admin1_weighted_draws.R`,
`test_pipeline_runner_pandoc_discovery.R`,
`test_country_report_filename.R`, and the dashboard/report/summary path tests.

- [ ] **Step 2: Run configuration tests**

Run `tests/test_info_config.R` and classify any pre-existing country-specific
failure instead of hiding it.

- [ ] **Step 3: Exercise CLI preview without model execution**

Run `Rscript --vanilla Rcode/run_igme_refresh.R --help`, then a fixture-backed
or preflight-only preview that proves it creates no production backup and does
not source Step 8.

- [ ] **Step 4: Inspect the final diff and status**

Confirm changes are limited to the approved runner, tests, documentation, copy
destination fix, promoted IGME files, and their verified backup. Preserve every
pre-existing user change.
