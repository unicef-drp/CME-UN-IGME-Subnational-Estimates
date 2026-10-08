# DR Congo crisis adjustment: 71/29 design

## Decision

Replace the active 77% historical-East / 23% Rest allocation with the 71% / 29% distribution reported in the peer-reviewed Lancet publication of the 2004 IRC nationwide survey. The source period remains January 2003-April 2004 and the share remains an all-age excess-mortality proxy applied to national under-five crisis deaths for 2000-2004.

## Allocation

National infant and ages 1-4 crisis deaths are split independently: 71% to the historical East and 29% to Rest. The historical-East crosswalk is unchanged. Within each group, infant deaths are weighted by population age 0-1 and ages 1-4 deaths by population age 1-4. Per the user's 2026-09-01 clarification, benchmarked non-crisis U5MR is not included in the spatial allocation weights.

## Active and archived artifacts

The active preparation script and focused test become `prepare_cod_71_29.R` and `test_cod_crisis_71_29.R`. The pipeline-compatible prepared filename remains `crisis_COD.rda`. Before replacement, the 77/23 script, test, prepared RDA, crisis-adjusted model files, dashboard, and final report are copied into a timestamped archive/backup. Historical 77/23 specs and plans remain as records but receive a superseded notice pointing to this design.

## Downstream regeneration

Regenerate `crisis_COD.rda`, apply it to the selected benchmarked Admin-1 and Admin-2 U5MR model files, rebuild the comparison data/dashboard with crisis-adjusted selected U5MR, rebuild report plots, and render/assemble the final PDF `Results/DR_Congo/DR Congo Report 2026.pdf` plus the canonical `11_CountrySummary.pdf`.

## Verification

Focused tests must first fail against the old 77/23 implementation and then pass after the update. Verify national death totals, 71/29 reconciliation for both age groups and administrative levels, saved metadata, unchanged non-crisis inputs, expected crisis-adjusted row counts and affected years, dashboard crisis metadata, PDF structure, and representative/all-page visual quality. Record the run in a new pipeline manifest.
