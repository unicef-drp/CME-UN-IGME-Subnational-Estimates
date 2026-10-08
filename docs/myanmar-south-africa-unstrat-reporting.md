# Myanmar and South Africa reporting selection, 28 September 2026

The user requested unstratified reporting models for Myanmar and South Africa,
refreshing national benchmarking where needed and regenerating reports. Both
countries retain AR1 temporal models, benchmarked estimates, the existing survey
scope, and both configured administrative levels. Myanmar retains its established
2008 cyclone adjustment; South Africa retains its HIV adjustment.

The preceding audit found 44 Myanmar Admin-1 and 5 South Africa Admin-2
region-years with NMR medians above U5MR in the selected stratified results.
Myanmar's 2023 country-update note explicitly linked the historical choice of
unstratified models to sparse-data INLA warnings in stratified Admin-2 models.

Existing unstratified fits are available for both countries. Before this refresh,
the older benchmarked unstratified files had no median crossings at either level.
This is not a guarantee for refreshed outputs: South Africa's unbenchmarked
Admin-2 unstratified results had nine crossings. Validate both levels and both
indicators again after refreshing benchmarking and Myanmar's crisis adjustment.

Configuration and original report/model targets were backed up with SHA-256
verification. See `outputs/20260928_unstrat_reporting/backup_manifest.json` and
country-specific refresh manifests under `Results/<Country>/logs/`.

Myanmar's crisis application and refresh validation now follow the configured
model family, including the correct all-survey unstratified object names. The
crisis allocation and probability transformation are unchanged. Regression tests
cover both stratified and unstratified crisis-file selection.

The repository-wide `test_info_config.R` has a pre-existing unrelated failure:
`Cameroon_general_info.json has unexpected surveys_1frame`. Focused tests for
these two country selections, the refresh runner, and Myanmar's crisis adjustment
pass. This change does not alter Cameroon configuration or waive that failure.

## Verified refreshed results

Both selected families were refreshed against the active September 2026 IGME
inputs. All eight benchmark outputs and both Myanmar crisis-adjusted outputs
have 1,000 finite draws and complete region/year coverage for 2000–2025.

| Country and level | Region-years | NMR median above U5MR |
| --- | ---: | ---: |
| Myanmar Admin-1 | 468 | 0 |
| Myanmar Admin-2 | 2,080 | 0 |
| South Africa Admin-1 | 234 | 0 |
| South Africa Admin-2 | 1,352 | 7 |

Myanmar's 44 previous crossings are resolved. South Africa's count changes from
five stratified crossings to seven unstratified crossings: Namakwa (2025), Cape
Winelands (2025), Garden Route (2024–2025), Overberg (2025), and West Coast
(2024–2025). Five of these seven already existed in the unbenchmarked
unstratified fits; Cape Winelands and Overberg appear only after refreshing
benchmarking. The unbenchmarked unstratified fits had nine crossings overall.
The older stored unstratified benchmarks had zero and cannot establish that the
new benchmarks are free of crossings. The largest current excess is West Coast
2025: NMR 13.084666 versus U5MR 11.560615 per 1,000 live births.

Separate population-weighted national benchmark checks flag one Myanmar row
(Admin-2 U5MR, 2000, gap 6.165438 per 1,000) and 29 South Africa rows. South
Africa's maximum gaps are 6.83 for NMR and 16.07 for U5MR per 1,000;
consult the generated benchmark-gap CSVs for full precision and years. These
are review findings, not failed output-file validation, and no extra correction
or numerical capping was applied.

Myanmar's 21-page and South Africa's 19-page PDFs were rendered and visually
reviewed, including all contact-sheet pages and full-size first, middle and last
pages. Both identify the unstratified model. Myanmar's appendix uses current-only
plots because old Bago/Shan regions do not match the current split geography.
The report dashboard needed a small Quarto discovery repair: pass the executable
already found by the pipeline to the installed R Quarto package, restoring the
environment afterward. Myanmar resumed at reporting without refitting its models.

The combined workbook retains 241,020 rows; 8,268 Myanmar/South Africa rows were
refreshed. Full saved-cell readback matched the expected data, all other-country
rows were unchanged, and the remaining median crossings are South Africa (7)
and Kenya (4). SHA-256 comparison confirms 42 backed-up unbenchmarked or
non-selected model files are unchanged.
