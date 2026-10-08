active_files <- c(
  "Rcode/run_country_pipeline.R",
  "Rcode/1_Preperation.R",
  "Rcode/3_DataProcessing_sf.R",
  "Rcode/7a_UR_prop.R",
  "Rcode/7b_UR_thresholding_sf.R",
  "Rcode/_supporting_scripts/project_paths.R",
  "Rcode/_supporting_scripts/pipeline_runner.R",
  "Rcode/_script_for_specific_tasks/MICS_Geospatial_DataProcessing.R"
)
texts <- vapply(active_files, function(path) {
  paste(readLines(path, warn = FALSE), collapse = "\n")
}, character(1))

legacy_terms <- c(
  paste0("_create", "_info.R"),
  paste0("_general_info.", "Rdata"),
  paste0("load.country.", "Rdata")
)
hits <- unlist(lapply(legacy_terms, function(term) {
  files <- names(texts)[grepl(term, texts, fixed = TRUE)]
  if (length(files) == 0) {
    return(character(0))
  }
  paste0(files, ": ", term)
}), use.names = FALSE)
if (length(hits) > 0) {
  stop(
    "Active pipeline still refers to legacy country info:\n",
    paste(hits, collapse = "\n"),
    call. = FALSE
  )
}

required_loader_files <- c(
  "Rcode/1_Preperation.R",
  "Rcode/3_DataProcessing_sf.R",
  "Rcode/_script_for_specific_tasks/MICS_Geospatial_DataProcessing.R"
)
stopifnot(all(grepl(
  "load.country.info",
  texts[required_loader_files],
  fixed = TRUE
)))

cat("Active pipeline uses JSON country info exclusively.\n")
