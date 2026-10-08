project_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
runbook_file <- file.path(project_dir, "Rcode", "run_country_pipeline.R")
runbook_text <- paste(readLines(runbook_file, warn = FALSE), collapse = "\n")
compact_text <- gsub("[[:space:]]+", "", runbook_text)

bootstrap_source <- paste0(
  'source(file.path("Rcode","_supporting_scripts",',
  '"pipeline_runner.R"))'
)
stopifnot(grepl(bootstrap_source, compact_text, fixed = TRUE))

pipeline_text <- sub(bootstrap_source, "", compact_text, fixed = TRUE)
stopifnot(!grepl('source(file.path("Rcode",', pipeline_text, fixed = TRUE))
stopifnot(!grepl('sys.source(file.path("Rcode",', pipeline_text, fixed = TRUE))

pipeline_scripts <- c(
  "1_Preperation.R",
  "2_download_georepo_shapefiles.R",
  "3_DataProcessing_sf.R",
  "4_Direct_SmoothDirect_sf.R",
  "5_Admin_Weights_sf.R",
  "6_Comparison_Plot.R",
  "7a_UR_prop.R",
  "7b_UR_thresholding_sf.R",
  "8_10_BB8.R",
  "8_10_Run_Unstrat_Admin1_Benchmarks.R",
  "9_Comparison_Plot.R",
  "9_Diagnostic_Plots.R",
  "11_Report_Plot.R",
  "12_Previous_Final_Comparison.R"
)
stopifnot(all(vapply(
  pipeline_scripts,
  function(script) {
    rooted_path <- paste0(
      'file.path(project_home(),"Rcode","', script, '")'
    )
    grepl(rooted_path, pipeline_text, fixed = TRUE)
  },
  logical(1)
)))

message("manual pipeline sources use project_home()")
