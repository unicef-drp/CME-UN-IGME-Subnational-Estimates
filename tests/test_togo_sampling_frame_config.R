info <- jsonlite::fromJSON(
  file.path("Info", "Togo_general_info.json"),
  simplifyVector = TRUE
)

stopifnot(
  isTRUE(all.equal(info$frame_year, c(2010, 2015))),
  isTRUE(all.equal(info$surveys_1frame, c(2013, 2017))),
  identical(info$poly.layer.adm2, "georepo_TGO_2"),
  identical(info$strata_weight_source, "survey")
)

cat("Togo sampling-frame and Admin2 settings are configured.\n")
