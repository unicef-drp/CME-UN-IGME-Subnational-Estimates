config_path <- file.path("Info", "Comoros_general_info.json")
if (!file.exists(config_path)) {
  stop("Comoros pipeline configuration is missing: ", config_path)
}

config <- jsonlite::read_json(config_path, simplifyVector = TRUE)

expected <- list(
  country = "Comoros",
  iso0 = "COM",
  frame_year = 2017L,
  surveys_1frame = 2022L,
  dhs_survey_year_start = 2000L,
  strata_weight_source = "survey",
  poly.layer.adm1 = "georepo_COM_1",
  poly.layer.adm2 = "georepo_COM_2"
)

for (field in names(expected)) {
  if (!identical(config[[field]], expected[[field]])) {
    stop(
      "Unexpected Comoros config value for ", field, ": ",
      paste(config[[field]], collapse = ", ")
    )
  }
}

expected_final_model <- list(
  time.model = "ar1",
  sd.time.model = "ar1",
  strata.model = "unstrat",
  bench.model = "bench"
)
for (field in names(expected_final_model)) {
  if (!identical(config$final_model[[field]], expected_final_model[[field]])) {
    stop("Unexpected Comoros final model value for ", field, ".")
  }
}

cat("Comoros is configured for MICS 2022 and the unstratified benchmarked model.\n")
