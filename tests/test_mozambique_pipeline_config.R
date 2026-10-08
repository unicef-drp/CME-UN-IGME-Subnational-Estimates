info <- jsonlite::fromJSON(
  file.path("Info", "Mozambique_general_info.json"),
  simplifyVector = TRUE
)

stopifnot(
  identical(info$country, "Mozambique"),
  identical(info$iso0, "MOZ"),
  isTRUE(info$doHIVAdj),
  identical(as.integer(info$frame_year), 2007L),
  identical(as.integer(info$surveys_1frame), c(2011L, 2015L)),
  identical(info$strata_weight_source, "survey"),
  identical(info$strata_weight_missing_region_fallback, "national"),
  identical(info$poly.layer.adm1, "georepo_MOZ_1"),
  identical(info$poly.layer.adm2, "georepo_MOZ_2"),
  identical(info$final_model$strata.model, "unstrat"),
  identical(info$final_model$bench.model, "bench")
)

cat("Mozambique sampling-frame and pipeline configuration tests passed\n")
