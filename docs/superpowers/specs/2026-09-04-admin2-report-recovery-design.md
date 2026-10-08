# Admin-2 Report Recovery Design

## Goal

Produce valid 2026 country reports for Lesotho, Myanmar, Angola, Kenya, and
Niger without replacing validated national or Admin-1 model families and
without hiding configured Admin-2 coverage.

## Current State

- Lesotho's selected Admin-2 model results already existed, but a later
  Admin-1-only processing run overwrote the shared adjacency and name-map
  artifacts. The artifacts have been backed up and rebuilt from the unchanged
  GeoRepo layers. The rebuilt Admin-1 matrix is numerically identical to the
  prior matrix, and the 78 rebuilt Admin-2 identifiers match both selected
  model objects. The refreshed report has already passed structural and visual
  checks.
- Myanmar's selected results and regenerated core report are valid. Its 2023
  comparison geography has one Bago and one Shan region, whereas the current
  geography has Bago East/West and Shan North/South/East. A one-to-one
  comparison cannot represent that change correctly.
- Angola is configured to report benchmarked, stratified Admin-2 results, but
  the selected Admin-2 NMR and U5MR model families are incomplete.
- Kenya and Niger are configured to report benchmarked, unstratified,
  all-survey Admin-2 results, but those Admin-2 model families are incomplete.
- Niger also lacks the required Admin-2 U1 and U5 population-weight artifacts.

## Selected Design

### Targeted BB8 recovery mode

Add one opt-in environment switch, `BB8_FINAL_ADMIN2_ONLY=1`, to
`Rcode/8_10_BB8.R`. The switch reads the country's configured `final_model`
and runs only the missing final Admin-2 family:

- `strata.model == "strat"`: fit Admin-2 stratified NMR and U5MR base models,
  calculate their Admin-2 benchmark adjustments, and fit their benchmarked
  models. Do not run national, Admin-1, Admin-2 unstratified, or all-survey
  models.
- `strata.model == "unstrat"`: skip the same-frame branch, fit Admin-2
  all-survey unstratified NMR and U5MR base models, calculate their Admin-2
  benchmark adjustments, and fit their benchmarked models. Do not run
  national, Admin-1, or other Admin-2 families.

The opt-in mode will fail before fitting when Admin-2 boundaries, adjacency,
name maps, data, or the required age-specific population weights are missing.
Normal runs with the switch unset retain their current behavior.

The recovery mode may create or replace only files belonging to the selected
Admin-2 family and its corresponding Admin-2 benchmark-adjustment files. It
must not alter national or Admin-1 BB8 outputs.

### Niger population weights

Back up Niger's existing WorldPop weight artifacts, run the supported Admin
Weights step against the already verified 2000-2025 raster inventory, and
validate that:

- Admin-2 U1 and U5 weights cover every configured Admin-2 region and every
  report year;
- values are finite and nonnegative;
- proportions sum to one by year; and
- existing Admin-1 weights remain numerically unchanged. If they change
  unexpectedly, restore them from backup and stop before model fitting.

### Myanmar report mode

Render the current core summary normally, including its Admin-1 and Admin-2
results. Assemble the appendix in the existing `current_only` mode for both
administrative levels. Record that previous-final comparison was intentionally
disabled because Bago and Shan cannot be mapped one-to-one. Do not create a
fabricated region crosswalk and do not suppress Admin-2 content.

### Other report assembly

After the target model outputs exist, rerun report plots and render friendly
country-named PDFs for Angola, Kenya, and Niger. Use strict previous-final
comparison where the current comparison code validates the geography. If a
country fails strict comparison validation, stop that country's assembly and
report the exact geography mismatch rather than silently using a false
crosswalk or dropping Admin-2.

## Data Flow

1. Inventory and back up the exact artifacts that a country run may replace.
2. For Niger, regenerate and validate Admin-2 population weights.
3. Run the opt-in BB8 recovery mode for Angola, Kenya, and Niger.
4. Verify both selected Admin-2 result files exist, load successfully, contain
   all configured regions and years, and have finite ordered intervals.
5. Regenerate report plots from the configured final model.
6. Render the core PDF and assemble the appropriate appendix.
7. Verify friendly filenames, page structure, text, and rendered layout.
8. Save logs, inventories, validations, and manifests under each country's
   `Results/<Country>/logs/<run-id>/` directory.

## Error Handling and Recovery

- All existing files that may be overwritten are copied into the run log
  before execution.
- A country stops at the first failed prerequisite or validation; later
  countries remain independently recoverable.
- Existing public PDFs remain recoverable from their backups.
- No country is reclassified as Admin-1-only to make a report render.
- No national or Admin-1 output is accepted as changed during targeted model
  recovery.

## Testing and Verification

Before implementation, add a focused test that fails until
`BB8_FINAL_ADMIN2_ONLY` is recognized and gates both configured final-model
branches without changing the default path. After implementation:

- run the new focused test and the existing BB8 resume/configuration tests;
- hash national and Admin-1 BB8 artifacts before and after every recovery run;
- load and structurally validate selected Admin-2 NMR and U5MR RDAs;
- run report filename and report-model tests;
- confirm every final PDF is nonempty and has no unintended blank pages; and
- render every page to contact sheets, inspect the full document, and inspect
  the first, a middle, and the final page at full resolution.

## Deliverables

- Friendly reports:
  - `Results/Lesotho/Lesotho Report 2026.pdf`
  - `Results/Myanmar/Myanmar Report 2026.pdf`
  - `Results/Angola/Angola Report 2026.pdf`
  - `Results/Kenya/Kenya Report 2026.pdf`
  - `Results/Niger/Niger Report 2026.pdf`
- Completed selected Admin-2 U5MR and NMR outputs for Angola, Kenya, and Niger.
- Niger Admin-2 U1 and U5 population weights.
- Per-country backup, run manifest, logs, and PDF QA evidence.
