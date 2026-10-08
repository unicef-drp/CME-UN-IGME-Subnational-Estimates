script <- paste(readLines(file.path("Rcode", "3_DataProcessing_sf.R"),
                          warn = FALSE),
                collapse = "\n")

if (!grepl("dhs_survey_year_start", script, fixed = TRUE)) {
  stop("3_DataProcessing_sf.R should use the country DHS survey start year.")
}

if (!grepl("surveyYearStart = dhs_survey_year_start", script, fixed = TRUE)) {
  stop("DHS dataset selection should pass dhs_survey_year_start.")
}

load_country_info <- function(country) {
  json_file <- file.path("Info", paste0(country, "_general_info.json"))
  if (!file.exists(json_file)) {
    stop("Missing country Info JSON for ", country, ".")
  }

  jsonlite::fromJSON(json_file, simplifyVector = TRUE)
}

haiti_info <- load_country_info("Haiti")

if (is.null(haiti_info$dhs_survey_year_start)) {
  stop("Haiti country info should save dhs_survey_year_start.")
}

if (!isTRUE(haiti_info$dhs_survey_year_start == 2005)) {
  stop("Haiti DHS survey start year should be 2005.")
}

angola_info <- load_country_info("Angola")

if (is.null(angola_info$dhs_survey_year_start)) {
  stop("Angola country info should save dhs_survey_year_start.")
}

if (!isTRUE(angola_info$dhs_survey_year_start == 2015)) {
  stop("Angola DHS survey start year should be 2015.")
}

cat("Data processing uses country DHS survey start years.\n")
