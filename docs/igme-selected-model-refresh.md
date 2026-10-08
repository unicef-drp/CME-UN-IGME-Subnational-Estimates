# IGME selected-model refresh

From 22 September 2026, `Rcode/run_igme_refresh.R` refreshes only the
`final_model` family selected in `Info/<Country>_general_info.json`:

- `strata.model = strat`: same-frame stratified benchmark, NMR and U5MR.
- `strata.model = unstrat`: all-survey unstratified benchmark, NMR and U5MR.
- Admin-1 always; Admin-2 only with a nonempty `poly.layer.adm2`.
- The supported selected model is AR1 with `bench.model = bench`; unsupported
  choices stop preflight rather than silently substituting another model.

The refresh runner sets `BB8_REFRESH_SELECTED_ONLY=1` together with
`BB8_REFRESH_BENCHMARKS_ONLY=1`. Direct benchmark-only Step 8 also defaults to
selected-only refresh. Both manual and logged general country pipelines now
gate the Step 8 benchmark blocks on `final_model`; ordinary unbenchmarked
comparison fits remain unchanged. The legacy Step 8b unstratified backfill
skips countries whose selected final model is not unstratified and benchmarked.
Preflight
and output validation require only the selected benchmark family. No saved
unbenchmarked model is refitted by this refresh.

Non-selected benchmark outputs are retained, not deleted or refreshed.
Comparison dashboards can therefore contain older-release non-selected
benchmarks; their regeneration does not establish release consistency for
all comparison candidates. Each refresh manifest records this limitation.
Final report outputs use the JSON-selected model and still require visual review.

The first 15 completed countries were refreshed under the previous all-family
scope and do not need rerunning solely because of this scope reduction.
Kenya was interrupted at the user's request; restart its selected family
in a new batch, preserving the original backup and interrupted logs. A new
pre-overwrite snapshot of partial outputs is not a replacement for that baseline.

Tests: `tests/test_igme_selected_model_refresh.R` and
`tests/test_igme_refresh_runner.R`, and
`tests/test_benchmark_entrypoint_selection.R`.
