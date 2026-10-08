if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' is required for this test.")
}

info <- jsonlite::fromJSON(
  file.path("Info", "Mauritania_general_info.json"),
  simplifyVector = TRUE
)

stopifnot(
  identical(info$country, "Mauritania"),
  identical(as.integer(info$frame_year), 2013L),
  identical(as.integer(info$surveys_1frame), 2020L),
  identical(info$strata_weight_source, "survey"),
  identical(info$strata_weight_missing_region_fallback, "national"),
  identical(info$final_model$bench.model, "bench")
)

if (!identical(info$final_model$strata.model, "strat")) {
  stop(
    "Mauritania's only included survey is in the selected shared frame; ",
    "the final model should be stratified."
  )
}

cat(
  paste(
    "Mauritania uses the 2020 survey with survey-derived strata and a",
    "stratified benchmarked final model.\n"
  )
)
