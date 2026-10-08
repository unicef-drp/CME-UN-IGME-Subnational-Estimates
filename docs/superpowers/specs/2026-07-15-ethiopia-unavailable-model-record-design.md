# Ethiopia unavailable-model record and dashboard handling

## Purpose

Record Ethiopia models that were attempted but could not be fitted, and allow the BB8 comparison dashboard to complete when those optional outputs are absent.

## Country configuration

Add a top-level `model_run_status` array to `Info/Ethiopia_general_info.json`. Each entry is machine-readable and contains:

- `model`: stable model-family identifier.
- `variant`: temporal-output variant.
- `status`: `attempted_not_fitted`.
- `reason`: stable reason code, initially `data_sparsity`.

The Ethiopia entries will record the period and yearly Admin-2 smoothed-direct NMR models. The existing country configuration remains otherwise unchanged.

## Dashboard behavior

`Rcode/9_Comparison_Plot.R` will treat Admin-2 smoothed-direct NMR and U5MR files independently. It will load and aggregate a series only when its source file exists. A missing optional series will be omitted with an informative message; available Admin-2 direct, smoothed-direct, BB8, and benchmarked results will remain in the dashboard.

The dashboard must still fail when required national or Admin-1 inputs are absent. This change applies only to optional Admin-2 smoothed-direct outputs that step 4 already permits to fail because of data sparsity.

## Testing

Add a regression test that verifies the dashboard script guards both Admin-2 period smoothed-direct files before loading them and does not require NMR and U5MR to exist as a pair. Run the new regression test and the existing dashboard/pipeline tests, then regenerate and verify the Ethiopia HTML dashboard.

## Acceptance criteria

- Ethiopia JSON records both unavailable Admin-2 smoothed-direct NMR variants.
- The JSON remains valid and loads through the existing country-info loader.
- `9_Comparison_Plot.R` completes when Admin-2 smoothed-direct NMR is absent but U5MR is present.
- The Ethiopia dashboard HTML and comparison-data RDS are produced and non-empty.
- Existing Admin-2 BB8 results remain included.
