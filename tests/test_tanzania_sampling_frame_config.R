info <- jsonlite::fromJSON(
  file.path("Info", "Tanzania_general_info.json"),
  simplifyVector = TRUE
)

stopifnot(
  isTRUE(all.equal(info$frame_year, c(2002, 2012))),
  isTRUE(all.equal(info$surveys_1frame, c(2015, 2022))),
  isTRUE(all.equal(info$survey_excluded, 2012)),
  identical(info$strata_weight_source, "survey")
)

boundary_exclusions <- info$georepo_boundary_exclusions
stopifnot(
  is.data.frame(boundary_exclusions),
  nrow(boundary_exclusions) == 1L,
  identical(as.integer(boundary_exclusions$level), 1L),
  identical(boundary_exclusions$name, "Under National Administration"),
  nzchar(boundary_exclusions$reason)
)
