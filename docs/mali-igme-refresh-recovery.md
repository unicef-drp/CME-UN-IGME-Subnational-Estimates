# Mali selected-model IGME refresh recovery

## Failure and scope

The 23 September 2026 refresh failed in `bb8_refresh`, during the selected
unstratified all-survey Admin-2 U5MR fit (160 regions, six age groups).
The original manifest is
`Results/Mali/logs/20260923_162917_igme_refresh/pipeline_manifest.json`.
INLA reported `file.exists(filename) is not TRUE` and exhausted its internal
retry. That message alone does not identify the missing file or its cause.

The user authorized fixing Mali. The other-country queue remains stopped;
this recovery does not include the deferred Laos or Lesotho work.

## Preserved inputs and completed work

The recovery checks the country JSON, national IGME release and prepared-input
hashes against the failed run. It does not change model selection, boundaries,
surveys, priors, adjustment formulas, temporal models or posterior draw count.

Before retrying, the three new result objects passed finite 1,000-draw and
complete region/year checks for 2000-2025:

- Admin-1 NMR: 20 regions, 520 region/year cells.
- Admin-1 U5MR: 20 regions, 520 region/year cells.
- Admin-2 NMR: 160 regions, 4,160 region/year cells.

Their 18 result/support artifacts are retained; hashes are checked again after
the failed fit is recovered. The original 148-file baseline backup was rehashed
and verified at `C:/Users/yanliu/UNSubnationalBackups/20260923_144520/Mali`.
The separate 149-file partial-state snapshot was hash-verified before overwrite
at `C:/Users/yanliu/UNSubnationalBackups/20260923_221600_mali/Mali`.
The latter is not a replacement for the original baseline.

## Bounded recovery and diagnostics

The recovery helper `.codex-tmp/recover_mali_admin2_u5.R` extracts and evaluates
the unchanged setup and exact Admin-2 U5MR benchmark block from `8_10_BB8.R`.
It does not source the full fitting pipeline. Its scope test ensures the block
contains one Admin-2 U5MR AR1 fit and no other outcome/family. It uses the
existing all-survey preparation helper and the production benchmark computation.

Process-local INLA tracing enables verbose output and keeps its working files
under `C:/Users/yanliu/UNSubnationalBackups/20260923_221600_mali/inla_work`.
Reader diagnostics record filenames and their existence; an error handler
records the condition call and available call stack. This is diagnostic
instrumentation, not a statistical specification change.

Run manifest and logs:
`Results/Mali/logs/20260923_221600_mali_recovery/`.
Batch status and process logs:
`.codex-tmp/igme_refresh_batches/20260923_221600_mali/`.
An earlier helper attempt, `20260923_221500_mali`, stopped during read-only
validation because the helper passed an object name positionally as the draw
count. It did not reach backup or fitting. The argument was corrected to the
named `expected_object` parameter and its scope test extended before retrying.
Both attempt logs are retained.

Focused tests passed before fitting: `test_mali_recovery_scope.R`,
`test_admin_benchmark_postfit_calibration.R`,
`test_bb8_benchmark_admin1_weighted_draws.R`, and
`test_igme_selected_model_refresh.R`.

## Completion gates

All four selected benchmark results must validate before comparison,
diagnostics, report plots and the country PDF are regenerated. A successful
retry does not by itself establish the original missing-file root cause.
Read the live manifest for current execution status; this document is not a
completion claim.

Benchmark-gap exceedances remain non-blocking and are retained for analytical
review. Unmatched previous-final regions use the approved current-only fallback.
Non-selected comparison benchmarks may use an older release. Visual and
analytical review remain required before publication.

## Completed recovery: 23 September 2026, 22:42 CEST

The recovery manifest reports `completed_pending_visual_review`. Admin-2 U5MR
finished at 22:39:13; comparison/dashboard, diagnostics, report plots and summary
assembly then completed. The final country report contains 28 pages.

All four selected benchmark results passed automated readability, finite
1,000-draw and full region/year coverage checks. The three reused result/support
sets remained hash-unchanged. At the terminal monitoring check, current hashes
were independently compared with the manifest for all four results, all 18
reused artifacts, the dashboard/data and final report; all matched.

No benchmark-gap threshold was exceeded: maximum absolute gaps were 1.419 per
1,000 for NMR and 4.7419 per 1,000 for U5MR. These are diagnostics, not a
publication approval or evidence of exact equality to national estimates.

The appendix retained previous-final comparisons where available; previous-final
estimates are missing for 11 current Admin-1 regions (`admin1_9` through
`admin1_19`). The appendix status is `previous_final`, not a whole-country
current-only fallback. Preserve that coverage warning for visual review.

The original missing-file error did not recur. No statistical specification or
shared production-code change was needed for this recovery; the exact cause of
the original INLA missing-file event remains unconfirmed. Original logs, both
verified backups and instrumented INLA working files are retained. Visual and
analytical review remain outstanding, and non-selected comparison benchmarks
may use an older release. The other-country queue remains stopped.
