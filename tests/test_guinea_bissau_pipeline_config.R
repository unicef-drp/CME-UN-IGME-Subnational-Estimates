info_path <- file.path("Info", "Guinea-Bissau_general_info.json")

if (!file.exists(info_path)) {
  stop("Guinea-Bissau country configuration is missing: ", info_path)
}

info <- jsonlite::fromJSON(info_path, simplifyVector = TRUE)

stopifnot(
  identical(info$country, "Guinea-Bissau"),
  identical(info$iso0, "GNB"),
  identical(info$doHIVAdj, FALSE),
  identical(info$poly.path, "../shapeFiles/georepo_GNB_shp"),
  identical(info$poly.layer.adm0, "georepo_GNB_0"),
  identical(info$poly.layer.adm1, "georepo_GNB_1"),
  identical(info$poly.label.adm1, "NAME_1"),
  identical(info$country.abbrev, "gnb"),
  isTRUE(all.equal(info$frame_year, 2009)),
  isTRUE(all.equal(info$surveys_1frame, c(2010, 2014))),
  identical(info$strata_weight_source, "survey"),
  identical(info$final_model$time.model, "ar1"),
  identical(info$final_model$sd.time.model, "ar1"),
  identical(info$final_model$strata.model, "strat"),
  identical(info$final_model$bench.model, "bench"),
  identical(info$info.name, "Guinea-Bissau_general_info.json")
)

if ("poly.layer.adm2" %in% names(info) ||
    "poly.label.adm2" %in% names(info)) {
  stop("Guinea-Bissau Admin-1 run should not define Admin-2 GeoRepo layers.")
}

cat("Guinea-Bissau Admin-1 MICS configuration is valid.\n")
