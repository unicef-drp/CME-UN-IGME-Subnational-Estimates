# Lesotho Admin-2 input repair (23 September 2026)

User approved rebuilding geographic inputs and refitting the selected models.
July's Admin-1-only preparation left both cluster files without Admin-2 fields;
September's boundary/report repair did not recreate them. GPS coordinates remain
available for all 1,975 clusters across 2004, 2009, 2014, 2018 and 2023.

## Approved implementation and validation

1. Test geographic restoration on a synthetic fixture, including nearest-polygon
   assignment, missing/inconsistent coordinates, name-map ordering and refusal
   to overwrite existing Admin-2 fields.
2. Restore only `admin2`, `admin2.char`, `admin2.name` using existing GeoRepo
   polygons and their verified saved ID ordering. Every original column and row
   must remain identical, including mortality counts, sampling weights, strata,
   GPS coordinates and Admin-1 fields. Eight clusters use the existing supported
   nearest-polygon rule (maximum observed distance approximately 681 m).
3. Repair the 2018 MICS prepared cache the same way and make its processor retain
   configured Admin-2 fields on future execution, preserving original strata.
4. Hash-verify backups of all affected data and result files before replacement.
5. Rebuild Admin-2 direct comparisons, refit the JSON-selected unstratified
   all-survey Admin-2 NMR/U5MR base and benchmarked models using the existing
   final-Admin-2 recovery runner, then refresh selected benchmarks and reports.
   Admin-1 base models and comparison-family BB8 models are not refitted.
6. Run the existing full refresh validation, preserve gap-review flags as
   non-blocking, and require visual/analytical review before publication.

Scripts: `.codex-tmp/run_lesotho_admin2_repair.R` and
`.codex-tmp/lesotho_admin2_refit_child.R`. Exact backups, status and per-stage logs
are recorded under the timestamped recovery manifest. No edits to JSON, weights,
adjacency, IGME release or statistical methods. Laos remains untouched. An
independent queue (20260923_144520, Liberia through Zimbabwe) was found running;
it is not interrupted. After its Admin-2 refit, Lesotho waits for that queue to
reach a terminal state before shared report rendering, preventing concurrent
Rcode render-intermediate writes. A failed stage preserves partial outputs and
stops for diagnosis.

## Resume after direct-only completion signal

The first repair stopped after writing four readable unadjusted Admin-2 direct
tables because Step 4 intentionally raises `DIRECT_ADMIN2_ONLY_COMPLETE` and
the wrapper treated that sentinel as an execution failure. No BB8 refit or
downstream report ran in that attempt. The failed manifest is preserved.

The scoped direct adapter now accepts only that exact signal and requires
readable outputs; other errors still propagate. Its regression test checks
the exact signal, unrelated errors, and output-validation failures.
`.codex-tmp/resume_lesotho_admin2_repair.R` verifies the repaired input hashes,
compares every original column against the verified backup, reuses the four
direct tables, takes a separate verified result snapshot, and resumes the
selected Admin-2 refit and benchmark/report refresh. It does not repeat the
geographic repair or overwrite its original backup. Full Step 4 (HIV-adjusted
direct variants, smoothed-direct refits and standalone direct plots) is not
claimed by this direct-only recovery; older comparison models remain explicitly
labelled as potentially stale. Final-model HIV adjustments remain enabled in
the existing BB8 runner. No model configuration or estimation method changes.
