info <- jsonlite::fromJSON(
  file.path("Info", "Burkina_Faso_general_info.json"),
  simplifyVector = TRUE
)

stopifnot(
  identical(info$country, "Burkina_Faso"),
  identical(info$iso0, "BFA"),
  identical(info$country.abbrev, "bfa"),
  identical(info$poly.layer.adm0, "georepo_BFA_0"),
  identical(info$poly.layer.adm1, "georepo_BFA_1"),
  identical(info$poly.layer.adm2, "georepo_BFA_2"),
  isTRUE(all.equal(info$frame_year, 2006)),
  isTRUE(all.equal(info$surveys_1frame, 2010)),
  isTRUE(all.equal(info$dhs_survey_year_start, 2000)),
  isTRUE(all.equal(info$survey_excluded, 2021)),
  identical(info$strata_weight_source, "survey"),
  identical(info$final_model$time.model, "ar1"),
  identical(info$final_model$sd.time.model, "ar1"),
  identical(info$final_model$strata.model, "unstrat"),
  identical(info$final_model$bench.model, "bench")
)

message("Burkina Faso survey exclusion and pipeline configuration tests passed")
