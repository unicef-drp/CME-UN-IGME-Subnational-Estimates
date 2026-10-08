info <- jsonlite::fromJSON(
  file.path("Info", "Uganda_general_info.json"),
  simplifyVector = TRUE
)

stopifnot(
  isTRUE(all.equal(info$frame_year, c(2002, 2014))),
  isTRUE(all.equal(info$surveys_1frame, 2016)),
  isTRUE(all.equal(info$dhs_survey_year_start, 2000)),
  identical(info$strata_weight_source, "survey"),
  identical(info$poly.layer.adm2, "georepo_UGA_2")
)

cat("Uganda sampling-frame and Admin2 settings are configured.\n")
