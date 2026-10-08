info <- jsonlite::fromJSON(
  file.path("Info", "Malawi_general_info.json"),
  simplifyVector = TRUE
)

stopifnot(
  identical(info$country, "Malawi"),
  identical(info$iso0, "MWI"),
  isTRUE(all.equal(info$frame_year, 2018)),
  isTRUE(all.equal(info$surveys_1frame, c(2020, 2024))),
  isTRUE(all.equal(info$dhs_survey_year_start, 2004)),
  isTRUE(all.equal(info$survey_excluded, 2014)),
  identical(info$strata_weight_source, "survey")
)

malawi_exclusions <- info$georepo_boundary_exclusions
stopifnot(
  is.data.frame(malawi_exclusions),
  nrow(malawi_exclusions) == 1L,
  identical(as.integer(malawi_exclusions$level), 1L),
  identical(
    as.character(malawi_exclusions$name),
    "Under National Administration"
  )
)

expected_model_status <- data.frame(
  model = "admin2_smoothed_direct_nmr",
  variant = "yearly",
  status = "attempted_not_fitted",
  reason = "data_sparsity",
  stringsAsFactors = FALSE
)
stopifnot(isTRUE(all.equal(info$model_run_status, expected_model_status)))

message("Malawi five-survey pipeline configuration tests passed")
