info_file <- file.path("Info", "Laos_general_info.json")
if (!file.exists(info_file)) {
  stop("Missing Lao PDR Info JSON: ", info_file)
}

info <- jsonlite::fromJSON(info_file, simplifyVector = TRUE)

stopifnot(
  identical(info$country, "Laos"),
  identical(info$iso0, "LAO"),
  isTRUE(all.equal(info$frame_year, 2021)),
  isTRUE(all.equal(info$surveys_1frame, 2023)),
  identical(info$final_model$strata.model, "unstrat"),
  identical(info$final_model$bench.model, "bench")
)

expected_model_status <- data.frame(
  model = c(
    "admin2_smoothed_direct_u5",
    "admin2_smoothed_direct_nmr"
  ),
  variant = rep("yearly", 2),
  status = rep("attempted_not_fitted", 2),
  reason = rep("data_sparsity", 2),
  stringsAsFactors = FALSE
)
stopifnot(isTRUE(all.equal(info$model_run_status, expected_model_status)))

cat("Lao PDR final-model and optional-model configuration is correct.\n")
