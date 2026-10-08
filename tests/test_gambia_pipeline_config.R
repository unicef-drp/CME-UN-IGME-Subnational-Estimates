info_file <- file.path("Info", "Gambia_general_info.json")

stopifnot(file.exists(info_file))

info <- jsonlite::fromJSON(info_file, simplifyVector = TRUE)

stopifnot(
  identical(info$country, "Gambia"),
  identical(info$iso0, "GMB"),
  identical(info$country.abbrev, "gmb"),
  identical(info$doHIVAdj, FALSE),
  identical(info$poly.path, "../shapeFiles/georepo_GMB_shp"),
  identical(info$poly.layer.adm0, "georepo_GMB_0"),
  identical(info$poly.layer.adm1, "georepo_GMB_1"),
  identical(info$poly.layer.adm2, "georepo_GMB_2"),
  identical(info$poly.label.adm1, "NAME_1"),
  identical(info$poly.label.adm2, "NAME_2"),
  identical(as.integer(info$beg.year), 2000L),
  identical(as.integer(info$end.proj.year), 2025L),
  identical(as.integer(info$frame_year), 2013L),
  identical(as.integer(info$surveys_1frame), c(2018L, 2019L)),
  identical(as.integer(info$dhs_survey_year_start), 2019L),
  identical(info$strata_weight_source, "survey"),
  identical(info$strata_weight_missing_region_fallback, "national"),
  identical(info$final_model$time.model, "ar1"),
  identical(info$final_model$sd.time.model, "ar1"),
  identical(info$final_model$strata.model, "strat"),
  identical(info$final_model$bench.model, "bench"),
  identical(info$info.name, "Gambia_general_info.json")
)

cat(
  paste(
    "Gambia uses the 2013 census frame for MICS 2018 and DHS 2019-20",
    "and selects the stratified final model.\n"
  )
)
