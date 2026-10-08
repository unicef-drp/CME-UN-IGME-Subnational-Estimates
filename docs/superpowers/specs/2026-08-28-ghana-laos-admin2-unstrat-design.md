# Ghana and Lao PDR Admin-2 unstratified run design

## Goal

Run Ghana and Lao PDR through the Admin-2 path and produce the benchmarked,
all-survey, unstratified BB8 family for NMR and U5MR. Stratified BB8 and
smoothed-direct variants are optional diagnostics for this run.

## Approved behavior

- A MICS-only country may use a self-contained geospatial Admin-2 artifact
  without a DHS-derived administrative key.
- A non-geospatial MICS artifact may still use DHS-derived Admin-2 matching
  when a DHS key exists, or boundary-derived Admin-1 matching as a fallback.
- Non-geospatial Admin-2 labels without a DHS key must fail explicitly rather
  than being silently interpreted as Admin-1 labels.
- Smoothed-direct Admin-2 variants that are technically fitted but unusable
  because sparse direct estimates create degenerate variances are recorded as
  `attempted_not_fitted` diagnostics and excluded from downstream comparison
  consumers. The files are archived, not deleted.
- The required model endpoint is `strata.model = unstrat` and
  `bench.model = bench`; other model families may remain unavailable.

## Scope and safety

The shared data-processing change is limited to lazy/optional construction of
MICS administrative keys. Existing Ghana and Lao PDR country configuration,
geospatial MICS artifacts, and the pre-run backup remain intact. WorldPop
weights use the local 2015/2020/2025 smoke cache and are non-publishable until
the canonical annual source is available.

The repository already contains user-owned uncommitted changes in the two
shared files and generated country state in this checkout. A clean git
worktree would omit that state, so implementation stays in the current
checkout and patches only the demonstrated branch.

## Verification

Verification covers the shared regression, existing MICS matching behavior,
both countries' Admin-2 configurations and geospatial artifacts, cluster
coverage, weight invariants, presence and numeric validity of the final
Admin-2 benchmarked BB8 outputs, and downstream summaries where feasible.
