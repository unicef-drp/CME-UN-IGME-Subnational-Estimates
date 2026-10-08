info_file <- file.path("Info", "Kenya_general_info.json")
info <- jsonlite::fromJSON(info_file, simplifyVector = TRUE)

stopifnot(
  identical(info$country, "Kenya"),
  identical(info$poly.layer.adm2, "georepo_KEN_2"),
  is.null(info$frame_year),
  isTRUE(all.equal(info$surveys_1frame, c(2003, 2008))),
  identical(info$strata_weight_source, "survey"),
  identical(info$strata_weight_missing_region_fallback, "national"),
  identical(info$final_model$strata.model, "unstrat")
)

expected_model_status <- data.frame(
  model = c(
    "admin1_smoothed_direct_nmr",
    "admin2_smoothed_direct_nmr",
    "admin2_smoothed_direct_nmr"
  ),
  variant = c("yearly", "period", "yearly"),
  status = rep("attempted_not_fitted", 3),
  reason = rep("data_sparsity", 3),
  stringsAsFactors = FALSE
)
stopifnot(isTRUE(all.equal(info$model_run_status, expected_model_status)))

message("Kenya pipeline configuration tests passed")
