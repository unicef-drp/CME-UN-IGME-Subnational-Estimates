# Master entrypoint for the country pipeline.
#
# Set the country here when running interactively, or pass command-line flags:
#   Rscript Rcode/run_country_pipeline.R --country Cameroon --mode preview
#   Rscript Rcode/run_country_pipeline.R --country Cameroon --mode production

country <- "Cote_dIvoire"
mode <- "preview"
render_summary <- TRUE
report_year <- 2026L

source(file.path("Rcode", "_supporting_scripts", "pipeline_runner.R"))

args <- parse_pipeline_args(
  country = country,
  mode = mode,
  render_summary = render_summary,
  report_year = report_year
)

if (isTRUE(args$help)) {
  cat(
    "Usage: Rscript Rcode/run_country_pipeline.R [--country COUNTRY] [--mode preview|production] [--report-year YEAR] [--skip-summary]\n",
    "\n",
    "Examples:\n",
    "  Rscript Rcode/run_country_pipeline.R --country Cameroon --mode preview\n",
    "  Rscript Rcode/run_country_pipeline.R --country Cameroon --production\n",
    sep = ""
  )
  quit(status = 0)
}

# Manual pipeline setup ---------------------------------------------------------
#
# Sourcing this file prepares the selected country but does not run any country
# processing. Run one numbered block at a time by selecting the statements
# inside an `if (TRUE)` block in RStudio, or temporarily change only that block
# to `if (TRUE)`.

project_dir <- pipeline_project_dir()
country <- args$country
mode <- args$mode
render_summary <- args$render_summary
report_year <- args$report_year

setwd(project_dir)
Sys.setenv(
  UN_SUBNATIONAL_HOME = project_dir,
  UN_SUBNATIONAL_COUNTRY = country,
  UN_SUBNATIONAL_MODE = mode
)
base::source(file.path(
  project_dir, "Rcode", "_supporting_scripts", "project_paths.R"
))

message("Manual country pipeline prepared for ", country, ".")
message("No processing step has been run. Execute the numbered blocks in order.")

# Step 1: Load country context and create folders ------------------------------
# Input: Info/<Country>_general_info.json.
# Outputs: country variables in the workspace plus Data/Results directories.
if (TRUE) {
  source(file.path(project_home(), "Rcode", "1_Preperation.R"))
}

# Step 2: Download and normalize GeoRepo boundaries ----------------------------
# Skip this step when georepo_boundaries_available(globalenv()) is TRUE.
# The script defines main() rather than running automatically when sourced.
if (TRUE) {
  if (georepo_boundaries_available(globalenv())) {
    message("GeoRepo Admin-0/1/2 shapefiles already exist; Step 2 skipped.")
  } else {
    georepo_env <- new.env(parent = globalenv())
    sys.source(
      file.path(
        project_home(), "Rcode", "2_download_georepo_shapefiles.R"
      ),
      envir = georepo_env
    )
    georepo_env$main()
    rm(georepo_env)
  }
}

# Optional MICS preprocessing (before Step 3) ----------------------------------
# Do not source either whole preprocessing script from this runbook.
# For MICS without GPS, open:
#   Rcode/_script_for_specific_tasks/MICS_DataProcessing.R
# For MICS with GPS, open:
#   Rcode/_script_for_specific_tasks/MICS_Geospatial_DataProcessing.R
# Run only the selected country's section or function, then confirm the expected
# *.tmp.rda or *.geo.tmp.rda output exists before continuing to Step 3.

# Step 3: Process DHS and prepared MICS survey data ----------------------------
# Outputs include <Country>_cluster_dat.rda, the same-frame cluster file,
# adjacency matrices, and standardized GeoRepo admin names.
if (TRUE) {
  source(file.path(project_home(), "Rcode", "3_DataProcessing_sf.R"))
}

use_path_base(home.dir)

# Step 4: Calculate direct and smoothed-direct estimates ------------------------
# Produces national, Admin-1, and (when configured) Admin-2 NMR/U5MR estimates
# and their preliminary diagnostic figures.
if (TRUE) {
  source(file.path(project_home(), "Rcode", "4_Direct_SmoothDirect_sf.R"))
}

# Step 5: Calculate annual admin population weights ----------------------------
# Uses aligned 1 km WorldPop population rasters.
if (TRUE) {
  source(file.path(project_home(), "Rcode", "5_Admin_Weights_sf.R"))
}

# Step 6: Create the pre-BB8 comparison plots ----------------------------------
# Review Results/<Country>/Figures/Summary before continuing to BB8 inputs.
if (TRUE) {
  source(file.path(project_home(), "Rcode", "6_Comparison_Plot.R"))
  review_summary_dir <- file.path(project_home(), "Results", country, "Figures", "Summary")
  message(
    "REVIEW POINT: inspect the pre-BB8 comparison plots before Step 7.\n",
    "  NMR plots: ",
    normalizePath(
      file.path(review_summary_dir, "NMR"),
      winslash = "/",
      mustWork = FALSE
    ),
    "\n",
    "  U5MR plots: ",
    normalizePath(
      file.path(review_summary_dir, "U5MR"),
      winslash = "/",
      mustWork = FALSE
    )
  )
}

# Steps 7a/7b: Prepare urban/rural stratum weights -----------------------------
# Run these only when frame_year is configured and strata_weight_source is not
# "survey". If survey-derived stratum weights are configured, skip both steps;
# Step 8 derives the weights from same-frame survey clusters instead.

# Step 7a: Match urban-frame proportions to GeoRepo Admin-1 names.
uses_survey_strata <- exists("strata_weight_source", inherits = FALSE) &&
  identical(strata_weight_source, "survey")
