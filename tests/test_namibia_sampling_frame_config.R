info <- jsonlite::fromJSON(
  file.path("Info", "Namibia_general_info.json"),
  simplifyVector = TRUE
)

stopifnot(
  isTRUE(all.equal(info$frame_year, 2011)),
  isTRUE(all.equal(info$surveys_1frame, 2013)),
  identical(info$strata_weight_source, "survey")
)

cat("Namibia uses the 2013 DHS with the 2011 sampling frame.\n")
