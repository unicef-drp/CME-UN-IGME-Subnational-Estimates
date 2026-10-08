info_path <- file.path("Info", "Sierra_Leone_general_info.json")
stopifnot(file.exists(info_path))

info <- jsonlite::fromJSON(info_path, simplifyVector = TRUE)

stopifnot(
  identical(info$country, "Sierra_Leone"),
  identical(info$iso0, "SLE"),
  identical(as.integer(info$frame_year), 2004L),
  identical(as.integer(info$surveys_1frame), c(2008L, 2013L)),
  identical(info$strata_weight_source, "survey"),
  identical(info$poly.label.adm1, "NAME_1"),
  identical(info$poly.label.adm2, "NAME_2")
)

cat("Sierra Leone sampling-frame configuration is valid.\n")
