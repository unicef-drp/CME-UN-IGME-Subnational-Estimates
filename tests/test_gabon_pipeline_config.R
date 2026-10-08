info_path <- file.path("Info", "Gabon_general_info.json")

if (!file.exists(info_path)) {
  stop("Gabon country configuration is missing.")
}

info <- jsonlite::fromJSON(info_path, simplifyVector = TRUE)

stopifnot(
  identical(info$country, "Gabon"),
  identical(info$iso0, "GAB"),
  isTRUE(info$doHIVAdj),
  identical(info$poly.path, "../shapeFiles/georepo_GAB_shp"),
  identical(info$poly.layer.adm0, "georepo_GAB_0"),
  identical(info$poly.layer.adm1, "georepo_GAB_1"),
  identical(info$poly.layer.adm2, "georepo_GAB_2"),
  identical(info$poly.label.adm1, "NAME_1"),
  identical(info$poly.label.adm2, "NAME_2"),
  identical(info$country.abbrev, "gab"),
  identical(as.integer(info$beg.year), 2000L),
  identical(as.integer(info$end.proj.year), 2025L),
  identical(as.integer(info$frame_year), c(2003L, 2013L)),
  identical(as.integer(info$surveys_1frame), 2019L),
  identical(as.integer(info$dhs_survey_year_start), 2012L),
  identical(info$strata_weight_source, "survey"),
  identical(info$strata_weight_missing_region_fallback, "national"),
  identical(info$final_model$time.model, "ar1"),
  identical(info$final_model$sd.time.model, "ar1"),
  identical(info$final_model$strata.model, "unstrat"),
  identical(info$final_model$bench.model, "bench"),
  identical(info$info.name, "Gabon_general_info.json")
)

cat(
  "Gabon uses DHS 2012 and DHS 2019-21 in the all-survey unstratified ",
  "model, with DHS 2019 as the latest-frame subset.\n",
  sep = ""
)
