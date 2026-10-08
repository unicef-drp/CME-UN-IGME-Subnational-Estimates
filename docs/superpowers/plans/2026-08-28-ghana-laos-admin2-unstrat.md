# Ghana and Lao PDR Admin-2 unstratified implementation plan

> Execute in the current checkout because the required generated country state
> and user-owned shared-file edits are not represented by a clean worktree.

**Goal:** Produce validated Admin-2 benchmarked all-survey unstratified BB8
outputs for Ghana and Lao PDR while treating unusable optional smoothed-direct
variants as nonblocking diagnostics.

**Architecture:** Make MICS key construction optional when no DHS `mod.dat`
exists, while retaining strict geospatial validation and explicit failure for
unresolvable non-geospatial Admin-2 labels. Resume each country at the first
affected stage, run only the approved unstratified BB8 family, and verify final
artifacts and aggregation invariants.

**Tech stack:** R 4.6.1, `sf`, `jsonlite`, INLA/BB8 project helpers, PowerShell.

---

### Task 1: Fix geospatial-only MICS key initialization

**Files:**
- Modify: `Rcode/_supporting_scripts/mics_admin_matching.R`
- Modify: `Rcode/3_DataProcessing_sf.R`
- Create: `tests/test_mics_geospatial_only_country_keys.R`

1. Add a failing test proving `mod.dat = NULL` yields a boundary-derived
   Admin-1 key and no Admin-2 key.
2. Run the focused test and confirm the expected missing-helper failure.
3. Add the smallest helper and integrate it at the existing Admin-2 MICS
   branch; guard DHS-only Admin-2 matching and fail explicitly for unresolved
   non-geospatial Admin-2 labels.
4. Run the focused test plus existing MICS matching/geospatial regressions.

### Task 2: Resume Lao PDR through direct estimates and weights

**Files:**
- Regenerate: `Data/Countries/Laos/Laos_cluster_dat.rda`
- Regenerate: `Results/Laos/Direct/**`
- Regenerate: `Data/Countries/Laos/*weights*.rda`

1. Re-run Lao PDR preview Steps 1-6 with the local WorldPop smoke cache.
2. Verify 18 Admin-1 and 148 Admin-2 boundaries, both MICS surveys' Admin-2
   assignments, cluster coverage, and yearly weight sums.
3. Classify any unusable optional Admin-2 smoothed-direct variants from actual
   diagnostics; archive their consumer-facing result files if needed.

### Task 3: Record Ghana optional-model status

**Files:**
- Modify: `Info/Ghana_general_info.json`
- Modify: `tests/test_ghana_pipeline_config.R`
- Archive: affected `Results/Ghana/Direct/**` Admin-2 smoothed-direct results

1. Extend the config test with the four observed optional Admin-2
   smoothed-direct statuses and confirm it fails.
2. Record `attempted_not_fitted` / `data_sparsity` in Ghana's config.
3. Move only the four unusable result objects into a timestamped diagnostic
   archive and rerun the config/consumer checks.

### Task 4: Run the required unstratified BB8 family

**Files:**
- Regenerate: `Results/Ghana/Betabinomial/**`
- Regenerate: `Results/Laos/Betabinomial/**`

1. Validate the unstratified-only runner contract and its Admin-2 benchmarks.
2. Run NMR and U5MR national, Admin-1, and Admin-2 unstratified all-survey base
   and benchmarked models for Ghana.
3. Repeat for Lao PDR. Do not require stratified BB8 success.

### Task 5: Verify downstream deliverables

**Files:**
- Regenerate/verify: `Results/<Country>/Summary_Output/**`
- Regenerate/verify: `Results/<Country>/11_CountrySummary.pdf` where supported

1. Run focused and relevant regression tests.
2. Check final Admin-2 benchmarked BB8 object schemas, region/year coverage,
   finite estimates, interval ordering, and benchmark aggregation.
3. Run downstream summary/export stages using the configured final model.
4. Render and inspect summary PDFs if produced; report the WorldPop smoke-data
   limitation explicitly.
