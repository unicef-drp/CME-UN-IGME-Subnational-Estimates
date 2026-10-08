if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' is required for this test.")
}

info_path <- file.path("Info", "Afghanistan_general_info.json")
stopifnot(file.exists(info_path))

info <- jsonlite::fromJSON(info_path, simplifyVector = TRUE)
report_source <- readLines(
  file.path("Rcode", "11_CountrySummary.Rmd"),
  warn = FALSE
)

stopifnot(
  identical(info$final_model$strata.model, "unstrat"),
  identical(info$final_model$bench.model, "bench"),
  any(grepl(
    "The unstratified specification is used as the default final model",
    report_source,
    fixed = TRUE
  ))
)

message("Afghanistan report model is benchmarked and unstratified.")
