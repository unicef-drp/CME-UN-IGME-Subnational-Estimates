# CME — UN IGME Subnational Estimates

R pipeline for neonatal mortality (NMR) and under-five mortality (U5MR) estimation at national, Admin-1 and, where configured, Admin-2 levels. It prepares survey data, fits direct, smoothed-direct and Beta-binomial (BB8) models, applies HIV adjustment and national benchmarking, and produces diagnostics, dashboards and country reports.

This repository builds on the [original UN Subnational Estimates repository](https://github.com/alanamcgovern/UN-Subnational-Estimates). Country selection, survey exclusions, geographic scope and the selected final model are controlled by `Info/<Country>_general_info.json`.

## Repository contents

| Location | Purpose |
|---|---|
| [Rcode/](Rcode/) | Numbered pipeline scripts and entry points |
| [Rcode/_supporting_scripts/](Rcode/_supporting_scripts/) | Shared model, path, benchmarking and pipeline helpers |
| [Rcode/_script_for_specific_tasks/](Rcode/_script_for_specific_tasks/) | Country-specific processing, crisis adjustment and recovery scripts |
| [Info/](Info/) | Country JSON configuration; older configuration scripts are retained in `Info/Archive/` |
| [tests/](tests/) | Focused regression and workflow checks |
| [docs/](docs/) | Method notes and country-specific implementation records |
| [REFERENCE_BB8_WORKFLOW.md](REFERENCE_BB8_WORKFLOW.md) | Detailed BB8 workflow reference |

`Data/`, `Results/`, `outputs/`, temporary files, local credentials and dependency folders are excluded from Git. A clone contains source and configuration; it does not include the inputs or previously generated country results.

## Requirements and local setup

Use R and an RStudio project opened at the repository root. The preparation script checks for `spdep`, `SUMMER`, `geosphere`, `stringr`, `tidyverse`, `rdhs`, `sf`, `haven` and `INLA`. Reporting and runner functions also use packages including `rmarkdown`, `jsonlite` and `openxlsx`; individual scripts may require additional packages. PDF rendering requires Pandoc and a working LaTeX installation. Package versions are not pinned by a lockfile in this repository.

The current preparation layer expects the shared local profile:

```r
USERPROFILE <- Sys.getenv("USERPROFILE")
source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))
```

This profile supplies shared directory variables such as `dir_SP` and `dir_IGME`. It is not included in Git. Configure it for your own environment before running the pipeline. The current preparation code also locates supporting code through the shared subnational project directory; the repository is not a standalone, zero-configuration installation.

For an explicitly selected local project root, set:

```r
Sys.setenv(UN_SUBNATIONAL_HOME = normalizePath(".", winslash = "/"))
```

Supply the applicable inputs separately under `Data/` or through the configured external paths:

- Authorized DHS/MICS birth-history microdata and, where applicable, survey GPS files. DHS downloading requires approved access and local `rdhs` credentials.
- Administrative boundaries and the country-specific geographic mappings.
- WorldPop population rasters and urban/rural frame inputs, or configured survey-based stratum weights.
- National IGME targets, HIV-adjustment inputs and any configured crisis inputs.
- Previous-final estimates when a comparison appendix is required.

Do not commit restricted microdata or local credentials. The pipeline can download some inputs, but required permissions and country-specific preparation still apply.

## Run a country

Always select the country explicitly, using the identifier in `Info/` (for example, `Malawi` or `Cote_dIvoire`). Review its JSON configuration before running.

### Manual workflow

Open [Rcode/run_country_pipeline.R](Rcode/run_country_pipeline.R), set the country and other controls at the top, and execute the setup and numbered blocks one at a time. **The current file contains enabled `if (TRUE)` processing blocks: sourcing or executing the entire file runs those blocks.** Its introductory comment saying that no processing is run does not describe those enabled blocks.

The main sequence is:

| Stage | Script |
|---|---|
| Load configuration and create folders | `Rcode/1_Preperation.R` |
| Obtain and normalize boundaries | `Rcode/2_download_georepo_shapefiles.R` |
| Process survey data | `Rcode/3_DataProcessing_sf.R` |
| Direct and smoothed-direct estimates | `Rcode/4_Direct_SmoothDirect_sf.R` |
| Annual population aggregation weights | `Rcode/5_Admin_Weights_sf.R` |
| Preliminary comparison | `Rcode/6_Comparison_Plot.R` |
| Urban/rural frame weights, when applicable | `Rcode/7a_UR_prop.R`, `Rcode/7b_UR_thresholding_sf.R` |
| BB8 fitting and national benchmarking | `Rcode/8_10_BB8.R` |
| Selected unstratified Admin-1 benchmark backfill | `Rcode/8_10_Run_Unstrat_Admin1_Benchmarks.R` |
| BB8 comparison/dashboard and diagnostics | `Rcode/9_Comparison_Plot.R`, `Rcode/9_Diagnostic_Plots.R` |
| Final report plots | `Rcode/11_Report_Plot.R` |
| Country summary and comparison appendix | `Rcode/11_CountrySummary.Rmd`, `Rcode/12_Previous_Final_Comparison.R` |

For MICS, run only the applicable country section of the relevant preprocessing script before survey processing. Survey-based stratum weights can replace the urban-frame stages when configured. Apply the established country-specific crisis adjustment after benchmarking and before final reporting when `doCrisisAdj` is enabled.

### Structured runner

From the repository root, call the supporting runner explicitly:

```r
source("Rcode/_supporting_scripts/pipeline_runner.R")
run_country_pipeline(
  country = "Malawi",
  mode = "preview",
  render_summary = TRUE,
  report_year = 2026L,
  project_dir = getwd()
)
```

Country-pipeline `preview` is a processing workflow with review checkpoints; it can generate data and model outputs before stopping for review. It is not an inventory-only dry run. Use `mode = "production"` for the production workflow after reviewing the configuration and inputs.

## Default national benchmarking

HIV adjustment and national benchmarking are separate steps:

1. Fit the base BB8 model with the configured HIV adjustments in the survey likelihood.
2. Calibrate the resulting regional mortality-rate draws to the national IGME median for each indicator, administrative level and year, including projection years.

The annual calibration factor is:

```text
factor = national IGME median / sum(population weight × regional posterior median)
```

The same factor scales each regional draw for that year, including available urban/rural stratum draws. Medians, intervals, means and variances are recomputed from the calibrated draws. The population-weighted regional medians match the national target; the median of the weighted joint draws is a different statistic and need not match exactly.

National targets are fixed medians: their uncertainty is not propagated. NMR/U5MR and Admin-1/Admin-2 are calibrated independently, without an ordering or cross-level consistency constraint. Missing targets, invalid weights or coverage, and calibrated rates outside `[0, 1]` stop execution.

Benchmarked result files retain the `*_bench.rda` naming convention and carry `benchmark$method = "direct_pointmedian_v1"`. Diagnostic components describe the HIV-adjusted source fit. Existing country outputs need a rerun to reflect this default.

See [the benchmarking method note](docs/national_benchmarking.md) and [the shared implementation](Rcode/_supporting_scripts/admin_benchmark_helpers.R).

## Refresh after national IGME targets change

Use the dedicated refresh function when national IGME inputs change while survey, boundary, population-weight and model-choice inputs remain unchanged:

```r
source("Rcode/_supporting_scripts/pipeline_runner.R")
source("Rcode/_supporting_scripts/igme_refresh_runner.R")
run_igme_refresh(
  country = "Malawi",
  mode = "preview",
  render_summary = TRUE,
  report_year = 2026L,
  project_dir = getwd()
)
```

Unlike country-pipeline preview, IGME-refresh preview validates and inventories the proposed refresh without fitting models or replacing country outputs. Inspect its manifest before calling the same function with `mode = "production"`.

The production refresh validates the active/staged national release, handles the selected benchmark family, reapplies supported configured crisis adjustments, and rebuilds downstream outputs. It can replace existing outputs. Inspect the run manifest for exact scope and backup locations. Production requires the country-summary PDF.

**Current entry-point limitation:** `Rcode/run_igme_refresh.R` sets `COUNTRY <- "Angola"` and passes an empty argument list to its parser. Its advertised CLI flags do not currently select the country or mode. Use the explicit function call above.

## Outputs and review

Country outputs are written under `Results/<Country>/`, including model objects, comparison dashboards, diagnostic figures, report figures and summary PDFs. Runner logs and manifests are under `Results/<Country>/logs/`.

Check the selected model, year and region coverage, benchmark closure, NMR/U5MR ordering, diagnostics and crisis treatment. Inspect the dashboard and rendered PDF before publication. A completed processing run does not establish scientific or publication approval.

## Focused checks

Run individual regression scripts from the repository root, for example:

```sh
Rscript --vanilla tests/test_admin_benchmark_postfit_calibration.R
Rscript --vanilla tests/test_direct_benchmark_diagnostic_draws.R
Rscript --vanilla tests/test_benchmark_entrypoint_selection.R
```

Other tests cover country configuration, data preparation, geographic joins, model compatibility and reporting. Some checks require local packages or country inputs.
