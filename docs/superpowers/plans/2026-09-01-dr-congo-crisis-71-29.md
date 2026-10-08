# DR Congo Crisis 71/29 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the active DR Congo crisis allocation with 71% historical East / 29% Rest and regenerate validated crisis inputs, adjusted model results, dashboard, and final PDF.

**Architecture:** Keep the existing two-stage design: a reproducible preparation script creates the self-contained spatial crisis RDA, then the existing application script adds the resulting crisis probabilities to selected benchmarked U5MR models. Preserve pipeline-compatible output names, archive replaced 77/23 artifacts, and rerun only the affected crisis/report/dashboard stages.

**Within-group clarification (2026-09-01):** Use age-specific population alone for spatial weights; do not multiply by benchmarked non-crisis U5MR.

**Tech Stack:** R 4.6.1, base R, repository RDA models, Quarto/R Markdown, Pandoc/LaTeX, PowerShell, PyMuPDF.

---

### Task 1: Establish rollback inventory and failing 71/29 test

**Files:**
- Create: `Data/Crisis_Adjustment/Archive/20260901_pre_cod_71_29/`
- Create: `Results/DR_Congo/backups/20260901_pre_crisis_71_29/`
- Create: `tests/test_cod_crisis_71_29.R`

- [ ] Copy the current 77/23 script, test, `crisis_COD.rda`, crisis-adjusted model files, dashboard, and report into the named archive/backup without changing the originals.
- [ ] Create `test_cod_crisis_71_29.R` from the focused allocation contract, point it at `prepare_cod_71_29.R`, and assert default East shares of `0.71` for infant and ages 1-4 deaths at both levels.
- [ ] Run `Rscript tests/test_cod_crisis_71_29.R` and confirm RED because the 71/29 preparation script does not yet exist.

### Task 2: Implement the 71/29 preparation source

**Files:**
- Create: `Data/Crisis_Adjustment/prepare_cod_71_29.R`
- Remove from active use: `Data/Crisis_Adjustment/prepare_cod_77_23.R`
- Remove from active use: `tests/test_cod_crisis_77_23.R`

- [ ] Copy the preparation implementation to the new active filename and change the default `east_share` and production call from `0.77` to `0.71`.
- [ ] Change all active method strings, comments, and test messages to 71% East / 29% Rest.
- [ ] Use population age 0-1 for infant allocations and population age 1-4 for ages 1-4 allocations, with no U5MR multiplier.
- [ ] Run the focused test and require `COD crisis 71/29 tests passed.`
- [ ] Confirm no active code or current README references the old active filename or 77/23 allocation.

### Task 3: Update documentation and historical status

**Files:**
- Modify: `Data/Crisis_Adjustment/README.md`
- Modify: `docs/superpowers/specs/2026-08-26-dr-congo-crisis-77-23-design.md`
- Modify: `docs/superpowers/plans/2026-08-26-dr-congo-crisis-77-23.md`
- Modify: `docs/superpowers/specs/2026-08-27-dr-congo-crisis-application-design.md`
- Modify: `docs/superpowers/plans/2026-08-27-dr-congo-crisis-application.md`

- [ ] Document the Lancet 71% result, complementary 29%, all-age/period limitation, unchanged within-group proxy, new command, and active filenames.
- [ ] Add a superseded notice to historical 77/23 design/plan documents without rewriting their historical content.
- [ ] Update the application design/plan to reference the active 71/29 preparation test.

### Task 4: Regenerate and validate crisis inputs and adjusted models

**Files:**
- Replace: `Data/Crisis_Adjustment/crisis_COD.rda`
- Replace: `Results/DR_Congo/Betabinomial/U5MR/DR_Congo_res_adm1_unstrat_u5_allsurveys_bench_crisis.rda`
- Replace: `Results/DR_Congo/Betabinomial/U5MR/DR_Congo_res_adm2_unstrat_u5_allsurveys_bench_crisis.rda`

- [ ] Record hashes of national source, non-crisis models, and replaced outputs.
- [ ] Run `Rscript Data/Crisis_Adjustment/prepare_cod_71_29.R`.
- [ ] Run `Rscript Data/Crisis_Adjustment/apply_cod_crisis_adjustment.R` with approved overwrite behavior.
- [ ] Run focused allocation/application/config tests and verify totals, 71/29 shares, metadata, affected years 2000-2004, expected row counts, and unchanged non-crisis model hashes.

### Task 5: Regenerate dashboard and final report

**Files:**
- Replace: `Results/DR_Congo/DR_Congo_bb8_comparison_data.rds`
- Replace: `Results/DR_Congo/DR_Congo_bb8_comparison_dashboard.html`
- Replace: `Results/DR_Congo/11_CountrySummary.pdf`
- Replace: `Results/DR_Congo/DR Congo Report 2026.pdf`
- Replace affected files under: `Results/DR_Congo/Figures/Summary/`

- [ ] Run the affected Step 9 comparison/dashboard generation and confirm the bundle records crisis adjustment for selected U5MR models.
- [ ] Run Step 11 report plots, render the country-summary core, and assemble Step 12 output using the metadata-selected crisis files.
- [ ] Confirm dashboard and PDF files are non-empty, current, and changed from their archived 77/23 versions.

### Task 6: Final verification and manifest

**Files:**
- Create: `Results/DR_Congo/logs/<run_id>/pipeline_manifest.json`
- Create: `Results/DR_Congo/logs/<run_id>/crisis_71_29_refresh.log`

- [ ] Run the focused tests plus report/dashboard configuration regressions and scan logs for errors.
- [ ] Render every final PDF page to PNG and inspect for clipping, overlap, blanks, and broken legends; inspect the dashboard metadata and representative content.
- [ ] Record source/output hashes, commands, tests, page counts, visual review, warnings, and completion status in the manifest.
- [ ] Run a final active-reference scan showing no unsuperseded 77/23 implementation references outside archives/historical documents.