has_urban_frame <- exists("frame_year", inherits = FALSE) &&
  length(frame_year) > 0L &&
  !all(is.na(frame_year))
if (!uses_survey_strata && has_urban_frame) {
  source(file.path(project_home(), "Rcode", "7a_UR_prop.R"))
} else {
  message("Step 7a skipped: using survey-derived strata or no urban frame.")
}

# Step 7b: Threshold WorldPop grids and save NMR/U5MR stratum weights.
if (!uses_survey_strata && has_urban_frame) {
  source(file.path(project_home(), "Rcode", "7b_UR_thresholding_sf.R"))
} else {
  message("Step 7b skipped: using survey-derived strata or no urban frame.")
}

# Step 8: Fit the BB8 model families -------------------------------------------
# Fits same-frame stratified/unstratified and all-survey unstratified NMR/U5MR
# models at the available administrative levels, including benchmarked outputs.
if (TRUE) {
  source(file.path(project_home(), "Rcode", "8_10_BB8.R"))
}

# Step 8b: Backfill selected unstratified Admin-1 benchmarks only --------------
# Skips countries selecting a stratified or unbenchmarked final model.
# Existing benchmark result files are skipped unless the force flag is set.
if (TRUE) {
  benchmark_script <- file.path(
    project_home(), "Rcode", "8_10_Run_Unstrat_Admin1_Benchmarks.R"
  )
  if (file.exists(benchmark_script)) {
    source(benchmark_script)
  }
}

# Step 9: Compare BB8 results and build the dashboard ---------------------------
# Compares benchmarked/unbenchmarked and stratified/unstratified model families.
if (TRUE) {
  source(file.path(project_home(), "Rcode", "9_Comparison_Plot.R"))
  message("REVIEW POINT: inspect the BB8 comparison dashboard before reports.")
}

# Step 10: Generate BB8 diagnostic plots ---------------------------------------
# Finds the BB8 result files that exist and plots their temporal and UR effects.
if (TRUE) {
  source(file.path(project_home(), "Rcode", "9_Diagnostic_Plots.R"))
}

# Step 11: Generate final report plots -----------------------------------------
# Uses final_model from the country info to select the report model family.
if (TRUE) {
  source(file.path(project_home(), "Rcode", "11_Report_Plot.R"))
}

# Step 12: Render the country summary and add the previous-final appendix -------
# Outputs the reusable core under Figures/Summary and the assembled public PDF at
# Results/<Country>/<Readable Country> Report <Report Year>.pdf.
if (TRUE) {
  if (!isTRUE(render_summary)) {
    message("Summary rendering is disabled by --skip-summary.")
  } else {
    summary_result_dir <- file.path(project_dir, "Results", country)
    summary_build_dir <- file.path(summary_result_dir, "Figures", "Summary")
    dir.create(summary_build_dir, recursive = TRUE, showWarnings = FALSE)
    core_summary_pdf <- file.path(
      summary_build_dir, "11_CountrySummary_core.pdf"
    )
    output_summary_pdf <- file.path(
      summary_result_dir,
      country_report_filename(country, report_year)
    )
    rmarkdown::render(
      input = file.path("Rcode", "11_CountrySummary.Rmd"),
      output_file = basename(core_summary_pdf),
      output_dir = dirname(core_summary_pdf),
      envir = globalenv(),
      quiet = FALSE
    )
    source(file.path(
      project_home(), "Rcode", "12_Previous_Final_Comparison.R"
    ))
    previous_final_workbook <- resolve_previous_final_workbook()
    previous_final_comparison <- run_country_summary_comparison_appendix(
      country = country,
      iso3 = iso0,
      previous_workbook = previous_final_workbook,
      core_summary_pdf = core_summary_pdf,
      output_summary_pdf = output_summary_pdf,
      home_dir = project_dir,
      res_dir = summary_result_dir,
      regions_per_page = 6L,
      strata_model = final_model$strata.model,
      benchmarked = identical(final_model$bench.model, "bench"),
      all_surveys = identical(final_model$strata.model, "unstrat")
    )
  }
}

# Step 13: Refresh the previous-final appendix without rerendering the core -----
# The core PDF must already exist from Step 12. This rebuild is idempotent.
if (isTRUE(render_summary)) {
  source(file.path(
    project_home(), "Rcode", "12_Previous_Final_Comparison.R"
  ))
  previous_final_workbook <- resolve_previous_final_workbook()
  summary_result_dir <- file.path(project_dir, "Results", country)
  core_summary_pdf <- file.path(
    summary_result_dir, "Figures", "Summary", "11_CountrySummary_core.pdf"
  )
  output_summary_pdf <- file.path(
    summary_result_dir,
    country_report_filename(country, report_year)
  )
  previous_final_comparison <- run_country_summary_comparison_appendix(
    country = country,
    iso3 = iso0,
    previous_workbook = previous_final_workbook,
    core_summary_pdf = core_summary_pdf,
    output_summary_pdf = output_summary_pdf,
    home_dir = project_dir,
    res_dir = summary_result_dir,
    regions_per_page = 6L,
    strata_model = final_model$strata.model,
    benchmarked = identical(final_model$bench.model, "bench"),
    all_surveys = identical(final_model$strata.model, "unstrat")
  )
}

# Step 14: Inspect final data and plots ----------------------------------------
# Review processed survey years and admin names, population weights, fitted model
# inventories, diagnostics, comparison plots, dashboard, and the assembled PDF.
# Record and summarize any data, model, or visual issue found before acceptance.
message(
  "FINAL REVIEW: Inspect final data, plots, dashboard, and summary PDF; summarize any issues."
)
