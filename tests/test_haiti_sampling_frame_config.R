info_file <- file.path("Info", "Haiti_general_info.json")
bb8_script <- file.path("Rcode", "8_10_BB8.R")

if (!file.exists(info_file)) {
  stop("Missing Haiti info JSON: ", info_file)
}
if (!file.exists(bb8_script)) {
  stop("Missing BB8 script: ", bb8_script)
}

info <- jsonlite::fromJSON(info_file, simplifyVector = TRUE)
bb8_text <- paste(readLines(bb8_script, warn = FALSE), collapse = "\n")

stopifnot(
  isTRUE(all.equal(info$frame_year, 2011)),
  isTRUE(all.equal(info$surveys_1frame, c(2012, 2016))),
  isTRUE(all.equal(info$dhs_survey_year_start, 2005)),
  identical(info$strata_weight_source, "survey"),
  isTRUE(all.equal(
    info$model_run_status,
    data.frame(
      model = c(
        "admin2_smoothed_direct_u5",
        "admin2_smoothed_direct_nmr"
      ),
      variant = c("period", "period"),
      status = rep("attempted_not_fitted", 2),
      reason = rep("data_sparsity", 2),
      stringsAsFactors = FALSE
    )
  ))
)

if (!grepl('identical(strata_weight_source, "survey")',
           bb8_text, fixed = TRUE)) {
  stop("8_10_BB8.R should derive survey strata weights based on ",
       "strata_weight_source, not a country-specific special case.")
}

cat("Haiti sampling-frame and survey-derived strata settings are configured.\n")
