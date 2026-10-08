config_path <- file.path("Info", "Philippines_general_info.json")
if (!file.exists(config_path)) {
  stop("Philippines pipeline configuration is missing: ", config_path)
}

config <- jsonlite::read_json(config_path, simplifyVector = TRUE)

expected <- list(
  country = "Philippines",
  iso0 = "PHL",
  frame_year = 2015L,
  surveys_1frame = c(2017L, 2022L),
  survey_excluded = 2013L,
  dhs_survey_year_start = 2000L,
  strata_weight_source = "survey",
  poly.path = "../shapeFiles/ocha_PHL_shp",
  poly.layer.adm0 = "ocha_PHL_0",
  poly.layer.adm1 = "ocha_PHL_1",
  poly.layer.adm2 = "ocha_PHL_2",
  poly.label.adm1 = "NAME_1",
  poly.label.adm2 = "NAME_2",
  boundary_source = "OCHA HDX (NAMRIA/PSA)",
  boundary_source_url =
    "https://data.humdata.org/dataset/cod-ab-phl"
)

for (field in names(expected)) {
  if (!identical(config[[field]], expected[[field]])) {
    stop(
      "Unexpected Philippines config value for ", field, ": ",
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
    stop("Unexpected Philippines final model value for ", field, ".")
  }
}

cat(
  "Philippines is configured for DHS 2003, 2008, 2017, and 2022, ",
  "with 2013 excluded because GPS was not collected.\n",
  sep = ""
)
