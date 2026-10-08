# Remaining IGME refresh continuation — 23 September 2026

User requested all unfinished countries be attempted, with errors investigated
and corrected rather than stopping the whole queue. This authorizes operational
recovery, not changed methods, invented inputs, altered final-model choices or
publication of invalid results.

## Accounting and scope

Batch `20260923_231000` verifies 27 prior completed manifests, including Lesotho
and Mali's separately completed recovery, then re-preflights the remaining 21
configured countries. These include Laos, previously deferred after a generic
file-connection failure. The remaining-country universe is the set difference
between the 48 current Info configurations and those 27 completion records.
Exact rows are in the batch's `previously_completed.csv`, `preflight_summary.csv`
and `queue.csv`.

Only each JSON-selected NMR/U5MR model family is refreshed, with Admin-2 only
when `poly.layer.adm2` is nonempty. Existing non-selected comparison models may
be older. No scientific configuration or statistical code is changed.

## Execution and recovery policy

- Countries run sequentially in separate R processes; report rendering is not
  concurrent. Each overwrite requires a new hash-verified backup. Older
  baselines and failed-attempt outputs/logs remain preserved.
- Worker revalidates JSON and release hashes against the fresh preview and
  rechecks required inputs before backing up and executing production.
- INLA diagnostic tracing enables verbose output, keeps its work files, and
  chooses a country-specific local work directory outside OneDrive. This
  affects diagnostics/storage only; no likelihood, model, priors, draw count,
  adjustment, scope or fitting tolerance is changed.
- Original error calls/stacks and immediate warnings are captured inside the
  step logger before error handlers unwind.
- A genuine worker failure is written to `failed_countries.csv`. Its downstream
  steps do not run; the outer queue moves to the next country. The failed country
  remains unfinished, never counted as completed. Monitoring investigates these
  failures while other countries progress and arranges evidence-based recovery
  under the user's authorization, without concurrent edits to active production
  scripts or another report-rendering process.
- No blind retry loop: a repeated error requires examination of exact logs,
  manifests and paths. Missing data or necessary methodological decisions are
  retained as explicit unresolved blockers, not bypassed.
- Gap threshold exceedances remain non-blocking analytical flags, and approved
  current-only fallback for unmatched previous-final regions remains active.
- `completed_with_errors` means the queue was exhausted, NOT that all countries
  succeeded. It triggers further diagnosis/recovery, not silent abandonment.
- Completion still requires output validation and visual/analytical review;
  successful execution is not publication approval.

Scripts: `.codex-tmp/prepare_all_remaining_refresh.R`,
`.codex-tmp/run_all_remaining_refresh.ps1`,
`.codex-tmp/run_resilient_refresh_worker.R` and the small queue helper
`.codex-tmp/continue_refresh_queue.ps1`.
Regression `.codex-tmp/test_continue_refresh_queue.ps1` confirmed that an error
in the middle country is preserved while the third country is still attempted
exactly once. Both runner scripts passed syntax checks before launch.

Additional numerical warnings (distinct from benchmark-gap flags) are retained
in the batch's `analytical_warnings.md` when observed. These require final-log
and scientific review even if execution and automated artifact checks succeed.
