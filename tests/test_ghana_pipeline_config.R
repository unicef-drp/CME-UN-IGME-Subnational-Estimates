info_file <- file.path("Info", "Ghana_general_info.json")
if (!file.exists(info_file)) {
  stop("Missing Ghana Info JSON: ", info_file)
}

info <- jsonlite::fromJSON(info_file, simplifyVector = TRUE)

stopifnot(
  identical(info$country, "Ghana"),
  identical(info$iso0, "GHA"),
  isTRUE(all.equal(info$frame_year, 2010)),
  isTRUE(all.equal(info$surveys_1frame, c(2011, 2014, 2018))),
  identical(info$final_model$strata.model, "unstrat"),
  identical(info$final_model$bench.model, "bench")
)

expected_model_status <- data.frame(
  model = c(
    "admin2_smoothed_direct_u5",
    "admin2_smoothed_direct_u5",
    "admin2_smoothed_direct_nmr",
    "admin2_smoothed_direct_nmr"
  ),
  variant = c("period", "yearly", "period", "yearly"),
  status = rep("attempted_not_fitted", 4),
  reason = rep("data_sparsity", 4),
  stringsAsFactors = FALSE
)
stopifnot(isTRUE(all.equal(info$model_run_status, expected_model_status)))

cat("Ghana survey-frame and final-model configuration is correct.\n")
