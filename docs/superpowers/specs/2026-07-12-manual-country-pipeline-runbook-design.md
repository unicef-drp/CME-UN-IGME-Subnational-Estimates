# Manual Country Pipeline Runbook Design

## Objective

Replace the final automatic `run_country_pipeline(...)` invocation in
`Rcode/run_country_pipeline.R` with an explicit, numbered manual runbook. A user
must be able to source the main file without launching the country pipeline,
then run and inspect each country script individually in the intended order.

## Scope

- Preserve the existing command-line/default-country parsing and the current
  Ethiopia default.
- Preserve `Rcode/_supporting_scripts/pipeline_runner.R` and its automatic
  pipeline functions for other callers.
- Change only `Rcode/run_country_pipeline.R` and tests directly needed to verify
  its new manual behavior.
- Do not modify any numbered country-processing script.

## Main-script behavior

Sourcing `Rcode/run_country_pipeline.R` will:

1. Parse the existing country and mode arguments.
2. Set the project directory, selected country, and pipeline environment
   variables.
3. Print brief instructions explaining how to run the manual blocks.
4. Not source any computational pipeline step automatically.

The file will contain numbered `if (FALSE) { ... }` blocks. The user can select
and execute the contents of a block in RStudio or temporarily change that block
to `if (TRUE)`.

## Manual sequence

The runbook will expose these steps in order:

1. Generate the country information file in an isolated environment.
2. Source `1_Preperation.R` to load country context and create directories.
3. Run `2_download_georepo_shapefiles.R` through its explicit `main()` function,
   with instructions to skip it when the required normalized layers exist.
4. Source `3_DataProcessing_sf.R`.
5. Source `4_Direct_SmoothDirect_sf.R`.
6. Source `5_Admin_Weights_sf.R` with
   `ADMIN_WEIGHTS_SKIP_100M_COMPARISON=1`, restoring the previous environment
   value afterward.
7. Source `6_Comparison_Plot.R`, followed by a clearly marked review point.
8. Source `7a_UR_prop.R` and `7b_UR_thresholding_sf.R` only when a frame year is
   configured and survey-derived stratum weights are not selected.
9. Source `8_10_BB8.R`.
10. Source `8_10_Run_Unstrat_Admin1_Benchmarks.R` when present.
11. Source `9_Comparison_Plot.R`, followed by the second review point.
12. Source `9_Diagnostic_Plots.R`.
13. Source `11_Report_Plot.R`.
14. Render `11_CountrySummary.Rmd` when summary rendering is enabled.

Each block will explain its purpose, important preconditions, and principal
outputs. It will also state that MICS preprocessing, when required, happens
before `3_DataProcessing_sf.R` and is not automatically included in this
runbook.

## Safety details

- The country-info creation script contains `rm(list = ls())`; the runbook will
  use `sys.source()` in a temporary environment so the interactive workspace is
  not cleared.
- The GeoRepo script defines `main()` when sourced; the runbook will load it in
  a temporary environment and call that environment's `main()` explicitly.
- The Admin Weights block will restore the pre-existing
  `ADMIN_WEIGHTS_SKIP_100M_COMPARISON` value even if the script fails.
- Heavy model and rendering steps remain disabled unless the user explicitly
  runs their blocks.

## Verification

Add a focused test that parses/sources the main file without running heavy
steps and checks that:

- the automatic `run_country_pipeline(...)` invocation is absent;
- every required numbered script appears in manual order;
- manual blocks default to disabled;
- the isolated country-info and GeoRepo patterns are present;
- the existing pipeline-runner unit tests still pass.
