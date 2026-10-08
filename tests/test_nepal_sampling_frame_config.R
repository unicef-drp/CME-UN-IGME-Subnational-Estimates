info <- jsonlite::fromJSON(
  file.path("Info", "Nepal_general_info.json"),
  simplifyVector = TRUE
)

stopifnot(
  isTRUE(all.equal(info$frame_year, 2011)),
  isTRUE(all.equal(info$surveys_1frame, c(2016, 2022))),
  identical(info$strata_weight_source, "survey")
)

cat("Nepal uses the 2016 and 2022 DHS rounds with the 2011 sampling frame.\n")
