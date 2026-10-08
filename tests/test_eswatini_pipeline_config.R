info_path <- file.path("Info", "Eswatini_general_info.json")

if (!file.exists(info_path)) {
  stop("Eswatini country configuration is missing.")
}

info <- jsonlite::fromJSON(info_path, simplifyVector = TRUE)

stopifnot(
  identical(info$country, "Eswatini"),
  identical(info$iso0, "SWZ"),
  isTRUE(info$doHIVAdj),
  identical(info$poly.path, "../shapeFiles/georepo_SWZ_shp"),
  identical(info$poly.layer.adm0, "georepo_SWZ_0"),
  identical(info$poly.layer.adm1, "georepo_SWZ_1"),
  identical(info$poly.layer.adm2, "georepo_SWZ_2"),
  identical(info$poly.label.adm1, "NAME_1"),
  identical(info$poly.label.adm2, "NAME_2"),
  identical(as.integer(info$frame_year), c(1997L, 2017L)),
  identical(as.integer(info$surveys_1frame), 2022L),
  identical(as.integer(info$dhs_survey_year_start), 2000L),
  identical(info$strata_weight_source, "survey"),
  identical(info$final_model$time.model, "ar1"),
  identical(info$final_model$sd.time.model, "ar1"),
  identical(info$final_model$strata.model, "unstrat"),
  identical(info$final_model$bench.model, "bench"),
  identical(info$info.name, "Eswatini_general_info.json")
)

cat("Eswatini uses DHS 2006 and MICS 2022 for the unstratified final model, with MICS 2022 as the latest-frame subset.\n")
