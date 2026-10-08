script_text <- paste(readLines(file.path("Rcode", "3_DataProcessing_sf.R"),
                               warn = FALSE),
                     collapse = "\n")
benin_info <- jsonlite::fromJSON(
  file.path("Info", "Benin_general_info.json"),
  simplifyVector = TRUE
)
guinea_info <- jsonlite::fromJSON(
  file.path("Info", "Guinea_general_info.json"),
  simplifyVector = TRUE
)

required_code <- c(
  "get_survey_exclusions <- function()",
  "survey_excluded",
  "dhs_survey_years <- setdiff(dhs_survey_years, excluded_surveys)",
  "mod.dat <- mod.dat[!mod.dat$survey %in% excluded_surveys, ]",
  "raw.dat <- raw.dat[!raw.dat$survey_year %in% excluded_surveys, ]"
)

missing_code <- required_code[!vapply(required_code, grepl, logical(1),
                                      x = script_text, fixed = TRUE)]
if (length(missing_code) > 0) {
  stop("3_DataProcessing_sf.R is missing survey exclusion support: ",
       paste(missing_code, collapse = ", "))
}

stopifnot(
  isTRUE(all.equal(benin_info$surveys_1frame, 2017)),
  isTRUE(all.equal(benin_info$survey_excluded, c(2011, 2012))),
  identical(benin_info$strata_weight_source, "survey"),
  identical(benin_info$final_model$strata.model, "strat"),
  isTRUE(all.equal(guinea_info$surveys_1frame, 2018)),
  isTRUE(all.equal(guinea_info$survey_excluded, 2016)),
  identical(guinea_info$final_model$strata.model, "unstrat")
)

cat("Survey exclusion support and country exclusion settings are configured.\n")
