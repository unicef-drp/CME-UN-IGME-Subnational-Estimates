info_file <- file.path("Info", "South Africa_general_info.json")

stopifnot(file.exists(info_file))

info <- jsonlite::fromJSON(info_file, simplifyVector = TRUE)

stopifnot(
  identical(info$country, "South Africa"),
  identical(info$iso0, "ZAF"),
  identical(info$country.abbrev, "zaf"),
  identical(info$doHIVAdj, TRUE),
  identical(info$poly.path, "../shapeFiles/georepo_ZAF_shp"),
  identical(info$poly.layer.adm0, "georepo_ZAF_0"),
  identical(info$poly.layer.adm1, "georepo_ZAF_1"),
  identical(info$poly.layer.adm2, "georepo_ZAF_2"),
  identical(info$poly.label.adm1, "NAME_1"),
  identical(info$poly.label.adm2, "NAME_2"),
  identical(as.integer(info$beg.year), 2000L),
  identical(as.integer(info$end.proj.year), 2025L),
  identical(as.integer(info$frame_year), 2011L),
  identical(as.integer(info$surveys_1frame), 2016L),
  identical(as.integer(info$dhs_survey_year_start), 2016L),
  identical(info$strata_weight_source, "survey"),
  identical(info$strata_weight_missing_region_fallback, "national"),
  identical(info$final_model$time.model, "ar1"),
  identical(info$final_model$sd.time.model, "ar1"),
  identical(info$final_model$strata.model, "unstrat"),
  identical(info$final_model$bench.model, "bench"),
  identical(info$info.name, "South Africa_general_info.json")
)

cat(
  paste(
    "South Africa uses the Census 2011 frame for DHS 2016,",
    "survey-derived strata, and an unstratified benchmarked final model.\n"
  )
)
