info_file <- file.path("Info", "Tajikistan_general_info.json")

stopifnot(file.exists(info_file))

info <- jsonlite::fromJSON(info_file, simplifyVector = TRUE)

stopifnot(
  identical(info$country, "Tajikistan"),
  identical(info$iso0, "TJK"),
  identical(info$country.abbrev, "tjk"),
  identical(info$doHIVAdj, FALSE),
  identical(info$poly.path, "../shapeFiles/georepo_TJK_shp"),
  identical(info$poly.layer.adm0, "georepo_TJK_0"),
  identical(info$poly.layer.adm1, "georepo_TJK_1"),
  identical(info$poly.layer.adm2, "georepo_TJK_2"),
  identical(info$poly.label.adm1, "NAME_1"),
  identical(info$poly.label.adm2, "NAME_2"),
  identical(as.integer(info$beg.year), 2000L),
  identical(as.integer(info$end.proj.year), 2025L),
  identical(as.integer(info$frame_year), c(2010L, 2020L)),
  identical(as.integer(info$surveys_1frame), c(2012L, 2017L)),
  identical(as.integer(info$dhs_survey_year_start), 2012L),
  is.null(info$survey_excluded),
  identical(info$strata_weight_source, "survey"),
  identical(info$strata_weight_missing_region_fallback, "national"),
  identical(info$final_model$time.model, "ar1"),
  identical(info$final_model$sd.time.model, "ar1"),
  identical(info$final_model$strata.model, "unstrat"),
  identical(info$final_model$bench.model, "bench"),
  identical(info$info.name, "Tajikistan_general_info.json")
)

cat(
  paste(
    "Tajikistan configuration retains DHS 2012, DHS 2017, and DHS 2023",
    "in all-survey models,",
    "uses DHS 2012 and DHS 2017 for the shared 2010-frame branch, and selects",
    "the benchmarked unstratified all-survey model as final.\n"
  )
)
