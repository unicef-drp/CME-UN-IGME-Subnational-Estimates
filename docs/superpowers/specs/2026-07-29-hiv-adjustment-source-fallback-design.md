# HIV Adjustment Source Fallback Design

## Objective

Make every active subnational pipeline path use the country-level 2026 HIV adjustment file by default and fall back to the country-level 2025 file only when the requested country has no rows in the 2026 file.

## Source policy

The source priority is fixed:

1. `Data/HIV/HIVAdjustments_country_2026.rda`
2. `Data/HIV/HIVAdjustments_country_2025.rda`

The loader must not use the legacy 2022 adjustment file.

The 2025 fallback is country-specific. A country present in the 2026 file must use its 2026 rows even if the 2025 file also contains that country. If a country is absent from the 2026 file, the loader must use its rows from the 2025 file. If the country is absent from both files, the loader must stop with a clear error naming the country and both files checked.

Missing files and malformed adjustment objects must also produce clear errors rather than silently selecting another legacy source.

## Code changes

Keep `load_country_hiv_adjustments(path, country)` as the public helper interface. Active callers will pass `Data/HIV/HIVAdjustments_country_2026.rda` as `path`. The helper will derive the sibling fallback path `Data/HIV/HIVAdjustments_country_2025.rda`.

Update every active direct-estimation and BB8 caller that currently passes `Data/HIV/HIVAdjustments.rda`. Archived scripts are outside scope.

Retain the existing normalization rules and required columns: `country`, `area`, `survey`, `years`, and `ratio`.

## Verification

Use test-first development. The focused loader tests will create isolated temporary 2026 and 2025 `.rda` fixtures and verify:

- a country found in 2026 uses only the 2026 rows;
- a country absent from 2026 but found in 2025 uses the 2025 rows;
- a country absent from both files produces a clear error;
- no active pipeline caller references `HIVAdjustments.rda` or `HIVAdjustments_2022.rda`.

After implementation, run the focused HIV adjustment tests and search active pipeline code for obsolete filenames.
