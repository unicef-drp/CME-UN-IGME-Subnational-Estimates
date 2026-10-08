info_file <- file.path("Info", "Timor-Leste_general_info.json")

stopifnot(file.exists(info_file))

info <- jsonlite::fromJSON(info_file, simplifyVector = TRUE)

stopifnot(
  identical(info$country, "Timor-Leste"),
  identical(info$iso0, "TLS"),
  identical(info$country.abbrev, "tls"),
  identical(info$doHIVAdj, FALSE),
  identical(info$poly.path, "../shapeFiles/georepo_TLS_shp"),
  identical(info$poly.layer.adm0, "georepo_TLS_0"),
  identical(info$poly.layer.adm1, "georepo_TLS_1"),
  identical(info$poly.layer.adm2, "georepo_TLS_2"),
  identical(info$poly.label.adm1, "NAME_1"),
  identical(info$poly.label.adm2, "NAME_2"),
  identical(as.integer(info$beg.year), 2000L),
  identical(as.integer(info$end.proj.year), 2025L),
  is.null(info$frame_year),
  identical(as.integer(info$surveys_1frame), 2009L),
  identical(as.integer(info$dhs_survey_year_start), 2009L),
  identical(as.integer(info$survey_excluded), 2016L),
  identical(info$strata_weight_source, "survey"),
  identical(info$strata_weight_missing_region_fallback, "national"),
  identical(info$final_model$time.model, "ar1"),
  identical(info$final_model$sd.time.model, "ar1"),
  identical(info$final_model$strata.model, "unstrat"),
  identical(info$final_model$bench.model, "bench"),
  identical(info$info.name, "Timor-Leste_general_info.json")
)

cat(
  paste(
    "Timor-Leste includes only DHS 2009-10 and excludes DHS 2016,",
    "derives any stratum weights from the retained survey, and selects the benchmarked",
    "unstratified all-survey model as final.\n"
  )
)
