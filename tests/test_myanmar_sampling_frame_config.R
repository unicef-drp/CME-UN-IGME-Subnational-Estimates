if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' is required for this test.")
}

info <- jsonlite::fromJSON(
  file.path("Info", "Myanmar_general_info.json"),
  simplifyVector = TRUE
)

stopifnot(
  identical(info$country, "Myanmar"),
  identical(as.integer(info$frame_year), 2014L),
  identical(as.integer(info$surveys_1frame), 2016L),
  identical(info$strata_weight_source, "survey"),
  identical(info$strata_weight_missing_region_fallback, "national"),
  isTRUE(info$doCrisisAdj),
  identical(info$final_model$bench.model, "bench")
)

if (!identical(info$final_model$strata.model, "unstrat")) {
  stop(
    "Myanmar reporting uses the user-selected unstratified model after ",
    "review of historical sparsity warnings and cross-indicator consistency."
  )
}

cat(
  paste(
    "Myanmar uses the 2016 DHS with survey-derived strata and a",
    "unstratified benchmarked final model.\n"
  )
)
