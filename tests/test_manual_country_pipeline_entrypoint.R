project_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
main_file <- file.path(project_dir, "Rcode", "run_country_pipeline.R")
lines <- readLines(main_file, warn = FALSE)
text <- paste(lines, collapse = "\n")
trimmed <- trimws(lines)

country_assignment <- grep(
  '^country\\s*<-\\s*"[^"]+"$',
  trimmed
)
runner_source <- grep(
  'source\\(file.path\\("Rcode", "_supporting_scripts", "pipeline_runner.R"\\)\\)',
  trimmed
)
stopifnot(length(country_assignment) == 1)
stopifnot(length(runner_source) == 1)
stopifnot(country_assignment < runner_source)
stopifnot(!grepl("default_country", text, fixed = TRUE))

stopifnot(!any(grepl("^run_country_pipeline\\s*\\(", trimmed)))
stopifnot(sum(grepl("^if \\(FALSE\\) \\{", trimmed)) >= 11)
stopifnot(!grepl("# Step 0:", text, fixed = TRUE))
stopifnot(grepl("Info/<Country>_general_info.json", text, fixed = TRUE))
legacy_terms <- c(
  paste0("_create", "_info.R"),
  paste0("_general_info.", "Rdata"),
  paste0("load.country.", "Rdata")
)
stopifnot(!any(vapply(
  legacy_terms,
  grepl,
  logical(1),
  x = text,
  fixed = TRUE
)))

compact_text <- gsub("[[:space:]]+", "", text)
mics_scripts <- c(
  "MICS_DataProcessing.R",
  "MICS_Geospatial_DataProcessing.R"
)
unsafe_mics_sources <- paste0(
  'source(file.path("Rcode","_script_for_specific_tasks","',
  mics_scripts,
  '"))'
)
stopifnot(!any(vapply(
  unsafe_mics_sources,
  grepl,
  logical(1),
  x = compact_text,
  fixed = TRUE
)))
stopifnot(all(vapply(
  mics_scripts,
  grepl,
  logical(1),
  x = text,
  fixed = TRUE
)))
stopifnot(grepl(
  "Run only the selected country's section or function",
  text,
  fixed = TRUE
))

stopifnot(grepl("georepo_env$main()", text, fixed = TRUE))

preparation_file <- file.path(project_dir, "Rcode", "1_Preperation.R")
preparation_text <- paste(
  readLines(preparation_file, warn = FALSE),
  collapse = "\n"
)
stopifnot(!grepl('country <- "Angola"', preparation_text, fixed = TRUE))
stopifnot(grepl(
  "Set `country` before sourcing Rcode/1_Preperation.R",
  preparation_text,
  fixed = TRUE
))

scripts <- c(
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
  "11_CountrySummary.Rmd"
)
positions <- vapply(
  scripts,
  function(script) regexpr(script, text, fixed = TRUE)[1],
  integer(1)
)
stopifnot(all(positions > 0), all(diff(positions) > 0))

message("manual country pipeline entrypoint tests passed")
