info <- jsonlite::fromJSON(
  file.path("Info", "DR_Congo_general_info.json"),
  simplifyVector = TRUE
)

stopifnot(
  identical(info$country, "DR_Congo"),
  identical(info$iso0, "COD"),
  identical(info$country.abbrev, "cod"),
  identical(info$poly.layer.adm0, "georepo_COD_0"),
  identical(info$poly.layer.adm1, "georepo_COD_1"),
  identical(info$poly.layer.adm2, "georepo_COD_2"),
  identical(info$poly.label.adm1, "NAME_1"),
  identical(info$poly.label.adm2, "NAME_2"),
  isTRUE(all.equal(info$beg.year, 2000)),
  isTRUE(all.equal(info$end.proj.year, 2025)),
  isTRUE(all.equal(info$frame_year, 2003)),
  isTRUE(all.equal(info$surveys_1frame, 2023)),
  isTRUE(all.equal(info$dhs_survey_year_start, 2000)),
  identical(info$strata_weight_source, "survey"),
  identical(info$strata_weight_missing_region_fallback, "national"),
  identical(info$final_model$time.model, "ar1"),
  identical(info$final_model$sd.time.model, "ar1"),
  identical(info$final_model$strata.model, "unstrat"),
  identical(info$final_model$bench.model, "bench")
)

message("DR Congo survey and pipeline configuration tests passed")
