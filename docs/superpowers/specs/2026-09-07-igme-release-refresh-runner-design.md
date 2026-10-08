# IGME Release Refresh Runner Design

## Goal

Add one country-selectable master workflow that promotes a newly staged 2026
IGME release into the active `Data/IGME` location, refreshes every applicable
benchmarked BB8 model family without refitting unchanged unbenchmarked models,
and then rebuilds the comparison dashboard, diagnostics, report plots, and
country PDF.

## Observed repository state

The active scripts read the four release files directly from `Data/IGME`. The
newer 7 September files were instead written to `Data/IGME/Data/IGME`; their
SHA-256 hashes differ from the active 25 August files. The nesting was caused by
`Data/IGME/update results file.R` appending `Data/IGME` to the directory that
already contains that script.

The current `run_country_pipeline()` always constructs the full pipeline and is
not invoked automatically by `Rcode/run_country_pipeline.R`. Step 8 already has
resume flags that can retain unbenchmarked results and rerun later benchmark
sections, but its all-survey branch currently treats existing benchmark outputs
as complete rather than stale after an IGME release change.

## Approaches considered

1. Run the complete country pipeline from survey processing through reporting.
   This is simple but unnecessarily refits models whose inputs did not change,
   overwrites unrelated derived data, and takes much longer.
2. Add a dedicated IGME-refresh orchestrator that reuses the existing Step 8
   code with an explicit benchmark-refresh flag, then runs Steps 9–13. This is
   the selected approach because it keeps the statistical implementation in
   the authoritative model script and limits replacement to affected outputs.
3. Refresh only the configured final model or only the Admin-1 all-survey
   benchmark. This is quicker, but it leaves old and new national benchmarks
   mixed in the comparison dashboard and is therefore not an acceptable
   country refresh.

## Interface

The runnable entry point is:

```powershell
Rscript --vanilla Rcode/run_igme_refresh.R --country Cameroon --preview
Rscript --vanilla Rcode/run_igme_refresh.R --country Cameroon --production
```

Optional `--report-year YEAR` controls the public PDF filename. Preview is the
default and performs validation/inventory only. Production means the user has
authorized replacement of the staged IGME files, applicable benchmark outputs,
dashboard, diagnostics, report plots, and PDF for the named country.

## Components and data flow

`Rcode/_supporting_scripts/igme_refresh_runner.R` owns the refresh-specific
contract. It resolves and validates the country JSON, compares the four staged
and active release files, checks required columns and ISO/year coverage, creates
hash inventories, finds applicable benchmark targets, and builds a manifest.

In production, the runner promotes the staged release only when all four staged
files are newer than their active counterparts and differ. Identical staged
files are a no-op; older staged files are ignored; a mixed state stops. The
future release-copy script resolves its own location under direct `Rscript`
execution and writes to `Data/IGME/staged`; production promotion and verified
backup remain exclusively owned by the master runner.

The model step sources `Rcode/8_10_BB8.R` in the prepared country context with
three process flags: retain same-frame base models, retain all-survey base
models, and force all benchmark sections to rerun. Step 8 discovers Admin-2
from configuration and uses the existing stratification path. Missing required
unbenchmarked results or stratum weights stop the run; the workflow never
silently falls back to another family.

The runner explicitly sets every Step 8 control flag so inherited repair,
Admin-1-only, or resume settings cannot narrow or terminate the refresh. Before
global release promotion it validates the exact saved unbenchmarked model set,
population weights, required packages, Quarto, Pandoc, LaTeX, qpdf, and the
previous-final workbook.

When the country JSON enables `doCrisisAdj`, the runner next dispatches to the
existing DR Congo, Myanmar, or four-country crisis implementation and replaces
only that country's crisis-adjusted U5MR files. An enabled country without a
registered method stops before downstream outputs are rebuilt. This reapplies
the configured policy; it does not alter the crisis methods or source inputs.

After model and any configured crisis-adjustment success, the runner sources
Steps 9, 10, and 11 and renders the core
summary plus previous-final/current-only appendix through the existing summary
implementation. A failure stops before the next dependent stage. Each step has
its own log and status in `Results/<Country>/logs/<run_id>/pipeline_manifest.json`.

## Backup and failure behavior

When a staged release is promoted, the four active IGME input files are copied
to `Data/IGME/backups/<run_id>/` and re-hashed. A failed or unverifiable IGME
input backup stops before promotion. Existing country model, dashboard, plot,
and PDF outputs are not backed up; the refresh overwrites them in place.

The runner does not delete live outputs or claim rollback automatically after a
partially written statistical run. Its manifest records the failure, completed
steps, and downstream invalidity. A promoted IGME release can use its verified
input backup for recovery without destroying partial run evidence.

## Validation

Focused tests cover argument parsing, staged-release classification, CSV
schema/ISO coverage, contained relative-path backup, refresh step selection,
environment restoration, and the Step 8 force conditions. Existing pipeline,
benchmark, report-path, dashboard, and summary tests remain part of the final
regression run.

Production output validation requires the exact applicable benchmark result
RDA objects, the complete region-year grid, finite saved cells with 1,000 draws,
fresh dashboard/diagnostic/report/appendix artifacts, a structurally readable
dashboard bundle, and a public PDF with a plausible page count. Statistical
benchmark-gap review
continues to use the project thresholds of 2 deaths per 1,000 for NMR and 5 per
1,000 for U5MR; it reports anomalies and never edits estimates to force a pass.

## Out of scope

This workflow does not change survey inputs, boundaries, population weights,
model choice, crisis-adjustment policy, benchmarking formulas, or publication
status. It reapplies an already configured crisis adjustment after benchmarking.
It does not run across every country in one invocation; one country per run
keeps logs and failure recovery isolated.
